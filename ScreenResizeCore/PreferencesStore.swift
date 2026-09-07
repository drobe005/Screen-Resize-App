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
        static let sizingMode = "ScreenResize.sizingMode"
        static let favoriteResolutionIDs = "ScreenResize.favoriteResolutionIDs"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// How preset numbers are interpreted. Defaults to `.logical`.
    public var sizingMode: SizingMode {
        get {
            defaults.string(forKey: Key.sizingMode)
                .flatMap(SizingMode.init(rawValue:)) ?? .logical
        }
        set { defaults.set(newValue.rawValue, forKey: Key.sizingMode) }
    }

    /// Starred resolution IDs, in the order they were starred.
    ///
    /// Order is meaningful and must be preserved: hotkey slots address favorites
    /// by position, so re-sorting this would silently repoint a user's shortcuts.
    public var favoriteResolutionIDs: [String] {
        get { defaults.stringArray(forKey: Key.favoriteResolutionIDs) ?? [] }
        set { defaults.set(newValue, forKey: Key.favoriteResolutionIDs) }
    }
}
