import Foundation

// MARK: - Language Bundle Swizzle
//
// Replaces Bundle.main's class with LanguageBundle so that ALL lookups —
// SwiftUI Text("key"), NSLocalizedString, String(localized:) — go through
// the user-selected language, regardless of the device locale.

final class LanguageBundle: Bundle, @unchecked Sendable {

    // The lproj bundle matching the user's in-app language choice.
    private static var _override: Bundle?

    /// Call once at app launch (before any view is shown).
    static func activate() {
        // Change Bundle.main's ISA pointer so our override is active.
        object_setClass(Bundle.main, LanguageBundle.self)
        // Apply the persisted language immediately.
        if let lang = UserDefaults.standard.string(forKey: "appLanguage") {
            setLanguage(lang)
        }
    }

    /// Switch the active language and persist the choice.
    static func setLanguage(_ lang: String) {
        UserDefaults.standard.set(lang, forKey: "appLanguage")
        // Also tell the OS so system-level formatters (DatePicker etc.) follow suit.
        UserDefaults.standard.set([lang], forKey: "AppleLanguages")

        // Locate the matching .lproj inside the app bundle.
        // Use `super` path lookup to avoid going through our own override.
        guard
            let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            _override = nil
            return
        }
        _override = bundle
    }

    // MARK: - The one override that makes everything work

    override func localizedString(forKey key: String,
                                  value: String?,
                                  table tableName: String?) -> String {
        guard let bundle = LanguageBundle._override else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        let result = bundle.localizedString(forKey: key, value: "", table: tableName)
        // If the language bundle has no entry, fall back to the base bundle.
        return result.isEmpty ? super.localizedString(forKey: key, value: value, table: tableName) : result
    }
}

// MARK: - Convenience helper (use for runtime-interpolated strings only)
//
// Prefer Text("xcstrings-key") for static strings — it goes through the
// swizzled bundle automatically.  Use localized() only when you need to
// build a String at runtime (e.g. chip labels, format strings).

func localized(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

// Three-argument form kept for backward compatibility with existing call sites.
func localized(_ ko: String, _ en: String, _ de: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
    switch lang {
    case "en": return en
    case "de": return de
    default:   return ko
    }
}
