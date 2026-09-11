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
        XCTAssertTrue(model.presetOptions().isEmpty,
                      "No size lists may be offered without permission")
        XCTAssertTrue(model.customOptions().isEmpty)
        XCTAssertTrue(model.favoriteOptions().isEmpty)
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
        model.apply(option(named: "1280x720"))
        XCTAssertNotNil(model.failureMessage)

        model.refresh()
        XCTAssertNil(model.failureMessage, "Opening the menu clears the previous failure")
    }

    // MARK: - Fit

    func testI8_oversizedPresetSaysItWillFillTheDisplay() {
        model.refresh()
        let option = option(named: "7680x4320")
        XCTAssertTrue(option.exceedsDisplay)
        XCTAssertEqual(option.menuLabel, "7680x4320 — fills this display")
        // The row still works; it just cannot exceed the screen.
        XCTAssertEqual(option.targetSizeInPoints,
                       PointSize(widthInPoints: 2000, heightInPoints: 1075))
    }

    func testI9_fittingPresetIsEnabledAndShowsJustItsSize() {
        model.refresh()
        let option = option(named: "1280x720")
        XCTAssertFalse(option.exceedsDisplay)
        XCTAssertEqual(option.menuLabel, "1280x720")
    }

    func testI10_aPresetIsTheSamePointSizeOnEveryDisplay() {
        // Presets are points, applied as-is. The backing scale factor is not
        // consulted, so the same preset yields the same on-screen size on a 1x
        // and a 2x display alike.
        model.refresh()
        let onTwoX = option(named: "1280x720").targetSizeInPoints

        screens.configuredDisplays = [Fixtures.secondary]      // 1600x975 @1x
        windowManager.storedFrame = Fixtures.frame(-1000, -500, 400, 300)
        model.refresh()
        let onOneX = option(named: "1280x720").targetSizeInPoints

        XCTAssertEqual(onTwoX, PointSize(widthInPoints: 1280, heightInPoints: 720))
        XCTAssertEqual(onOneX, onTwoX, "Scale factor must not change a preset's point size")
    }

    func testI10b_aFivePointOverflowStillCountsAsExceeding() {
        // The trap that has caught me repeatedly: 1080 is the obvious height and
        // it does NOT fit, because the menu bar and Dock take 125pt off a 1200pt
        // display, leaving 1075. Five points short.
        model.refresh()

        let option = option(named: "1920x1080")
        XCTAssertTrue(option.exceedsDisplay, "1080pt exceeds a 1075pt visible frame")
        XCTAssertEqual(option.menuLabel, "1920x1080 — fills this display")
        XCTAssertEqual(option.targetSizeInPoints,
                       PointSize(widthInPoints: 1920, heightInPoints: 1075),
                       "Only the overflowing dimension is reduced")
    }

    // MARK: - Apply

    func testI12_applyResizesAndRecentersOnTheCurrentDisplay() {
        model.refresh()
        model.apply(option(named: "1280x720"))

        let expectedSize = PointSize(widthInPoints: 1280, heightInPoints: 720)
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
        model.apply(option(named: "1280x720"))

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("Safari"), "Failure must name the app: \(message)")
        XCTAssertTrue(message.contains("refused"), message)
    }

    func testI14_partialResizeIsReportedWithBothSizes() {
        windowManager.applyBehavior = .clamp(
            to: PointSize(widthInPoints: 1000, heightInPoints: 700))
        model.refresh()
        model.apply(option(named: "1280x720"))

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("1000 × 700 pt"), message)
        XCTAssertTrue(message.contains("1280 × 720 pt"), message)
    }

    func testI15_applyingAnOversizedPresetFillsTheDisplay() {
        model.refresh()
        model.apply(option(named: "7680x4320"))

        XCTAssertEqual(windowManager.appliedFrames.count, 1, "Oversized presets still apply")
        XCTAssertEqual(windowManager.appliedFrames[0].size,
                       PointSize(widthInPoints: 2000, heightInPoints: 1075))
        XCTAssertNil(model.failureMessage,
                     "The row already said it would fill the display; do not warn twice")
    }

    func testI16_headerReflectsTheNewSizeAfterApplying() {
        model.refresh()
        model.apply(option(named: "1280x720"))

        guard case .ready(let snapshot) = model.state else { return XCTFail("Expected .ready") }
        XCTAssertEqual(snapshot.currentSizeDescription, "1280 × 720 pt")
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
        XCTAssertFalse(option.exceedsDisplay, "precondition: fits the huge display")

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

        model.apply(option(named: "1280x720"))

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
        model.apply(option(named: "1280x720"))

        let message = model.failureMessage ?? ""
        XCTAssertTrue(message.contains("1000 × 700 pt"), message)
        XCTAssertTrue(message.contains("1280 × 720 pt"), message)
    }

    func testQ5_anExactResizeReportsNothing() {
        model.refresh()
        model.apply(option(named: "1280x720"))

        XCTAssertNil(model.failureMessage)
        XCTAssertEqual(windowManager.appliedFrames.count, 1, "No recovery write when exact")
    }

    // MARK: - Helpers

    private func option(named name: String) -> ResolutionOption {
        let all = model.presetOptions() + model.customOptions()
        guard let match = all.first(where: { $0.resolution.name == name }) else {
            fatalError("No option named \(name)")
        }
        return match
    }

}
