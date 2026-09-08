import XCTest
import ScreenResizeCore

/// Group M — aspect ratio math and custom sizes.
@MainActor
final class CustomSizeTests: XCTestCase {

    private var windowManager: MockWindowManager!
    private var defaults: UserDefaults!
    private var model: MenuBarModel!

    override func setUp() {
        super.setUp()
        windowManager = MockWindowManager()
        windowManager.storedFrame = Fixtures.frame(100, 100, 800, 600)
        defaults = UserDefaults(suiteName: "CustomSizeTests-\(UUID().uuidString)")
        model = makeModel()
        model.refresh()
    }

    private func makeModel() -> MenuBarModel {
        MenuBarModel(
            windowManager: windowManager,
            screens: MockScreenProvider([Fixtures.primary]),
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

    private func ratio(_ w: CGFloat, _ h: CGFloat) -> String? {
        WindowGeometry.aspectRatioDescription(
            of: PointSize(widthInPoints: w, heightInPoints: h))
    }

    // MARK: - Aspect ratio reduction

    func testM1_commonRatiosReduceCorrectly() {
        XCTAssertEqual(ratio(1920, 1080), "16:9")
        XCTAssertEqual(ratio(1024, 768), "4:3")
        XCTAssertEqual(ratio(2560, 1600), "8:5")     // 16:10 reduces further
        XCTAssertEqual(ratio(2160, 1440), "3:2")
    }

    func testM2_ultrawideRatiosAreNotTwentyOneByNine() {
        // The reason group headings are labels, not math. See Phase 3.
        XCTAssertEqual(ratio(2560, 1080), "64:27")
        XCTAssertEqual(ratio(3440, 1440), "43:18")
    }

    func testM3_anArbitraryTypedSizeReduces() {
        XCTAssertEqual(ratio(1720, 1080), "43:27")
    }

    func testM4_coprimeDimensionsAreLeftAlone() {
        XCTAssertEqual(ratio(1001, 999), "1001:999")
    }

    func testM5_nonPositiveSizeHasNoRatioRatherThanDividingByZero() {
        XCTAssertNil(ratio(0, 1080))
        XCTAssertNil(ratio(1920, 0))
        XCTAssertNil(ratio(-1920, -1080))
    }

    // MARK: - Adding and validating

    func testM6_addingACustomSizeMakesItAvailableAsAGroup() throws {
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)

        let options = model.customOptions()
        XCTAssertEqual(options.map(\.resolution.name), ["1720x1080"])
        XCTAssertEqual(options[0].resolution.label, "43:27")
    }

    func testM7_customSizesBehaveExactlyLikeBuiltInPresets() throws {
        // Custom sizes are points, like every preset. The middle case is the one
        // worth pinning: 1080 is the obvious height and it misses the 1075pt
        // visible frame by five points, because the menu bar and Dock take 125pt
        // off a 1200pt display.
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1000)
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)
        try model.addCustomSize(widthInPoints: 9000, heightInPoints: 9000)

        let options = model.customOptions()

        XCTAssertFalse(options[0].exceedsDisplay, "1000pt tall fits a 1075pt frame")
        XCTAssertTrue(options[1].exceedsDisplay, "1080pt tall exceeds a 1075pt frame by 5")
        XCTAssertEqual(options[1].menuLabel, "1720x1080 — fills this display")
        XCTAssertTrue(options[2].exceedsDisplay)
        XCTAssertEqual(options[2].menuLabel, "9000x9000 — fills this display")
    }

    func testM8_nonPositiveDimensionsAreRefused() {
        XCTAssertThrowsError(try model.addCustomSize(widthInPoints: 0, heightInPoints: 1080)) {
            XCTAssertEqual($0 as? CustomSizeError, .notPositive)
        }
    }

    func testM9_absurdDimensionsAreRefusedRatherThanClamped() {
        let maximum = CustomSizeLimits.maximumInPoints
        XCTAssertThrowsError(
            try model.addCustomSize(widthInPoints: maximum + 1, heightInPoints: 1080)
        ) {
            XCTAssertEqual($0 as? CustomSizeError, .tooLarge(maximumInPoints: maximum))
        }
        XCTAssertTrue(model.customSizes.isEmpty, "A refused size must not be stored")
    }

    func testM10_duplicatesAreRefusedIncludingAgainstBuiltInPresets() throws {
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)
        XCTAssertThrowsError(try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)) {
            XCTAssertEqual($0 as? CustomSizeError, .duplicate(name: "1720x1080"))
        }
        // 1920x1080 already exists in the shipped catalog.
        XCTAssertThrowsError(try model.addCustomSize(widthInPoints: 1920, heightInPoints: 1080)) {
            XCTAssertEqual($0 as? CustomSizeError, .duplicate(name: "1920x1080"))
        }
    }

    // MARK: - Persistence and interaction with favorites

    func testM11_customSizesPersistAcrossModelInstances() throws {
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)
        XCTAssertEqual(makeModel().customSizes.map(\.id), ["1720x1080"])
    }

    func testM12_aCustomSizeCanBeStarred() throws {
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)
        let custom = try XCTUnwrap(model.customSizes.first?.resolution)

        model.toggleFavorite(custom)

        XCTAssertTrue(model.isFavorite(custom))
        XCTAssertEqual(model.favoriteOptions().map(\.resolution.name), ["1720x1080"])
    }

    func testM13_removingAStarredCustomSizeAlsoUnstarsIt() throws {
        try model.addCustomSize(widthInPoints: 1720, heightInPoints: 1080)
        let size = try XCTUnwrap(model.customSizes.first)
        model.toggleFavorite(size.resolution)
        XCTAssertEqual(model.favoriteResolutionIDs, ["1720x1080"])

        model.removeCustomSize(size)

        XCTAssertTrue(model.customSizes.isEmpty)
        XCTAssertTrue(model.favoriteResolutionIDs.isEmpty,
                      "A deleted size must not linger as a dangling favorite")
        XCTAssertTrue(model.customOptions().isEmpty)
    }

    func testM14_corruptStoredDataYieldsNoCustomSizesRatherThanCrashing() {
        defaults.set(Data("not json".utf8), forKey: "ScreenResize.customSizes")
        XCTAssertTrue(PreferencesStore(defaults: defaults).customSizes.isEmpty)
    }
}
