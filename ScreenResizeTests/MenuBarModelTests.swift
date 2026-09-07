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
        model.sizingMode = .logical
        model.refresh()
        let option = option(named: "7680x4320")
        XCTAssertFalse(option.isEnabled)
        XCTAssertEqual(option.menuLabel, "7680x4320 — too large for this display")
    }

    func testI9_fittingPresetIsEnabledAndShowsItsFriendlyLabel() {
        model.sizingMode = .logical
        model.refresh()
        let option = option(named: "1280x720")
        XCTAssertTrue(option.isEnabled)
        XCTAssertEqual(option.menuLabel, "1280x720 — 720p / HD")
    }

    func testI10_captureModeEnablesPresetsThatLogicalModeCannotFit() {
        model.refresh()

        model.sizingMode = .logical
        let logical = option(named: "2560x1440")
        model.sizingMode = .capture
        let capture = option(named: "2560x1440")

        XCTAssertFalse(logical.isEnabled, "2560 points is wider than the 2000 pt visible frame")
        XCTAssertTrue(capture.isEnabled, "At 2x it is 1280x720 points, which fits")
    }

    func testI10b_dockAndMenuBarCanStillDefeatACaptureModePreset() {
        // Worth pinning down: 3840x2160 at 2x is 1920x1080 POINTS, and 1920 fits
        // the 2000 pt width -- but 1080 exceeds the 1075 pt visible HEIGHT, because
        // the menu bar and Dock take 125 pt off a 1200 pt display. Halving by the
        // scale factor is not a guarantee that a preset fits.
        model.sizingMode = .capture
        model.refresh()

        let option = option(named: "3840x2160")
        XCTAssertEqual(option.targetSizeInPoints,
                       PointSize(widthInPoints: 1920, heightInPoints: 1080))
        XCTAssertFalse(option.isEnabled, "1080 pt tall does not fit a 1075 pt visible frame")
        XCTAssertEqual(option.menuLabel, "3840x2160 — too large for this display")
    }

    func testI11_sizingModePersistsAcrossModelInstances() {
        model.sizingMode = .capture
        let reloaded = MenuBarModel(
            windowManager: windowManager, screens: screens,
            frontmostTracker: tracker, preferences: PreferencesStore(defaults: defaults)
        )
        XCTAssertEqual(reloaded.sizingMode, .capture)
    }

    // MARK: - Apply

    func testI12_applyResizesAndRecentersOnTheCurrentDisplay() {
        model.sizingMode = .logical
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

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
        XCTAssertTrue(message.contains("1280 × 720 pt"), message)
    }

    func testI15_applyingADisabledOptionDoesNothing() {
        model.sizingMode = .logical
        model.refresh()
        model.apply(option(named: "7680x4320"))
        XCTAssertTrue(windowManager.appliedFrames.isEmpty, "A disabled option must not be applied")
    }

    func testI16_headerReflectsTheNewSizeAfterApplying() {
        model.sizingMode = .logical
        model.refresh()
        model.apply(enabledOption(named: "1280x720"))

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
