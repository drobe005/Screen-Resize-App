import Foundation

/// Every persisted preference, and the only place that knows a defaults key.
///
/// **Where this writes:** `~/Library/Preferences/com.deiondrickroberts.ScreenResize.plist`.
/// Note that this is the real Preferences directory, not `~/Library/Containers/…`:
/// the app is unsandboxed by necessity, because the Accessibility API cannot run
/// inside the App Sandbox. See CLAUDE.md, hard constraint 1.
///
/// **Why UserDefaults:** the data is small, non-secret, key-value shaped and
/// machine-specific. The system handles atomic writes and caching, and the
/// values survive app updates and moving the bundle.
///
/// **Deliberately not used:** a JSON file in Application Support would mean
/// hand-rolling atomic writes, corruption recovery and migration for no benefit
/// at this size; the Keychain is for secrets and none of this is one; and
/// iCloud syncing would be actively wrong, since hotkeys collide differently per
/// machine and a size that fits one display may not fit another.
///
/// **Deliberately not stored here:** launch-at-login lives in `SMAppService`, and
/// hotkey bindings live in `KeyboardShortcuts`. Mirroring system state into
/// defaults creates two sources of truth that disagree the moment the user
/// changes one of them somewhere else.
public final class PreferencesStore {

    private enum Key {
        static let favoriteResolutionIDs = "ScreenResize.favoriteResolutionIDs"
        static let customSizes = "ScreenResize.customSizes"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Starred resolution IDs, in the order they were starred.
    ///
    /// Order is meaningful and must be preserved: hotkey slots address favorites
    /// by position, so re-sorting this would silently repoint a user's shortcuts.
    public var favoriteResolutionIDs: [String] {
        get { defaults.stringArray(forKey: Key.favoriteResolutionIDs) ?? [] }
        set { defaults.set(newValue, forKey: Key.favoriteResolutionIDs) }
    }

    /// User-defined sizes, in the order they were added.
    ///
    /// Encoded as JSON rather than a plist array of dictionaries so the shape is
    /// owned by `Codable` and a future field addition does not need a manual
    /// migration. A value that fails to decode yields an empty list rather than
    /// crashing on launch.
    public var customSizes: [CustomSize] {
        get {
            guard let data = defaults.data(forKey: Key.customSizes) else { return [] }
            return (try? JSONDecoder().decode([CustomSize].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.customSizes)
        }
    }
}
