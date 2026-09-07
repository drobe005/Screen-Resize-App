import Combine
import CoreGraphics
import Foundation

/// What the menu should be showing.
public enum MenuState: Equatable {
    /// Accessibility permission is missing. The menu body is replaced wholesale
    /// by a call to action; no size lists are offered.
    case permissionRequired
    /// Permission is fine, but there is nothing to resize right now.
    case noTargetWindow(reason: String)
    /// A window is available and its details are known.
    case ready(WindowSnapshot)
}

/// What the header shows, captured at the moment the menu opened.
public struct WindowSnapshot: Equatable {
    public let applicationName: String
    public let currentSizeInPoints: PointSize
    public let backingScaleFactor: CGFloat

    public init(applicationName: String, currentSizeInPoints: PointSize, backingScaleFactor: CGFloat) {
        self.applicationName = applicationName
        self.currentSizeInPoints = currentSizeInPoints
        self.backingScaleFactor = backingScaleFactor
    }

    /// e.g. "1512 × 945 pt"
    public var currentSizeDescription: String {
        "\(Int(currentSizeInPoints.widthInPoints.rounded())) × "
            + "\(Int(currentSizeInPoints.heightInPoints.rounded())) pt"
    }

    /// e.g. "2× display"
    public var scaleDescription: String {
        let scale = backingScaleFactor
        let formatted = scale == scale.rounded()
            ? String(Int(scale))
            : String(format: "%.1f", Double(scale))
        return "\(formatted)× display"
    }
}

/// One row in an aspect-ratio submenu, fully resolved.
///
/// The view renders `menuLabel` and reads `isEnabled`. It never computes fit and
/// never formats a resolution, which is what keeps resolution literals out of the
/// UI layer entirely.
public struct ResolutionOption: Identifiable, Equatable {
    public let resolution: Resolution
    public let targetSizeInPoints: PointSize
    public let isEnabled: Bool
    public let menuLabel: String

    public var id: String { resolution.id }
}

/// The single source of truth behind the menu.
///
/// Lives in Core rather than the app target so it can be unit tested: the test
/// bundle is host-less and links only this framework.
@MainActor
public final class MenuBarModel: ObservableObject {

    @Published public private(set) var state: MenuState = .permissionRequired
    @Published public private(set) var failureMessage: String?

    /// Whether this process is currently trusted for Accessibility.
    ///
    /// Separate from `state` because onboarding presentation keys off trust
    /// alone: a trusted app with no focused window is still perfectly set up and
    /// must not be shown the onboarding window.
    @Published public private(set) var isTrusted: Bool = false

    @Published public var sizingMode: SizingMode {
        didSet {
            guard sizingMode != oldValue else { return }
            preferences.sizingMode = sizingMode
        }
    }

    private let windowManager: WindowManaging
    private let screens: ScreenProviding
    private let frontmostTracker: FrontmostApplicationTracking
    private let preferences: PreferencesStore
    private let trustMonitor: AccessibilityTrustMonitoring
    private let settingsOpener: SystemSettingsOpening

    /// The display the target window currently occupies. Established by
    /// `refresh()`; nil whenever there is no usable window.
    private var currentDisplay: DisplayGeometry?

    public init(
        windowManager: WindowManaging,
        screens: ScreenProviding,
        frontmostTracker: FrontmostApplicationTracking,
        preferences: PreferencesStore = PreferencesStore(),
        trustMonitor: AccessibilityTrustMonitoring = SystemTrustMonitor(),
        settingsOpener: SystemSettingsOpening = WorkspaceSettingsOpener()
    ) {
        self.windowManager = windowManager
        self.screens = screens
        self.frontmostTracker = frontmostTracker
        self.preferences = preferences
        self.trustMonitor = trustMonitor
        self.settingsOpener = settingsOpener
        self.sizingMode = preferences.sizingMode
        self.isTrusted = windowManager.isProcessTrusted()

        // Re-check whenever trust may have changed, so a permission granted in
        // System Settings takes effect without relaunching the app.
        self.trustMonitor.onPossibleTrustChange = { [weak self] in
            self?.handlePossibleTrustChange()
        }
        self.trustMonitor.start()
    }


    // MARK: - Refresh

    /// Recomputes everything the menu shows. Called when the menu opens, and
    /// only then — nothing here is polled or scheduled.
    public func refresh() {
        failureMessage = nil
        isTrusted = windowManager.isProcessTrusted()
        reloadSnapshot()
    }

    /// Called by the trust monitor. Acts only on a genuine change.
    ///
    /// Deliberately not a full `refresh()`: these notifications fire on ordinary
    /// app activation, and clearing `failureMessage` every time the user tabbed
    /// away and back would wipe the explanation of a resize that had just been
    /// refused.
    private func handlePossibleTrustChange() {
        let trusted = windowManager.isProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        reloadSnapshot()
    }

    /// Re-reads window state without disturbing `failureMessage`, so a failure
    /// raised by `apply` survives the refresh that follows it.
    private func reloadSnapshot() {
        guard windowManager.isProcessTrusted() else {
            currentDisplay = nil
            isTrusted = false
            state = .permissionRequired
            return
        }

        do {
            let application = try targetApplication()
            let window = try windowManager.focusedWindow(of: application)
            let frame = try windowManager.frame(of: window)

            guard let display = WindowGeometry.displayContaining(frame, among: screens.displays()) else {
                currentDisplay = nil
                state = .noTargetWindow(reason: "That window is not on any display.")
                return
            }

            currentDisplay = display
            state = .ready(WindowSnapshot(
                applicationName: application.localizedName ?? "Focused window",
                currentSizeInPoints: frame.size,
                backingScaleFactor: display.backingScaleFactor
            ))
        } catch {
            currentDisplay = nil
            state = Self.state(for: error)
        }
    }

    private static func state(for error: Error) -> MenuState {
        guard let error = error as? WindowManagerError else {
            return .noTargetWindow(reason: "\(error)")
        }
        switch error {
        case .permissionDenied:
            return .permissionRequired
        case .noFrontmostApp:
            return .noTargetWindow(reason: "No application is active.")
        case .noFocusedWindow:
            return .noTargetWindow(reason: "That application has no resizable window.")
        default:
            return .noTargetWindow(reason: error.description)
        }
    }

    /// The application to act on: the last one the user actually worked in,
    /// falling back to whatever is frontmost.
    private func targetApplication() throws -> ApplicationHandle {
        if let pid = frontmostTracker.lastActiveProcessIdentifier {
            return windowManager.application(
                withProcessIdentifier: pid,
                localizedName: frontmostTracker.lastActiveApplicationName
            )
        }
        return try windowManager.frontmostApplication()
    }

    // MARK: - Options

    /// The rows for one aspect-ratio group, resolved against the current display
    /// and sizing mode. Empty when there is no window to act on.
    public func options(in group: AspectRatioGroup) -> [ResolutionOption] {
        guard let display = currentDisplay else { return [] }

        return group.resolutions.map { resolution in
            let target = WindowGeometry.targetPointSize(
                for: resolution,
                mode: sizingMode,
                backingScaleFactor: display.backingScaleFactor
            )
            let fits = WindowGeometry.fits(target, in: display)

            // Built here, from resolution.name — never from digits in a view.
            let label: String
            if fits {
                label = resolution.label.map { "\(resolution.name) — \($0)" } ?? resolution.name
            } else {
                label = "\(resolution.name) — too large for this display"
            }

            return ResolutionOption(
                resolution: resolution,
                targetSizeInPoints: target,
                isEnabled: fits,
                menuLabel: label
            )
        }
    }

    // MARK: - Apply

    /// Resizes and re-centres the target window on the display it occupies.
    public func apply(_ option: ResolutionOption) {
        guard option.isEnabled else { return }

        var applicationName = "That application"
        do {
            let application = try targetApplication()
            applicationName = application.localizedName ?? applicationName

            let window = try windowManager.focusedWindow(of: application)
            let currentFrame = try windowManager.frame(of: window)

            guard let display = WindowGeometry.displayContaining(
                currentFrame, among: screens.displays()
            ) else {
                failureMessage = "Could not tell which display that window is on."
                return
            }

            let size = WindowGeometry.targetPointSize(
                for: option.resolution, mode: sizingMode,
                backingScaleFactor: display.backingScaleFactor
            )
            let origin = WindowGeometry.centeredOriginInAXSpace(for: size, in: display)
            let (target, _) = WindowGeometry.clamped(
                PointFrame(origin: origin, size: size), to: display
            )

            switch try windowManager.applyFrame(target, to: window) {
            case .exact:
                failureMessage = nil
            case .partial(let requested, let actual):
                // A partial resize is not silent: CLAUDE.md constraint 3.
                failureMessage = "\(applicationName) resized to "
                    + "\(Self.describe(actual)) instead of \(Self.describe(requested))."
            }

            reloadSnapshot()
        } catch WindowManagerError.resizeRejected(let requested, _) {
            failureMessage = "\(applicationName) refused to resize to \(Self.describe(requested))."
        } catch let error as WindowManagerError {
            failureMessage = error.description
        } catch {
            failureMessage = "\(error)"
        }
    }

    private static func describe(_ size: PointSize) -> String {
        "\(Int(size.widthInPoints.rounded())) × \(Int(size.heightInPoints.rounded())) pt"
    }

    // MARK: - Permission

    /// Prompts for Accessibility permission and re-evaluates.
    ///
    /// The system prompt appears at most once per app identity. Once a user has
    /// dismissed or denied it, this silently does nothing forever — which is why
    /// `openAccessibilitySettings()` exists alongside it rather than as a
    /// redundant second route.
    public func requestPermission() {
        _ = windowManager.promptForAccessibilityPermission()
        refresh()
    }

    /// Opens System Settings at Privacy & Security → Accessibility.
    public func openAccessibilitySettings() {
        settingsOpener.openAccessibilityPane()
    }
}
