import StoreKit
import SwiftUI

/// 설정, in the order of the design: plan · 언어 · 지역 · 단위 · 알림 · 가까운 비 · 화면 · 위젯 · 워치 · 정보.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var purchases: Purchases
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss
    @State private var redeeming = false
    @ObservedObject private var cloud = CloudLog.shared
    @ObservedObject private var ads = Ads.shared

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: L("설정")) { dismiss() }
            ScrollView {
                VStack(spacing: 0) {
                    plan
                    // Apple subscription offer codes, right by the plan (3.1.1: Apple's sheet, no coupon path of our own)
                    Button(L("코드 사용")) { redeeming = true }
                        .font(.ui(12.5)).foregroundStyle(UI.sub)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 22).padding(.top, 8)
                        .accessibilityIdentifier("redeem-code-settings")
                    languageSection
                    placesSection
                    unitsSection
                    notificationsSection
                    displaySection
                    widgetsSection
                    cloudSection
                    infoSection
                    // Europe/UK (Google's consent form): change the ad consent any time
                    if ads.privacyOptions && !model.plus {
                        Button(L("광고 개인정보 설정")) { ads.showPrivacyOptions() }
                            .font(.ui(12.5)).foregroundStyle(UI.sub).padding(.top, 14)
                            .accessibilityIdentifier("ad-privacy")
                    }
                    Text(model.isSample ? L("지금은 예시 날씨로 보여요 (서버 연결 전)") : "")
                        .font(.ui(11)).foregroundStyle(UI.faint).padding(.top, 14).padding(.bottom, 30)
                }
            }
        }
        .background(UI.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) { AdBanner { go(.paywall) } }     // Free
        // Apple's offer-code sheet; the transaction listener picks the redeemed plan up by itself
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await purchases.refresh(); await purchases.refreshTrialEligibility() } }
    }

    // MARK: plan banner

    /// Free: what Plus adds, in one line (no "광고 제거" while the free app shows no ads).
    private var plusPitch: String {
        var parts: [String] = []
        if Features.adsInFree { parts.append(L("광고 제거")) }
        parts += [L("애플워치"), L("캐릭터"), L("가까운 비")]
        return parts.joined(separator: " · ")
    }

    /// " · 3일 무료" after Plus when the store offers a trial (or a test build offers its test trial).
    private var trialSuffix: String {
        if let t = purchases.trialText(Purchases.yearly) { return " · " + t }
        return purchases.offersTestTrial ? " · " + L("테스트") : ""
    }

    @ViewBuilder private var plan: some View {
        if model.plus && !purchases.active && purchases.testActive {
            RowGroup {
                SettingRow(icon: "sparkle", title: L("Plus 테스트 체험 중"), subtitle: purchases.statusLine) {
                    Button { Haptic.soft(); purchases.endTestTrial() } label: { RowValue(text: L("끝내기"), chevron: false) }
                        .accessibilityIdentifier("end-test-plus")
                }
            }.padding(.top, 6)
        } else if model.plus {
            RowGroup {
                SettingRow(icon: "sparkle", title: L("Plus 구독 중"), subtitle: purchases.statusLine) {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) { RowValue(text: L("관리")) }
                }
            }.padding(.top, 6)
        } else {
            Button { go(.paywall) } label: {
                HStack(spacing: 12) {
                    PixelIcon(name: "sparkle", size: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Brand.plus + trialSuffix).font(.ui(15, .bold)).foregroundStyle(UI.ink)
                        Text(plusPitch).font(.ui(12)).foregroundStyle(UI.warmInk)
                    }
                    Spacer()
                    RowChevron()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(LinearGradient(colors: [UI.warmTop, UI.warmBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(UI.warmLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.press(0.98)).padding(.horizontal, 16).padding(.top, 6)
            .accessibilityIdentifier("go-plus")
        }
    }

    // MARK: 언어

    /// 언어 · Language, near the top and in two languages, so it can be found even in a language one cannot read.
    private var languageSection: some View {
        RowGroup {
            Button { go(.language) } label: {
                SettingRow(icon: "globe", title: L("언어 · Language")) {
                    RowValue(text: model.language.isEmpty ? L("기기 설정") : (Lang(rawValue: model.language)?.nativeName ?? ""))
                }
            }.buttonStyle(.row).accessibilityIdentifier("language")
        }
        .padding(.top, 14)
    }

    // MARK: 지역

    private var hereSubtitle: String? {
        if model.hereIsLive { return model.places.first { $0.id == "here" }?.name }
        return model.location.allowed || model.location.undecided ? L("끄면 %@로 봐요", Place.here.name) : L("아이폰 설정에서 위치를 허용해 주세요")
    }

    private var placesSection: some View {
        Group {
            SectionLabel(text: L("지역"))
            RowGroup {
                SettingRow(symbol: "location.fill", title: L("지금 위치 쓰기"), subtitle: hereSubtitle) { toggle($model.useLocation, L("지금 위치 쓰기")) }
                RowDivider()
                Button { go(.places) } label: {
                    SettingRow(icon: "daynight", title: L("저장한 지역")) { RowValue(text: L("%d곳", model.places.count)) }
                }.buttonStyle(.row)
            }
        }
    }

    // MARK: 단위

    private var unitsSection: some View {
        Group {
            SectionLabel(text: L("단위"))
            RowGroup {
                SettingRow(title: L("온도")) { Pills(options: [(false, "°C"), (true, "°F")], value: $model.unitF) }
                RowDivider()
                SettingRow(title: L("시간")) { Pills(options: [(false, L("24시간")), (true, L("12시간"))], value: $model.clock12) }
                RowDivider()
                SettingRow(title: L("바람")) { Pills(options: WindUnit.allCases.map { ($0, $0.label) }, value: $model.wind) }
            }
        }
    }

    // MARK: 알림

    private var notificationsSection: some View {
        Group {
            SectionLabel(text: L("알림"))
            RowGroup {
                // free: the morning summary only; rain, the day-to-day change and warnings are Plus
                SettingRow(icon: "umbrella_closed", title: L("비 오기 전"), subtitle: L("비·눈이 오기 1시간 전과 올 때 잠깐 알려 드려요")) { if model.plus { toggle($model.notifyRain, L("비 오기 전")) } else { PlusTag() } }
                RowDivider()
                SettingRow(icon: "sun", title: L("아침 요약")) {
                    HStack(spacing: 8) {
                        DatePicker("", selection: $model.morningTime, displayedComponents: .hourAndMinute).labelsHidden()
                            .onChange(of: model.morningTime) { _, _ in Haptic.select() }
                        toggle($model.notifyMorning, L("아침 요약"))
                    }
                }
                RowDivider()
                SettingRow(icon: "daynight", title: L("기온 변화"), subtitle: L("아침에 어제와 비교해 알려 드려요")) { if model.plus { toggle($model.notifyChange, L("기온 변화")) } else { PlusTag() } }
                RowDivider()
                SettingRow(icon: "star", title: L("월간 리포트"), subtitle: L("매달 1일 아침에 지난달 날씨를 정리해 알려 드려요")) { if model.plus { toggle($model.notifyMonthly, L("월간 리포트")) } else { PlusTag() } }
                RowDivider()
                SettingRow(icon: "exclaim", title: L("기상특보 · 미세먼지"), subtitle: L("특보·황사·미세먼지 주의보가 내려지거나 미세먼지가 나빠지면 잠깐 알려 드려요")) { if model.plus { toggle($model.notifyAlert, L("기상특보 · 미세먼지")) } else { PlusTag() } }
                RowDivider()
                SettingRow(icon: "zzz", title: L("조용한 시간")) { RowValue(text: "22:00~07:00", chevron: false) }
            }
        }
    }

    // MARK: 가까운 비

    /// Title and sub line by the current place's region: Korea gets the KMA six hours, elsewhere Apple's minute rain.
    // MARK: 화면

    private var displaySection: some View {
        Group {
            SectionLabel(text: L("화면"))
            RowGroup {
                SettingRow(title: L("글씨")) { Pills(options: [(true, L("픽셀")), (false, L("일반"))], value: $model.pixelFont) }
                RowDivider()
                SettingRow(title: L("화면 모드")) { Pills(options: Appearance.allCases.map { ($0, $0.title) }, value: $model.appearance) }
                    .accessibilityIdentifier("appearance")
                RowDivider()
                Button { go(.character) } label: {
                    SettingRow(icon: "heart", title: L("캐릭터"), subtitle: Voice.choices.isEmpty ? nil : L("이름 · 말투")) {
                        if model.plus || model.gifts.contains(model.shownCharacter) { RowValue(text: model.name(of: model.shownCharacter)) } else { PlusTag() }
                    }
                }.buttonStyle(.row)
                RowDivider()
                Button { go(.appIcon) } label: {
                    SettingRow(icon: "partly_cloudy", title: L("앱 아이콘")) {
                        HStack(spacing: 8) {
                            Image(AppIcon.currentPreview(model.shownCharacter)).resizable().interpolation(.high).frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            RowChevron()
                        }
                    }
                }.buttonStyle(.row).accessibilityIdentifier("app-icon")
                RowDivider()
                // the home cards move by a long press; back to the usual order here
                SettingRow(icon: "sparkle", title: L("홈 카드 순서"), subtitle: L("카드를 꾹 눌러서 옮길 수 있어요")) {
                    if !model.homeOrder.isEmpty {
                        Button { Haptic.soft(); withAnimation(Motion.gentle) { model.homeOrder = [] } } label: {
                            Text(L("기본으로")).font(.ui(13, .semibold)).foregroundStyle(UI.accent)
                        }
                        .buttonStyle(.press(0.94)).accessibilityIdentifier("home-order-reset")
                    }
                }
            }
        }
    }

    // MARK: 위젯 · 워치

    private var widgetsSection: some View {
        Group {
            SectionLabel(text: L("위젯 · 워치"))
            RowGroup {
                Button { go(.widgets) } label: {
                    SettingRow(icon: "star", title: L("위젯 추가하는 법")) { RowChevron() }
                }.buttonStyle(.row).accessibilityIdentifier("widgets")
                RowDivider()
                SettingRow(icon: "daynight", title: L("애플워치"), subtitle: model.plus ? L("워치에 %@를 설치하면 바로 보여요", Brand.name) : L("Plus에서 워치 앱이 열려요")) {
                    if model.plus { RowValue(text: L("켜짐"), chevron: false) } else { PlusTag() }
                }
            }
        }
    }

    // MARK: 날씨 달력 · iCloud

    private var cloudSection: some View {
        Group {
            SectionLabel(text: L("날씨 달력"))
            RowGroup {
                SettingRow(icon: "cloud", title: L("iCloud에 보관"), subtitle: cloudLine) { toggle($cloud.enabled, L("iCloud에 보관")) }
            }
        }
    }

    private var cloudLine: String {
        switch cloud.status {
        case .off: return L("이 폰에만 보관해요")
        case .idle: return L("폰을 바꾸거나 앱을 다시 설치해도 날씨 달력과 받은 캐릭터가 그대로 남아요")
        case .syncing: return L("iCloud에 보관하는 중…")
        case .saved(let t): return L("iCloud에 보관했어요 · %@", Self.when(t))
        case .noAccount: return L("iCloud에 로그인하면 보관돼요")
        case .failed: return L("지금은 iCloud에 연결할 수 없어요")
        }
    }

    /// "14:32" today, "11월 7일" before (in the app's language)
    private static func when(_ t: Date) -> String {
        let f = DateFormatter(); f.locale = Lang.current.locale
        if Calendar.current.isDateInToday(t) { f.timeStyle = .short; f.dateStyle = .none }
        else { f.setLocalizedDateFormatFromTemplate("MMMd") }
        return f.string(from: t)
    }

    // MARK: 정보

    private var infoSection: some View {
        Group {
            SectionLabel(text: L("정보"))
            RowGroup {
                Button { go(.sources) } label: {
                    SettingRow(icon: "question", title: L("데이터 출처"), subtitle: model.isSample ? L("지금은 예시 날씨") : L("Apple 날씨 · 기상청 · MET Norway")) { RowChevron() }
                }.buttonStyle(.row)
                RowDivider()
                Button { go(.licenses) } label: { SettingRow(title: L("오픈소스 라이선스")) { RowChevron() } }
                    .buttonStyle(.row).accessibilityIdentifier("licenses")
                RowDivider()
                Link(destination: Legal.privacy) { SettingRow(title: L("개인정보 처리방침")) { RowChevron() } }.buttonStyle(.plain)
                if let mail = Legal.support {
                    RowDivider()
                    Link(destination: mail) { SettingRow(title: L("문의하기")) { RowChevron() } }.buttonStyle(.plain)
                }
                RowDivider()
                SettingRow(title: L("버전")) { RowValue(text: Self.version, chevron: false) }
            }
        }
    }

    // MARK: helpers

    /// `label`: the row's title, for VoiceOver (the row shows it already, so the switch hides its own)
    private func toggle(_ b: Binding<Bool>, _ label: String) -> some View {
        Toggle(label, isOn: b).labelsHidden().tint(UI.accent).onChange(of: b.wrappedValue) { _, _ in Haptic.select() }
    }

    private func go(_ r: Route) {
        Haptic.soft()
        route = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = r }
    }

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
}

/// 데이터 출처: the sources, what each one is used for, and the attribution each licence asks for.
struct SourcesView: View {
    @EnvironmentObject var model: AppModel
    @Binding var route: Route?
    @Environment(\.dismiss) private var dismiss

    private static let appleLegal = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    private static let kma = URL(string: "https://www.weather.go.kr")!
    private static let ccBy = URL(string: "https://creativecommons.org/licenses/by/4.0/")!
    private static let airkorea = URL(string: "https://www.airkorea.or.kr")!
    private static let openWeather = URL(string: "https://openweathermap.org/")!

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("데이터 출처")).font(.px(24)).foregroundStyle(UI.ink)
                    note
                    appleCard
                    kmaCard
                    metCard
                    airKoreaCard
                    openWeatherCard
                    otherCard
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(UI.bg)
    }

    /// "‹ 설정" on the left (back to settings), "완료" on the right.
    private var header: some View {
        HStack {
            Button {
                Haptic.soft(); route = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = .settings }
            } label: {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.ui(13, .bold)); Text(L("설정")) }
            }
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accentText).buttonStyle(.press(0.94))
            Spacer()
            Button { Haptic.soft(); dismiss() } label: { Text(L("완료")).tapArea() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(UI.accentText)  // darker than the accent for this text only, like SheetHeader
                .buttonStyle(.press(0.94)).accessibilityIdentifier("sheet-close")
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 14)
    }

    /// Which source does what for the place on screen (Korea: 기상청 first; elsewhere: Apple 날씨 first).
    private var noteText: String {
        let name = model.currentPlace.name
        if model.isSample { return L("지금은 예시 날씨예요. 서버가 연결되면 아래 출처의 예보를 보여 드려요.") }
        if model.currentPlace.region == "kr" {
            return L("지금 위치(%@)는 기상청 예보가 기본이고, 기상청 예보가 없는 뒤쪽 시간과 자외선은 Apple 날씨로 채워요. MET Norway는 예보 비교에 써요. 미세먼지는 에어코리아예요. 해외에선 Apple 날씨가 기본이에요.", name)
        }
        return L("지금 위치(%@)는 Apple 날씨로 예보를 보여주고, MET Norway는 예보 비교와 예비로 써요. 미세먼지는 OpenWeather예요. 한국에선 기상청이 기본이에요.", name)
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(UI.accent).padding(.top, 2)
            Text(noteText).font(.ui(12.5)).lineSpacing(3).foregroundStyle(UI.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UI.warm)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(UI.warmLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Apple's attribution: the words (or their mark) plus a link to their legal page, wherever WeatherKit data shows.
    private var appleCard: some View {
        card {
            HStack(spacing: 8) { Text(L("Apple 날씨")).font(.ui(15, .bold)); GreyTag(text: L("전 세계")) }
            HStack(spacing: 3) {
                Image(systemName: "apple.logo").font(.system(size: 11))
                Text("Weather data provided by Apple Weather").font(.ui(12, .semibold))
            }
            .foregroundStyle(UI.ink).padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(UI.sub, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            line(L("기본 예보 (한국 밖) · 한국에선 뒤쪽 시간 · 자외선 · 예보 비교"))
            link(L("Apple 날씨 출처 안내"), Self.appleLegal)
        }
    }

    private var kmaCard: some View {
        card {
            HStack(spacing: 8) { Text(L("기상청")).font(.ui(15, .bold)); GreyTag(text: L("한국")) }
            line(L("기본 예보 · 10일 예보 · 기상특보 · 예보 비교 · 다음 6시간(Plus)"))
            line(L("공공누리 제1유형(출처표시)"))
            link(L("기상청 날씨누리"), Self.kma)
        }
    }

    private var metCard: some View {
        card {
            HStack(spacing: 8) { Text("MET Norway").font(.ui(15, .bold)); GreyTag(text: L("전 세계")) }
            line(L("예보 비교 · 예비 예보 · Data from MET Norway"))
            line(L("CC BY 4.0 · 그래프로 바꿔 씀"))
            link(L("라이선스 보기"), Self.ccBy)
        }
    }

    private var airKoreaCard: some View {
        card {
            HStack(spacing: 8) { Text(L("에어코리아")).font(.ui(15, .bold)); GreyTag(text: L("한국")) }
            line(L("미세먼지 · 초미세먼지: 가까운 측정소의 실시간 값과 예보"))
            line(L("출처: 환경부 · 한국환경공단"))
            line(L("실시간 측정값은 확정 전 자료라 나중에 바뀔 수 있어요"))
            link(L("에어코리아"), Self.airkorea)
        }
    }

    // OpenWeather's free plan asks for these words and a link to their site wherever the data shows
    private var openWeatherCard: some View {
        card {
            HStack(spacing: 8) { Text("OpenWeather").font(.ui(15, .bold)); GreyTag(text: L("전 세계")) }
            line(L("미세먼지 · 초미세먼지 (한국 밖)"))
            Text("Weather data provided by OpenWeather").font(.ui(12, .semibold)).foregroundStyle(UI.ink)
            link("openweathermap.org", Self.openWeather)
        }
    }

    private var otherCard: some View {
        card {
            Text(L("그 밖에")).font(.ui(15, .bold))
            line(L("일출 · 일몰: 위치로 폰에서 계산"))
            line(L("지역 이름: countries-states-cities-database (ODbL 1.0) · 기상청 격자 위경도"))
            line(L("공휴일: holidays 오픈소스 (MIT)"))
            line(L("글꼴: Purrcast Pixel Medium (MGalmuri10 기반 · SIL OFL 1.1)"))
            Button {
                Haptic.soft(); route = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { route = .licenses }
            } label: { Text(L("라이선스 전문 보기")).font(.ui(12.5, .semibold)).underline().foregroundStyle(UI.accent) }
        }
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { c() }
            .foregroundStyle(UI.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(UI.row).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func line(_ t: String) -> some View { Text(t).font(.ui(12.5)).lineSpacing(3).foregroundStyle(UI.body) }
    private func link(_ t: String, _ url: URL) -> some View {
        Link(destination: url) { Text(t).font(.ui(12.5, .semibold)).underline().foregroundStyle(UI.accent) }
    }
}
