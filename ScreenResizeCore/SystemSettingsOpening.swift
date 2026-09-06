import AppKit

/// Opens the Accessibility pane of System Settings.
///
/// Behind a protocol so the model's use of it is assertable in a test without
/// System Settings actually launching.
@MainActor
public protocol SystemSettingsOpening: AnyObject {
    func openAccessibilityPane()
}

@MainActor
public final class WorkspaceSettingsOpener: SystemSettingsOpening {

    /// Deep link to Privacy & Security → Accessibility.
    ///
    /// The `x-apple.systempreferences:` scheme is registered by System Settings,
    /// and `com.apple.preference.security` still resolves on macOS 26/27 even
    /// though the old System Preferences panes are gone.
    public static let accessibilityPaneURL =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    // nonisolated for use as a default argument; touches no isolated state.
    public nonisolated init() {}

    public func openAccessibilityPane() {
        guard let url = URL(string: Self.accessibilityPaneURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
