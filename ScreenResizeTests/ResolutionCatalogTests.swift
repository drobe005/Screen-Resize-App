import XCTest
import ScreenResizeCore

/// Group A — catalog integrity.
/// Pure data assertions: no display, no scale factor, no geometry.
final class ResolutionCatalogTests: XCTestCase {

    private var all: [Resolution] { ResolutionCatalog.all }

    // A1
    func testCatalogHoldsTheExpectedPresets() {
        let expected = [
            (7680, 4320), (3840, 2160), (3440, 1440), (3000, 2000),
            (2560, 1600), (2560, 1440), (2560, 1080), (2160, 1440),
            (1920, 1200), (1920, 1080), (1600, 1200), (1280, 720),
            (1024, 768), (960, 1080), (640, 480),
        ]
        let actual = all.map {
            (Int($0.pointSize.widthInPoints), Int($0.pointSize.heightInPoints))
        }
        XCTAssertEqual(actual.count, expected.count)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.0, e.0)
            XCTAssertEqual(a.1, e.1)
        }
    }

    // A2 — the list is flat and ordered largest first, so the menu needs no
    // grouping and no sorting of its own.
    func testCatalogIsSortedLargestFirst() {
        let dimensions = all.map {
            ($0.pointSize.widthInPoints, $0.pointSize.heightInPoints)
        }
        for (previous, next) in zip(dimensions, dimensions.dropFirst()) {
            XCTAssertTrue(
                previous.0 > next.0 || (previous.0 == next.0 && previous.1 > next.1),
                "\(previous) should sort before \(next)"
            )
        }
    }

    // A3
    func testEveryResolutionHasPositiveDimensions() {
        for resolution in all {
            XCTAssertGreaterThan(resolution.pointSize.widthInPoints, 0, resolution.name)
            XCTAssertGreaterThan(resolution.pointSize.heightInPoints, 0, resolution.name)
        }
    }

    // A4
    func testResolutionNamesAreUniqueAndMatchTheirDimensions() {
        let names = all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "names double as persisted IDs")

        for resolution in all {
            let expected = "\(Int(resolution.pointSize.widthInPoints))"
                + "x\(Int(resolution.pointSize.heightInPoints))"
            XCTAssertEqual(resolution.name, expected)
        }
    }

    // A5 — ultrawide entries are kept, but nothing in the model claims they are
    // 21:9. Their real reduced ratios are 64:27 and 43:18.
    func testUltrawidePresetsAreNotActuallyTwentyOneByNine() {
        let nominal: CGFloat = 21.0 / 9.0
        for name in ["2560x1080", "3440x1440"] {
            let resolution = all.first { $0.name == name }!
            let ratio = resolution.pointSize.widthInPoints / resolution.pointSize.heightInPoints
            XCTAssertGreaterThan(abs(ratio - nominal), 0.01,
                                 "\(name) is not 21:9 and must not be treated as such")
        }
        XCTAssertEqual(
            WindowGeometry.aspectRatioDescription(
                of: all.first { $0.name == "2560x1080" }!.pointSize), "64:27")
        XCTAssertEqual(
            WindowGeometry.aspectRatioDescription(
                of: all.first { $0.name == "3440x1440" }!.pointSize), "43:18")
    }
}
