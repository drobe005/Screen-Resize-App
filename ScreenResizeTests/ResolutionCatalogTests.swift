import XCTest
import ScreenResizeCore

/// Group A — catalog integrity.
/// Pure data assertions: no display, no scale factor, no geometry.
final class ResolutionCatalogTests: XCTestCase {

    private var groups: [AspectRatioGroup] { ResolutionCatalog.groups }

    // A1
    func testCatalogHasFiveGroupsInOrder() {
        XCTAssertEqual(groups.map(\.heading), ["16:9", "16:10", "3:2", "21:9", "4:3"])
    }

    // A2
    func testGroupSizesAndTotalCount() {
        XCTAssertEqual(groups.map(\.resolutions.count), [5, 2, 2, 2, 3])
        XCTAssertEqual(groups.flatMap(\.resolutions).count, 14)
    }

    // A3
    func testEveryGroupHoldsTheSpecifiedResolutionsInOrder() throws {
        let expected: [String: [(Int, Int)]] = [
            "16:9":  [(1280, 720), (1920, 1080), (2560, 1440), (3840, 2160), (7680, 4320)],
            "16:10": [(1920, 1200), (2560, 1600)],
            "3:2":   [(2160, 1440), (3000, 2000)],
            "21:9":  [(2560, 1080), (3440, 1440)],
            "4:3":   [(640, 480), (1024, 768), (1600, 1200)],
        ]

        XCTAssertEqual(Set(groups.map(\.heading)), Set(expected.keys))
        for group in groups {
            let wanted = try XCTUnwrap(expected[group.heading], "Unexpected group \(group.heading)")
            let actual = group.resolutions.map {
                (Int($0.pixelSize.widthInPixels), Int($0.pixelSize.heightInPixels))
            }
            XCTAssertEqual(actual.count, wanted.count, "Group \(group.heading)")
            for (a, w) in zip(actual, wanted) {
                XCTAssertEqual(a.0, w.0, "Group \(group.heading) width")
                XCTAssertEqual(a.1, w.1, "Group \(group.heading) height")
            }
        }
    }

    // A4
    func testEveryResolutionHasPositiveDimensions() {
        for resolution in groups.flatMap(\.resolutions) {
            XCTAssertGreaterThan(resolution.pixelSize.widthInPixels, 0, resolution.name)
            XCTAssertGreaterThan(resolution.pixelSize.heightInPixels, 0, resolution.name)
        }
    }

    // A5 — the group heading is a marketing label, not a computed ratio.
    // Nothing in the geometry layer may derive an aspect ratio from it.
    func testTwentyOneByNineHeadingIsNotTheActualRatio() throws {
        let nominal: CGFloat = 21.0 / 9.0            // 2.3333
        let ultrawide = try XCTUnwrap(groups.first { $0.heading == "21:9" }).resolutions
        XCTAssertEqual(ultrawide.count, 2)

        let ratios = ultrawide.map { $0.pixelSize.widthInPixels / $0.pixelSize.heightInPixels }

        XCTAssertEqual(ratios[0], 2560.0 / 1080.0, accuracy: 0.0001)  // 64:27, 2.3704
        XCTAssertEqual(ratios[1], 3440.0 / 1440.0, accuracy: 0.0001)  // 43:18, 2.3889
        for ratio in ratios {
            XCTAssertGreaterThan(abs(ratio - nominal), 0.01,
                                 "Heading 21:9 must not be treated as the real ratio")
        }
    }

    // A6
    func testResolutionNamesAreUniqueAcrossTheCatalog() {
        let names = groups.flatMap(\.resolutions).map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }
}
