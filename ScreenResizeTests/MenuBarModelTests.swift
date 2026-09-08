import XCTest
import ScreenResizeCore

/// Group I — the menu's state machine and apply pipeline, entirely against mocks.
@MainActor
final class MenuBarModelTests: XCTestCase {

    private var windowManager: MockWindowManager!
    private var screens: MockScreenProvider!
    private var tracker: MockFrontmostTracker!
    private var defaults: UserDefaults!
    private var model: MenuBarModel!

    override func setUp() {
        super.setUp()
        windowManager = MockWindowManager()
        // A window sitting on the primary display.
        windowManager.storedFrame = Fixtures.frame(100, 100, 800, 600)
        screens = MockScreenProvider([Fixtures.primary, Fixtures.secondary])
        tracker = MockFrontmostTracker()
        defaults = UserDefaults(suiteName: "MenuBarModelTests-\(UUID().uuidString)")
        model = MenuBarModel(
            windowManager: windowManager, screens: screens,
            frontmostTracker: tracker, preferences: PreferencesStore(defaults: defaults)
        )
    }

    override func tearDown() {
        model = nil; tracker = nil; screens = nil; windowManager = nil; defaults = nil
        super.tearDown()
    }

    // MARK: - State

    func testI1_missingPermissionReplacesTheMenuBody() {
        windowManager.isTrusted = false
        model.refresh()
        XCTAssertEqual(model.state, .permissionRequired)
    }

    func testI2_missingPermissionExposesNoOptions() {
        windowManager.isTrusted = false
        model.refresh()
        for group in ResolutionCatalog.groups {
            XCTAssertTrue(model.options(in: group).isEmpty,
                          "No size lists may be offered without permission")
        }
    }

    func testI3_noFrontmostApplication() {
        tracker.lastActiveProcessIdentifier = nil
        windowManager.frontmostApp = nil
        model.refresh()
        XCTAssertEqual(model.state, .noTargetWindow(reason: "No application is active."))
    }

    func testI4_noFocusedWindow() {
        windowManager.focusedWindow = nil
        model.refresh()
        XCTAssertEqual(model.state,
                       .noTargetWindow(reason: "That application has no resizable window."))
    }

    func testI5_readySnapshotCarriesAppSizeAndScale() {
        model.refresh()
        guard case .ready(let snapshot) = model.state else {
            return XCTFail("Expected .ready, got \(model.state)")
        }
        XCTAssertEqual(snapshot.applicationName, "Safari")
        XCTAssertEqual(snapshot.currentSizeInPoints, PointSize(widthInPoints: 800, heightInPoints: 600))
        XCTAssertEqual(snapshot.backingScaleFactor, 2.0)
        XCTAssertEqual(snapshot.currentSizeDescription, "800 × 600 pt")
        XCTAssertEqual(snapshot.scaleDescription, "2× display")
    }

    func testI6_windowOnSecondaryDisplayReportsThatDisplaysScale() {
        windowManager.storedFrame = Fixtures.frame(-1000, -500, 400, 300)
        model.refresh()
        guard case .ready(let snapshot) = model.state else { return XCTFail("Expected .ready") }
        XCTAssertEqual(snapshot.backingScaleFactor, 1.0, "Should report the secondary display's scale")
    }

    func testI7_refreshClearsAStaleFailure() {
        windowManager.applyBehavior = .refuse
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))
        XCTAssertNotNil(model.failureMessage)

        model.refresh()
        XCTAssertNil(model.failureMessage, "Opening the menu clears the previous failure")
    }

    // MARK: - Fit

    func testI8_oversizedPresetIsDisabledAndSaysWhy() {
        model.refresh()
        let option = option(named: "7680x4320")
        XCTAssertFalse(option.isEnabled)
        XCTAssertEqual(option.menuLabel, "7680x4320 — too large for this display")
    }

    func testI9_fittingPresetIsEnabledAndShowsItsFriendlyLabel() {
        model.refresh()
        let option = option(named: "1280x720")
        XCTAssertTrue(option.isEnabled)
        XCTAssertEqual(option.menuLabel, "1280x720 — 720p / HD")
    }

    func testI10_fitIsRelativeToTheActiveDisplayNotAbsolute() {
        // The whole point of dropping the mode picker: sizing is always relative
        // to the display's own scale factor, and this is what "relative" means in
        // practice. 2560x1440 pixels is 2560x1440 points on a 1x display (does not
        // fit a 2000pt-wide visible frame) but 1280x720 points on a 2x display
        // (fits easily). Same preset, different displays, different outcome.
        model.refresh()
        let onPrimary2x = option(named: "2560x1440")
        XCTAssertTrue(onPrimary2x.isEnabled, "At 2x, 2560x1440 pixels is 1280x720 points, which fits")
        XCTAssertEqual(onPrimary2x.targetSizeInPoints,
                       PointSize(widthInPoints: 1280, heightInPoints: 720))
    }

    func testI10b_dockAndMenuBarCanStillDefeatAPreset() {
        // Worth pinning down: 3840x2160 at 2x is 1920x1080 POINTS, and 1920 fits
        // the 2000 pt width -- but 1080 exceeds the 1075 pt visible HEIGHT, because
        // the menu bar and Dock take 125 pt off a 1200 pt display. Halving by the
        // scale factor is not a guarantee that a preset fits.
        model.refresh()

        let option = option(named: "3840x2160")
        XCTAssertEqual(option.targetSizeInPoints,
                       PointSize(widthInPoints: 1920, heightInPoints: 1080))
        XCTAssertFalse(option.isEnabled, "1080 pt tall does not fit a 1075 pt visible frame")
        XCTAssertEqual(option.menuLabel, "3840x2160 — too large for this display")
    }

    // MARK: - Apply

    func testI12_applyResizesAndRecentersOnTheCurrentDisplay() {
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

        // 1280x720 PIXELS at this fixture's 2x scale is 640x360 POINTS.
        let expectedSize = PointSize(widthInPoints: 640, heightInPoints: 360)
        let expectedOrigin = WindowGeometry.centeredOriginInAXSpace(
            for: expectedSize, in: Fixtures.primary)

        XCTAssertEqual(windowManager.appliedFrames.count, 1)
        let applied = windowManager.appliedFrames[0]
        XCTAssertEqual(applied.size, expectedSize)
        XCTAssertEqual(applied.origin, expectedOrigin, "Window must be re-centred, not left in place")
        XCTAssertNil(model.failureMessage)
    }

    func testI13_rejectedResizeNamesTheApplicationThatRefused() {
        windowManager.applyBehavior = .refuse
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("Safari"), "Failure must name the app: \(message)")
        XCTAssertTrue(message.contains("refused"), message)
    }

    func testI14_partialResizeIsReportedWithBothSizes() {
        windowManager.applyBehavior = .clamp(
            to: PointSize(widthInPoints: 1000, heightInPoints: 700))
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("1000 × 700 pt"), message)
        XCTAssertTrue(message.contains("640 × 360 pt"), message)   // 1280x720 px at 2x
    }

    func testI15_applyingADisabledOptionDoesNothing() {
        model.refresh()
        model.apply(option(named: "7680x4320"))
        XCTAssertTrue(windowManager.appliedFrames.isEmpty, "A disabled option must not be applied")
    }

    func testI16_headerReflectsTheNewSizeAfterApplying() {
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

        guard case .ready(let snapshot) = model.state else { return XCTFail("Expected .ready") }
        // 1280x720 PIXELS at this fixture's 2x scale is 640x360 POINTS.
        XCTAssertEqual(snapshot.currentSizeDescription, "640 × 360 pt")
    }

    func testI17_applyTargetsTheTrackedAppNotWhateverIsFrontmost() {
        // The tracker names Safari; the "frontmost" app is ScreenResize itself,
        // which is exactly the situation opening the menu creates.
        windowManager.frontmostApp = MockApplicationHandle(
            processIdentifier: 999, localizedName: "ScreenResize")
        model.refresh()

        guard case .ready(let snapshot) = model.state else { return XCTFail("Expected .ready") }
        XCTAssertEqual(snapshot.applicationName, "Safari")
    }

    // MARK: - Q. Clamp surfacing and position recovery

    /// A display large enough that every catalog preset fits, used to get an
    /// option marked enabled before swapping the display out from under it.
    private var hugeDisplay: DisplayGeometry {
        DisplayGeometry(
            visibleFrameInAppKitPoints: AppKitPointRect(
                origin: AppKitPointOrigin(xInPoints: 0, yInPoints: 0),
                size: PointSize(widthInPoints: 10000, heightInPoints: 10000)
            ),
            backingScaleFactor: 2.0,
            primaryDisplayHeightInPoints: 10000
        )
    }

    func testQ1_aShrinkToFitIsReportedRatherThanAbsorbedSilently() {
        // Reproduces the display-changed-since-menu-open case: 7680x4320 is
        // enabled against the huge display, then the window is on the small one
        // by the time it is clicked.
        screens.configuredDisplays = [hugeDisplay]
        model.refresh()
        let option = option(named: "7680x4320")
        XCTAssertTrue(option.isEnabled, "precondition: enabled against the huge display")

        screens.configuredDisplays = [Fixtures.primary]
        model.apply(option)

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("Shrunk to"), "A silent shrink violates constraint 4: \(message)")
        XCTAssertTrue(message.contains("2000 × 1075 pt"), message)
    }

    func testQ2_aShrunkWindowIsCentredForTheSizeItActuallyGot() {
        // A regression lock, not a bug fix. Centring-then-clamping and
        // fitting-then-centring turn out to be equivalent: when a dimension is
        // clamped to the full visible extent there is zero slack left to centre
        // within, so both land on the same coordinate. Verified numerically
        // across the oversize cases before this test was written. The current
        // order is kept because it reads in the order it happens and makes the
        // "was it shrunk?" comparison fall out naturally.
        screens.configuredDisplays = [hugeDisplay]
        model.refresh()
        let option = option(named: "7680x4320")

        screens.configuredDisplays = [Fixtures.primary]
        model.apply(option)

        let fitted = PointSize(widthInPoints: 2000, heightInPoints: 1075)
        XCTAssertEqual(windowManager.appliedFrames.count, 1)
        XCTAssertEqual(windowManager.appliedFrames[0].size, fitted)
        XCTAssertEqual(
            windowManager.appliedFrames[0].origin,
            WindowGeometry.centeredOriginInAXSpace(for: fitted, in: Fixtures.primary),
            "Must be centred for the fitted size, not the requested one"
        )
    }

    func testQ3_aPartialResizeIsReCentredForTheSizeTheWindowTook() {
        // Borrowed from Raycast's window-sizer: when an app enforces its own
        // minimum, the window is left centred for a size it never adopted.
        let stubborn = PointSize(widthInPoints: 1000, heightInPoints: 700)
        windowManager.applyBehavior = .clamp(to: stubborn)
        model.refresh()

        model.apply(enabledOption(named: "1280x720"))

        XCTAssertEqual(windowManager.appliedFrames.count, 2,
                       "Expected a second write re-centring the window")
        XCTAssertEqual(
            windowManager.appliedFrames[1].origin,
            WindowGeometry.centeredOriginInAXSpace(for: stubborn, in: Fixtures.primary),
            "Second write must centre for the size the window actually took"
        )
        XCTAssertEqual(windowManager.appliedFrames[1].size, stubborn)
    }

    func testQ4_reCentringDoesNotMaskThePartialResizeMessage() {
        windowManager.applyBehavior = .clamp(
            to: PointSize(widthInPoints: 1000, heightInPoints: 700))
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("1000 × 700 pt"), message)
        XCTAssertTrue(message.contains("640 × 360 pt"), message)
    }

    func testQ5_anExactResizeReportsNothing() {
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

        XCTAssertNil(model.failureMessage)
        XCTAssertEqual(windowManager.appliedFrames.count, 1, "No recovery write when exact")
    }

    // MARK: - Helpers

    private func option(named name: String) -> ResolutionOption {
        for group in ResolutionCatalog.groups {
            if let match = model.options(in: group).first(where: { $0.resolution.name == name }) {
                return match
            }
        }
        fatalError("No option named \(name)")
    }

    private func enabledOption(named name: String) -> ResolutionOption {
        let option = option(named: name)
        XCTAssertTrue(option.isEnabled, "\(name) should be enabled for this test")
        return option
    }
}
