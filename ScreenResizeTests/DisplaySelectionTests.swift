import XCTest
import ScreenResizeCore

/// Groups G and H — the AX-space visible rect and display selection.
final class DisplaySelectionTests: XCTestCase {

    private let primary = Fixtures.primary
    private let secondary = Fixtures.secondary

    // MARK: - G. visibleRectInAXSpace

    func testG1_primaryVisibleRectSitsBelowTheMenuBar() {
        let rect = WindowGeometry.visibleRectInAXSpace(of: primary)
        XCTAssertEqual(rect.origin.xInPoints, 0, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.yInPoints, 25, accuracy: 0.0001)
        XCTAssertEqual(rect.size.widthInPoints, 2000, accuracy: 0.0001)
        XCTAssertEqual(rect.size.heightInPoints, 1075, accuracy: 0.0001)
    }

    func testG2_displayAboveAndLeftHasNegativeAXOrigin() {
        let rect = WindowGeometry.visibleRectInAXSpace(of: secondary)
        XCTAssertEqual(rect.origin.xInPoints, -1600, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.yInPoints, -975, accuracy: 0.0001)
    }

    func testG3_visibleRectAgreesWithClampBounds() {
        // A frame pinned to the visible rect must survive clamping untouched.
        let rect = WindowGeometry.visibleRectInAXSpace(of: primary)
        let result = WindowGeometry.clamped(rect, to: primary)
        XCTAssertEqual(result.adjustment, .none)
        XCTAssertEqual(result.frame, rect)
    }

    // MARK: - H. displayContaining

    func testH1_windowWhollyOnPrimary() {
        let display = WindowGeometry.displayContaining(
            Fixtures.frame(100, 100, 500, 400), among: [primary, secondary])
        XCTAssertEqual(display, primary)
    }

    func testH2_windowWhollyOnSecondary() {
        let display = WindowGeometry.displayContaining(
            Fixtures.frame(-1000, -500, 400, 300), among: [primary, secondary])
        XCTAssertEqual(display, secondary)
    }

    func testH3_straddlingWindowPicksTheLargerOverlap() {
        // x -300...300, y -200...200.
        // Secondary overlap: 300 wide x 200 tall = 60000
        // Primary overlap:   300 wide x 175 tall = 52500
        let display = WindowGeometry.displayContaining(
            Fixtures.frame(-300, -200, 600, 400), among: [primary, secondary])
        XCTAssertEqual(display, secondary, "Should follow the display holding most of the window")
    }

    func testH4_windowOffEveryDisplayReturnsNil() {
        XCTAssertNil(WindowGeometry.displayContaining(
            Fixtures.frame(5000, 5000, 100, 100), among: [primary, secondary]))
    }

    func testH5_emptyDisplayListReturnsNil() {
        XCTAssertNil(WindowGeometry.displayContaining(Fixtures.frame(0, 25, 100, 100), among: []))
    }
}
