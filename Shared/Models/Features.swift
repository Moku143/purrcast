import Foundation

/// Product switches. Anything the paywall promises must exist in the app, so these gate the wording too.
enum Features {
    /// The free app shows no ads today, so Plus does not advertise "광고 없이". Turn on together with an ad SDK
    /// (and the tracking-consent screen + privacy manifest entries that come with it).
    static let adsInFree = false
}
