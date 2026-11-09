import Foundation

/// Reads and writes other apps' preferences, the same store `defaults` uses
/// (current user, any host). Needs a non-sandboxed app.
enum Preferences {
    static let globalDomain = "NSGlobalDomain"

    static func read(_ domain: String, _ key: String) -> Any? {
        let app = applicationID(domain)
        CFPreferencesSynchronize(app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesCopyValue(key as CFString, app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    /// Writes a value, or removes the key (back to the macOS default) when `value` is nil.
    static func write(_ value: PrefValue?, _ domain: String, _ key: String) {
        let app = applicationID(domain)
        CFPreferencesSetValue(key as CFString, value?.propertyList, app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(app, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func applicationID(_ domain: String) -> CFString {
        domain == globalDomain || domain == ".GlobalPreferences"
            ? kCFPreferencesAnyApplication
            : domain as CFString
    }
}
