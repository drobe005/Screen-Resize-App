import XCTest
import ScreenResizeCore

/// Group K — preference persistence, tested directly against the store rather
/// than only indirectly through MenuBarModel.
final class PreferencesStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: PreferencesStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PreferencesStoreTests-\(UUID().uuidString)")
        store = PreferencesStore(defaults: defaults)
    }

    override func tearDown() {
        store = nil; defaults = nil
        super.tearDown()
    }

    // MARK: - favoriteResolutionIDs

    func testK1_favoriteResolutionIDsDefaultsToEmpty() {
        XCTAssertEqual(store.favoriteResolutionIDs, [])
    }

    func testK2_favoriteResolutionIDsRoundTripsAndPreservesOrder() {
        store.favoriteResolutionIDs = ["1920x1080", "1280x720"]
        XCTAssertEqual(store.favoriteResolutionIDs, ["1920x1080", "1280x720"])
    }

    func testK3_favoriteResolutionIDsSurviveANewStoreOverTheSameDefaults() {
        store.favoriteResolutionIDs = ["1920x1080"]
        XCTAssertEqual(
            PreferencesStore(defaults: defaults).favoriteResolutionIDs, ["1920x1080"])
    }

    // MARK: - customSizes

    func testK4_customSizesDefaultsToEmpty() {
        XCTAssertEqual(store.customSizes, [])
    }

    func testK5_customSizesRoundTrip() {
        let size = CustomSize(widthInPoints: 1720, heightInPoints: 1000)
        store.customSizes = [size]
        XCTAssertEqual(store.customSizes, [size])
    }

    func testK6_corruptCustomSizesDataYieldsEmptyRatherThanCrashing() {
        defaults.set(Data("not json".utf8), forKey: "ScreenResize.customSizes")
        XCTAssertEqual(store.customSizes, [])
    }

    // MARK: - Isolation

    func testK7_storesAreIsolatedByDefaultsInstance() {
        store.favoriteResolutionIDs = ["1920x1080"]
        let other = PreferencesStore(
            defaults: UserDefaults(suiteName: "PreferencesStoreTests-other-\(UUID().uuidString)")!)
        XCTAssertEqual(other.favoriteResolutionIDs, [])
    }
}
