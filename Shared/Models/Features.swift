import Foundation

/// Product switches. Anything the paywall promises must exist in the app, so these gate the wording too.
enum Features {
    /// The free app shows no ads today, so Plus does not advertise "광고 없이". Turn on together with an ad SDK
    /// (and the tracking-consent screen + privacy manifest entries that come with it).
    static let adsInFree = false
    /// 비 지도 (Plus, Korea): the app side is ready; on once the server has the 기상청 API허브 key for both pictures
    /// (레이더 합성영상 and 1시간 강수예측). Off: no card, no paywall line, nothing loaded.
    static let radar = false
}
