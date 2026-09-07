import XCTest
import ScreenResizeCore

/// Group K — preference persistence.
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

    func testK1_sizingModeDefaultsToLogical() {
        XCTAssertEqual(store.sizingMode, .logical)
    }

    func testK2_sizingModeRoundTrips() {
        store.sizingMode = .capture
        XCTAssertEqual(store.sizingMode, .capture)
    }

    func testK3_sizingModeSurvivesANewStoreOverTheSameDefaults() {
        store.sizingMode = .capture
        XCTAssertEqual(PreferencesStore(defaults: defaults).sizingMode, .capture)
    }

    func testK4_unrecognisedStoredValueFallsBackToTheDefault() {
        // A value written by a future version, or a corrupted plist, must not
        // crash or produce a nonsense mode.
        defaults.set("teleport", forKey: "ScreenResize.sizingMode")
        XCTAssertEqual(store.sizingMode, .logical)
    }

    func testK5_storesAreIsolatedByDefaultsInstance() {
        store.sizingMode = .capture
        let other = PreferencesStore(
            defaults: UserDefaults(suiteName: "PreferencesStoreTests-other-\(UUID().uuidString)")!)
        XCTAssertEqual(other.sizingMode, .logical)
    }
}
