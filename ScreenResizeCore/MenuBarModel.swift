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
/// The view renders `menuLabel`. It never computes fit and
/// never formats a resolution, which is what keeps resolution literals out of the
/// UI layer entirely.
public struct ResolutionOption: Identifiable, Equatable {
    public let resolution: Resolution

    /// The size that will actually be applied — already reduced to fit the
    /// display, so it is what the window will become, not merely what was asked.
    public let targetSizeInPoints: PointSize

    /// True when the preset is larger than the display and will therefore fill
    /// it rather than reach its nominal size. Nothing is disabled: an oversized
    /// preset still works, it just cannot exceed the screen.
    public let exceedsDisplay: Bool

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

    /// Starred resolution IDs, in star order.
    @Published public private(set) var favoriteResolutionIDs: [String] = []

    /// User-defined sizes, in the order they were added.
    @Published public private(set) var customSizes: [CustomSize] = []

    /// Whether the app is registered to start at login. Read from the system,
    /// never cached in preferences.
    @Published public private(set) var launchesAtLogin: Bool = false

    /// Why launch-at-login may be unavailable, if it is.
    public var launchAtLoginAvailability: LoginItemAvailability { loginItem.availability }

    /// Set when a launch-at-login change was refused.
    @Published public private(set) var launchAtLoginError: String?

    private let windowManager: WindowManaging
    private let screens: ScreenProviding
    private let frontmostTracker: FrontmostApplicationTracking
    private let preferences: PreferencesStore
    private let trustMonitor: AccessibilityTrustMonitoring
    private let settingsOpener: SystemSettingsOpening
    private let loginItem: LoginItemManaging

    /// The display the target window currently occupies. Established by
    /// `refresh()`; nil whenever there is no usable window.
    private var currentDisplay: DisplayGeometry?

    public init(
        windowManager: WindowManaging,
        screens: ScreenProviding,
        frontmostTracker: FrontmostApplicationTracking,
        preferences: PreferencesStore = PreferencesStore(),
        trustMonitor: AccessibilityTrustMonitoring = SystemTrustMonitor(),
        settingsOpener: SystemSettingsOpening = WorkspaceSettingsOpener(),
        loginItem: LoginItemManaging = SMAppServiceLoginItem()
    ) {
        self.windowManager = windowManager
        self.screens = screens
        self.frontmostTracker = frontmostTracker
        self.preferences = preferences
        self.trustMonitor = trustMonitor
        self.settingsOpener = settingsOpener
        self.loginItem = loginItem
        self.favoriteResolutionIDs = preferences.favoriteResolutionIDs
        self.customSizes = preferences.customSizes
        self.launchesAtLogin = loginItem.isEnabled
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
    /// The built-in presets, largest first. Empty when there is no window to act on.
    public func presetOptions() -> [ResolutionOption] {
        guard currentDisplay != nil else { return [] }
        return ResolutionCatalog.all.compactMap(makeOption(for:))
    }

    /// The user's own sizes, in the order they were added.
    public func customOptions() -> [ResolutionOption] {
        guard currentDisplay != nil else { return [] }
        return customSizes.map(\.resolution).compactMap(makeOption(for:))
    }

    /// Starred resolutions, in star order, resolved against the current display.
    ///
    /// IDs that no longer name anything are skipped rather than surfacing as
    /// broken rows: a custom size can be deleted while still starred.
    public func favoriteOptions() -> [ResolutionOption] {
        guard currentDisplay != nil else { return [] }
        return favoriteResolutionIDs
            .compactMap { id in allResolutions.first { $0.id == id } }
            .compactMap(makeOption(for:))
    }

    /// Every resolution the app knows about, built-in and custom.
    public var allResolutions: [Resolution] {
        ResolutionCatalog.all + customSizes.map(\.resolution)
    }

    /// Adds a custom size after validating it.
    ///
    /// - Throws: `CustomSizeError`. Refusals are surfaced, never silently
    ///   clamped into something the user did not ask for.
    public func addCustomSize(widthInPoints: Int, heightInPoints: Int) throws {
        guard widthInPoints > 0, heightInPoints > 0 else {
            throw CustomSizeError.notPositive
        }
        let maximum = CustomSizeLimits.maximumInPoints
        guard widthInPoints <= maximum, heightInPoints <= maximum else {
            throw CustomSizeError.tooLarge(maximumInPoints: maximum)
        }

        let candidate = CustomSize(widthInPoints: widthInPoints, heightInPoints: heightInPoints)
        guard !allResolutions.contains(where: { $0.id == candidate.id }) else {
            throw CustomSizeError.duplicate(name: candidate.id)
        }

        customSizes.append(candidate)
        preferences.customSizes = customSizes
    }

    /// Removes a custom size, and unstars it if it was starred.
    public func removeCustomSize(_ size: CustomSize) {
        customSizes.removeAll { $0.id == size.id }
        preferences.customSizes = customSizes

        if let index = favoriteResolutionIDs.firstIndex(of: size.id) {
            favoriteResolutionIDs.remove(at: index)
            preferences.favoriteResolutionIDs = favoriteResolutionIDs
        }
    }

    public func isFavorite(_ resolution: Resolution) -> Bool {
        favoriteResolutionIDs.contains(resolution.id)
    }

    /// Stars or unstars a resolution. Newly starred entries append, so existing
    /// positions do not shift underneath anything addressing them by index.
    public func toggleFavorite(_ resolution: Resolution) {
        if let index = favoriteResolutionIDs.firstIndex(of: resolution.id) {
            favoriteResolutionIDs.remove(at: index)
        } else {
            favoriteResolutionIDs.append(resolution.id)
        }
        preferences.favoriteResolutionIDs = favoriteResolutionIDs
    }

    private func makeOption(for resolution: Resolution) -> ResolutionOption? {
        guard let display = currentDisplay else { return nil }

        let requested = WindowGeometry.targetPointSize(for: resolution)
        let fitted = WindowGeometry.sizeThatFits(requested, in: display)
        let exceedsDisplay = fitted != requested

        // Built here, from resolution.name, never from digits in a view.
        // An oversized preset says so up front rather than being greyed out:
        // on a 1800pt-wide display most of the catalog exceeds the screen, and a
        // menu of disabled rows would be useless. See CLAUDE.md constraint 4 —
        // the oversize is surfaced, it is simply surfaced before the click
        // instead of after it.
        let label: String
        if exceedsDisplay {
            label = "\(resolution.name) — fills this display"
        } else {
            label = resolution.name
        }

        return ResolutionOption(
            resolution: resolution,
            targetSizeInPoints: fitted,
            exceedsDisplay: exceedsDisplay,
            menuLabel: label
        )
    }

    // MARK: - Apply

    /// Resizes and re-centres the target window on the display it occupies.
    public func apply(_ option: ResolutionOption) {
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

            let requestedSize = WindowGeometry.targetPointSize(for: option.resolution)

            // Fit the SIZE first, then centre for whatever size survived.
            // Centring for the requested size and clamping afterwards leaves the
            // window off-centre exactly when it was shrunk, because the origin
            // was computed for a box that no longer exists.
            let fittedSize = WindowGeometry.sizeThatFits(requestedSize, in: display)
            let origin = WindowGeometry.centeredOriginInAXSpace(for: fittedSize, in: display)
            let (target, adjustment) = WindowGeometry.clamped(
                PointFrame(origin: origin, size: fittedSize), to: display
            )

            // Never absorb a shrink silently — CLAUDE.md constraint 4 — but do
            // not nag about one the menu already announced. `exceedsDisplay`
            // means the row said "fills this display" before it was clicked; a
            // clamp that was NOT announced means the display changed since the
            // menu opened, and that is worth a banner.
            var note: String?
            if fittedSize != requestedSize, !option.exceedsDisplay {
                note = "Shrunk to \(Self.describe(fittedSize)) to fit this display."
            }
            if note == nil, adjustment == .resized || adjustment == .movedAndResized {
                note = "Adjusted to \(Self.describe(target.size)) to fit this display."
            }

            switch try windowManager.applyFrame(target, to: window) {
            case .exact:
                failureMessage = note

            case .partial(let requested, let actual):
                // The window took a size of its own choosing — a minimum width,
                // a character-cell grid, whatever. It is now centred for a size
                // it never adopted, so re-centre for the size it actually has.
                recentre(window: window, at: actual, on: display)

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

    /// Re-centres a window that ended up a different size than requested.
    ///
    /// Best effort: the window has already been resized, so a failure here means
    /// it is merely off-centre, and reporting that on top of the size mismatch
    /// would be noise. The original outcome message is what matters.
    private func recentre(window: WindowHandle, at size: PointSize, on display: DisplayGeometry) {
        let origin = WindowGeometry.centeredOriginInAXSpace(for: size, in: display)
        let (frame, _) = WindowGeometry.clamped(
            PointFrame(origin: origin, size: size), to: display
        )
        _ = try? windowManager.applyFrame(frame, to: window)
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

    /// Registers or unregisters the app as a login item.
    ///
    /// Re-reads the system afterwards rather than trusting the requested value,
    /// so a refused registration cannot leave the toggle showing a lie.
    public func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
            launchAtLoginError = nil
        } catch let error as LoginItemError {
            if case .unavailable(let reason) = error { launchAtLoginError = reason }
        } catch {
            launchAtLoginError = "\(error)"
        }
        launchesAtLogin = loginItem.isEnabled
    }

    /// Applies the favorite occupying `slot`, a zero-based position.
    ///
    /// Hotkeys address favorites by position rather than identity, because
    /// KeyboardShortcuts binds to fixed names decided at compile time while the
    /// favorites list is whatever the user starred.
    ///
    /// Refreshes first: a hotkey fires with no menu open, so nothing has
    /// established which window or display is being targeted.
    public func applyFavoriteSlot(_ slot: Int) {
        refresh()

        let options = favoriteOptions()
        guard options.indices.contains(slot) else {
            // An unbound or empty slot does nothing, but says so rather than
            // leaving the user wondering whether the key registered.
            failureMessage = "No favorite is assigned to shortcut \(slot + 1)."
            return
        }

        apply(options[slot])
    }

    /// Opens System Settings at Privacy & Security → Accessibility.
    public func openAccessibilitySettings() {
        settingsOpener.openAccessibilityPane()
    }
}
