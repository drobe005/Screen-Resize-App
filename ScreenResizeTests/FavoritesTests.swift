import XCTest
import ScreenResizeCore

/// Group L — favorites.
@MainActor
final class FavoritesTests: XCTestCase {

    private var windowManager: MockWindowManager!
    private var defaults: UserDefaults!
    private var model: MenuBarModel!

    override func setUp() {
        super.setUp()
        windowManager = MockWindowManager()
        windowManager.storedFrame = Fixtures.frame(100, 100, 800, 600)
        defaults = UserDefaults(suiteName: "FavoritesTests-\(UUID().uuidString)")
        model = makeModel()
        model.refresh()
    }

    private func makeModel() -> MenuBarModel {
        MenuBarModel(
            windowManager: windowManager,
            screens: MockScreenProvider([Fixtures.primary, Fixtures.secondary]),
            frontmostTracker: MockFrontmostTracker(),
            preferences: PreferencesStore(defaults: defaults),
            trustMonitor: MockTrustMonitor(),
            settingsOpener: MockSettingsOpener()
        )
    }

    override func tearDown() {
        model = nil; defaults = nil; windowManager = nil
        super.tearDown()
    }

    private func resolution(_ name: String) -> Resolution { Fixtures.catalogResolution(name) }

    func testL1_nothingIsFavoritedByDefault() {
        XCTAssertTrue(model.favoriteResolutionIDs.isEmpty)
        XCTAssertTrue(model.favoriteOptions().isEmpty)
    }

    func testL2_togglingStarsAndUnstars() {
        let hd = resolution("1280x720")
        model.toggleFavorite(hd)
        XCTAssertTrue(model.isFavorite(hd))
        model.toggleFavorite(hd)
        XCTAssertFalse(model.isFavorite(hd))
    }

    func testL3_favoritesKeepStarOrderAndNewOnesAppend() {
        model.toggleFavorite(resolution("2560x1440"))
        model.toggleFavorite(resolution("1280x720"))
        model.toggleFavorite(resolution("1920x1080"))

        XCTAssertEqual(model.favoriteResolutionIDs, ["2560x1440", "1280x720", "1920x1080"],
                       "New stars must append; reordering would repoint anything indexing them")
    }

    func testL4_unstarringPreservesTheOrderOfTheRest() {
        model.toggleFavorite(resolution("2560x1440"))
        model.toggleFavorite(resolution("1280x720"))
        model.toggleFavorite(resolution("1920x1080"))

        model.toggleFavorite(resolution("1280x720"))   // remove the middle one

        XCTAssertEqual(model.favoriteResolutionIDs, ["2560x1440", "1920x1080"])
    }

    func testL5_favoritesPersistAcrossModelInstances() {
        model.toggleFavorite(resolution("1920x1080"))
        let reloaded = makeModel()
        XCTAssertEqual(reloaded.favoriteResolutionIDs, ["1920x1080"])
    }

    func testL6_favoriteOptionsCarryFitStateLikeAnyOtherRow() {
        model.toggleFavorite(resolution("1280x720"))
        model.toggleFavorite(resolution("7680x4320"))

        let options = model.favoriteOptions()
        XCTAssertEqual(options.count, 2)
        XCTAssertFalse(options[0].exceedsDisplay)
        XCTAssertTrue(options[1].exceedsDisplay)
        XCTAssertEqual(options[1].menuLabel, "7680x4320 — fills this display")
    }

    func testL7_unknownFavoriteIDIsSkippedNotSurfacedAsABrokenRow() {
        // Simulates a custom size that was deleted while still starred.
        PreferencesStore(defaults: defaults).favoriteResolutionIDs = ["1280x720", "9999x9999"]
        let reloaded = makeModel()
        reloaded.refresh()

        XCTAssertEqual(reloaded.favoriteOptions().map(\.resolution.name), ["1280x720"])
    }

    func testL8_noFavoritesAreOfferedWhileUntrusted() {
        model.toggleFavorite(resolution("1280x720"))
        windowManager.isTrusted = false
        model.refresh()
        XCTAssertTrue(model.favoriteOptions().isEmpty)
    }
}
