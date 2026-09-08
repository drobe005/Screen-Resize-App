import XCTest
import ScreenResizeCore

/// Group O — hotkey slot resolution. Covers everything except the key press
/// itself, which belongs to KeyboardShortcuts and is not faked here.
@MainActor
final class FavoriteSlotTests: XCTestCase {

    private var windowManager: MockWindowManager!
    private var model: MenuBarModel!

    override func setUp() {
        super.setUp()
        windowManager = MockWindowManager()
        windowManager.storedFrame = Fixtures.frame(100, 100, 800, 600)
        model = MenuBarModel(
            windowManager: windowManager,
            screens: MockScreenProvider([Fixtures.primary]),
            frontmostTracker: MockFrontmostTracker(),
            preferences: PreferencesStore(
                defaults: UserDefaults(suiteName: "FavoriteSlotTests-\(UUID().uuidString)")!),
            trustMonitor: MockTrustMonitor(),
            settingsOpener: MockSettingsOpener(),
            loginItem: MockLoginItem()
        )
        model.refresh()
    }

    override func tearDown() {
        model = nil; windowManager = nil
        super.tearDown()
    }

    func testO1_slotIdentifiersAndTitlesAreOneBasedForHumans() {
        XCTAssertEqual(FavoriteSlot.title(for: 0), "Favorite 1")
        XCTAssertEqual(FavoriteSlot.identifier(for: 0), "favorite1")
        XCTAssertEqual(Array(FavoriteSlot.indices), [0, 1, 2, 3, 4])
    }

    func testO2_firingASlotAppliesTheFavoriteAtThatPosition() {
        model.toggleFavorite(Fixtures.catalogResolution("3840x2160"))   // slot 0
        model.toggleFavorite(Fixtures.catalogResolution("1280x720"))    // slot 1

        model.applyFavoriteSlot(1)

        XCTAssertEqual(windowManager.appliedFrames.count, 1)
        XCTAssertEqual(windowManager.appliedFrames[0].size,
                       PointSize(widthInPoints: 1280, heightInPoints: 720))
    }

    func testO3_firingWithoutAMenuOpenStillResolvesTheDisplay() {
        // applyFavoriteSlot refreshes first; without that there is no
        // currentDisplay and nothing would be applied at all.
        let fresh = MenuBarModel(
            windowManager: windowManager,
            screens: MockScreenProvider([Fixtures.primary]),
            frontmostTracker: MockFrontmostTracker(),
            preferences: PreferencesStore(
                defaults: UserDefaults(suiteName: "FavoriteSlotTests-fresh-\(UUID().uuidString)")!),
            trustMonitor: MockTrustMonitor(),
            settingsOpener: MockSettingsOpener(),
            loginItem: MockLoginItem()
        )
        fresh.toggleFavorite(Fixtures.catalogResolution("1280x720"))

        fresh.applyFavoriteSlot(0)   // no refresh() called by the test

        XCTAssertEqual(windowManager.appliedFrames.count, 1)
    }

    func testO4_emptySlotSaysSoRatherThanDoingNothingSilently() {
        model.applyFavoriteSlot(0)
        XCTAssertTrue(windowManager.appliedFrames.isEmpty)
        XCTAssertEqual(model.failureMessage, "No favorite is assigned to shortcut 1.")
    }

    func testO5_outOfRangeSlotIsHandled() {
        model.toggleFavorite(Fixtures.catalogResolution("1280x720"))
        model.applyFavoriteSlot(4)
        XCTAssertTrue(windowManager.appliedFrames.isEmpty)
        XCTAssertNotNil(model.failureMessage)
    }

    func testO6_slotPointingAtAnOversizedPresetFillsTheDisplay() {
        // Nothing is refused any more: an oversized preset fills the screen
        // rather than doing nothing, which is what makes a hotkey worth pressing.
        model.toggleFavorite(Fixtures.catalogResolution("7680x4320"))

        model.applyFavoriteSlot(0)

        XCTAssertEqual(windowManager.appliedFrames.count, 1)
        XCTAssertEqual(windowManager.appliedFrames[0].size,
                       PointSize(widthInPoints: 2000, heightInPoints: 1075))
    }

    func testO7_restarringRepointsASlotRatherThanBreakingIt() {
        model.toggleFavorite(Fixtures.catalogResolution("1280x720"))
        model.toggleFavorite(Fixtures.catalogResolution("1280x720"))   // unstar
        model.toggleFavorite(Fixtures.catalogResolution("1024x768"))   // new occupant of slot 0

        model.applyFavoriteSlot(0)

        XCTAssertEqual(windowManager.appliedFrames[0].size,
                       PointSize(widthInPoints: 1024, heightInPoints: 768))
    }
}
