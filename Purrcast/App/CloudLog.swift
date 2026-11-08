import Foundation
import CloudKit
import CryptoKit

/// 날씨 기록 in the person's own iCloud (the CloudKit private database): one record per place and month, so a new
/// phone or a reinstall gets the 날씨 달력 back. Only the person's Apple account reads it; the developer never sees it.
///
/// A sync pulls what other phones saved since the last change token, folds it into the day files (DayLog.merge),
/// then saves the months whose bytes changed since they were last saved. Nothing is deleted in iCloud: a place taken
/// off the list keeps its months there, and only places on the list (and "here") are pulled back.
///
/// Release builds only: TestFlight and App Store builds carry the iCloud entitlement; a debug or simulator build
/// without it would crash creating the container, so there the switch shows but nothing runs.
@MainActor
final class CloudLog: ObservableObject {
    static let shared = CloudLog()
    nonisolated static let containerID = "iCloud.app.purrcast.ios"
    nonisolated static let recordType = "DayMonth"

    enum Status: Equatable { case off, idle, syncing, saved(Date), noAccount, failed }

    @Published private(set) var status: Status
    /// 설정 → 날씨 달력 → iCloud에 보관 (on by default)
    @Published var enabled: Bool {
        didSet {
            guard enabled != oldValue else { return }
            SharedStore.defaults.set(enabled, forKey: "cloudLog")
            if enabled { status = .idle; Task { await sync(force: true) } } else { status = .off }
        }
    }

    #if DEBUG
    static let active = ProcessInfo.processInfo.arguments.contains("-cloud")
    #else
    static let active = true
    #endif

    private let zoneID = CKRecordZone.ID(zoneName: "DayLog", ownerName: CKCurrentUserDefaultName)
    private var running = false
    private var lastRun: Date?
    private var state: CloudState
    private lazy var container = CKContainer(identifier: Self.containerID)
    private var db: CKDatabase { container.privateCloudDatabase }

    init() {
        let st = CloudState.load()
        let on = SharedStore.defaults.object(forKey: "cloudLog") as? Bool ?? true
        state = st
        enabled = on
        status = !on ? .off : (st.saved.map(Status.saved) ?? .idle)
    }

    /// Pull, fold in, save. At most every five minutes unless forced (the switch turned on).
    func sync(model: AppModel? = AppModel.shared, force: Bool = false) async {
        guard Self.active, enabled, let model, model.cloudAllowed, !running else { return }
        if !force, let l = lastRun, Date().timeIntervalSince(l) < 300 { return }
        running = true; lastRun = Date()
        defer { running = false }
        let before = status
        status = .syncing
        do {
            guard try await container.accountStatus() == .available else { status = .noAccount; return }
            // another Apple account on this phone: its records are not the ones remembered
            let user = try await container.userRecordID().recordName
            if state.user != user { state = CloudState(user: user) }
            if !state.zone {
                _ = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
                state.zone = true
            }
            let ids = Set(model.places.map(\.id)).union(["here"])
            if try await pull(ids: ids, log: model.dayLog) { model.dayLogChanged() }
            // a month another phone saved first comes back folded in; one more pass saves the merged month
            if try await push(ids: ids, log: model.dayLog) {
                model.dayLogChanged()
                _ = try await push(ids: ids, log: model.dayLog)
            }
            let now = Date()
            state.saved = now
            status = .saved(now)
        } catch let e as CKError where e.code == .userDeletedZone {
            // the person deleted this app's data in iCloud settings: stop, and do not put it back
            state = CloudState(user: state.user)
            enabled = false
        } catch let e as CKError where e.code == .zoneNotFound {
            state = CloudState(user: state.user)        // made again, and everything saved again, next time
            status = before == .syncing ? .failed : before
        } catch {
            status = .failed
        }
        state.save()
    }

    // MARK: pull · push

    /// Folds in the months other phones saved since the last pull; true when a day file changed
    private func pull(ids: Set<String>, log: DayLog) async throws -> Bool {
        var token = state.tokenValue
        var changed = false
        var more = true, expired = 0
        while more {
            do {
                let r = try await db.recordZoneChanges(inZoneWith: zoneID, since: token)
                for (_, res) in r.modificationResultsByID {
                    guard case .success(let m) = res else { continue }
                    if fold(m.record, ids: ids, log: log) { changed = true }
                }
                token = r.changeToken
                more = r.moreComing
            } catch let e as CKError where e.code == .changeTokenExpired && expired == 0 {
                token = nil; expired += 1
            }
        }
        state.tokenValue = token
        return changed
    }

    /// One month from iCloud into its place's file. Its bytes become the month's "last saved" mark, unless this
    /// phone still has days it lacks (then the push saves the merged month).
    private func fold(_ rec: CKRecord, ids: Set<String>, log: DayLog) -> Bool {
        state.keep(rec)
        guard let place = rec["place"] as? String, let packed = rec["body"] as? Data,
              let raw = Self.unzip(packed), let days = DayLog.unpack(raw) else { return false }
        guard ids.contains(place) else { return false }
        let changed = log.mergeIn(days, for: place)
        // the month as iCloud has it: when this phone's merged month still differs, the push saves it
        state.hashes[rec.recordID.recordName] = Self.hash(raw)
        return changed
    }

    /// Saves the months whose bytes differ from what was saved last; true when another phone had saved one of them
    /// first (its days were folded in, so the merged month goes up on the next pass)
    private func push(ids: Set<String>, log: DayLog) async throws -> Bool {
        var out: [CKRecord] = [], marks: [String: String] = [:]
        for id in ids.sorted() {
            for (month, days) in log.months(id) {
                guard let raw = DayLog.pack(days), let packed = Self.zip(raw) else { continue }
                let name = Self.recordName(place: id, month: month)
                let h = Self.hash(raw)
                if state.hashes[name] == h { continue }
                let rec = state.record(name) ?? CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
                rec["place"] = id as NSString
                rec["month"] = month as NSString
                rec["body"] = packed as NSData
                rec["v"] = 1 as NSNumber
                out.append(rec); marks[name] = h
            }
        }
        var conflict = false
        for start in stride(from: 0, to: out.count, by: 40) {
            let chunk = Array(out[start..<min(start + 40, out.count)])
            let res = try await db.modifyRecords(saving: chunk, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: false)
            for (rid, r) in res.saveResults {
                switch r {
                case .success(let saved):
                    state.keep(saved)
                    state.hashes[rid.recordName] = marks[rid.recordName]
                case .failure(let e as CKError) where e.code == .serverRecordChanged:
                    if let server = e.serverRecord {
                        _ = fold(server, ids: ids, log: log)
                        state.hashes[rid.recordName] = nil      // save the merged month again
                        conflict = true
                    }
                case .failure(let e as CKError) where e.code == .zoneNotFound || e.code == .userDeletedZone:
                    throw e
                case .failure:
                    break                                       // tried again on the next sync
                }
            }
        }
        return conflict
    }

    // MARK: helpers

    /// "m_<place>_2026-11": the place id as is when it is plain ASCII, else (or when it has other signs, "kr:…",
    /// "mk:37.566,126.902") a short hash of it, so two places never share a record
    nonisolated static func recordName(place: String, month: String) -> String {
        let plain = place.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        let key = plain && place.count <= 60 ? place : "h" + String(hash(Data(place.utf8)).prefix(20))
        return "m_\(key)_\(month)"
    }
    nonisolated static func hash(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
    nonisolated static func zip(_ d: Data) -> Data? { try? (d as NSData).compressed(using: .zlib) as Data }
    nonisolated static func unzip(_ d: Data) -> Data? { try? (d as NSData).decompressed(using: .zlib) as Data }
}

/// What a sync remembers between runs (Application Support, this phone only): the account, the zone, the change
/// token, each record's system fields (so saves carry the server's change tag) and the bytes last saved per month.
private struct CloudState: Codable {
    var user: String?
    var zone = false
    var token: Data?
    var fields: [String: Data] = [:]
    var hashes: [String: String] = [:]
    var saved: Date?

    init(user: String? = nil) { self.user = user }

    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("CloudLog.plist")
    }
    static func load() -> CloudState {
        (try? Data(contentsOf: url)).flatMap { try? PropertyListDecoder().decode(CloudState.self, from: $0) } ?? CloudState()
    }
    func save() { if let d = try? PropertyListEncoder().encode(self) { try? d.write(to: Self.url, options: .atomic) } }

    var tokenValue: CKServerChangeToken? {
        get { token.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) } }
        set { token = newValue.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) } }
    }
    mutating func keep(_ r: CKRecord) {
        let c = NSKeyedArchiver(requiringSecureCoding: true)
        r.encodeSystemFields(with: c)
        c.finishEncoding()
        fields[r.recordID.recordName] = c.encodedData
    }
    func record(_ name: String) -> CKRecord? {
        guard let d = fields[name], let c = try? NSKeyedUnarchiver(forReadingFrom: d) else { return nil }
        c.requiresSecureCoding = true
        defer { c.finishDecoding() }
        return CKRecord(coder: c)
    }
}
