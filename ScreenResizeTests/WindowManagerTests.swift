import XCTest
import ScreenResizeCore

/// Exercises the window control surface against MockWindowManager.
/// No real windows, no Accessibility API, no permission.
final class WindowManagerTests: XCTestCase {

    private var manager: MockWindowManager!

    override func setUp() {
        super.setUp()
        manager = MockWindowManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    private let target = PointFrame(
        origin: PointOrigin(xInPoints: 100, yInPoints: 50),
        size: PointSize(widthInPoints: 1280, heightInPoints: 720)
    )

    // MARK: - Permission

    func testUntrustedProcessReportsNotTrusted() {
        manager.isTrusted = false
        XCTAssertFalse(manager.isProcessTrusted())
    }

    func testUntrustedProcessThrowsPermissionDenied() {
        manager.isTrusted = false
        XCTAssertThrowsError(try manager.frontmostApplication()) { error in
            XCTAssertEqual(error as? WindowManagerError, .permissionDenied)
        }
    }

    // MARK: - Lookup failures

    func testNoFrontmostApplicationThrows() {
        manager.frontmostApp = nil
        XCTAssertThrowsError(try manager.frontmostApplication()) { error in
            XCTAssertEqual(error as? WindowManagerError, .noFrontmostApp)
        }
    }

    func testNoFocusedWindowThrows() throws {
        manager.focusedWindow = nil
        let app = try manager.frontmostApplication()
        XCTAssertThrowsError(try manager.focusedWindow(of: app)) { error in
            XCTAssertEqual(error as? WindowManagerError, .noFocusedWindow)
        }
    }

    // MARK: - Reading

    func testFrameIsReadInPoints() throws {
        manager.storedFrame = PointFrame(
            origin: PointOrigin(xInPoints: 12, yInPoints: 34),
            size: PointSize(widthInPoints: 640, heightInPoints: 480)
        )
        let window = try manager.focusedWindow(of: manager.frontmostApplication())
        let frame = try manager.frame(of: window)

        XCTAssertEqual(frame.origin.xInPoints, 12)
        XCTAssertEqual(frame.origin.yInPoints, 34)
        XCTAssertEqual(frame.size.widthInPoints, 640)
        XCTAssertEqual(frame.size.heightInPoints, 480)
    }

    // MARK: - The three outcomes

    func testAcceptingWindowReportsExactAndUpdatesFrame() throws {
        manager.applyBehavior = .accept
        let window = try manager.focusedWindow(of: manager.frontmostApplication())

        let outcome = try manager.applyFrame(target, to: window)

        XCTAssertEqual(outcome, .exact)
        XCTAssertEqual(try manager.frame(of: window), target)
    }

    func testClampingWindowReportsPartialWithBothSizes() throws {
        let clamped = PointSize(widthInPoints: 1024, heightInPoints: 720)
        manager.applyBehavior = .clamp(to: clamped)
        let window = try manager.focusedWindow(of: manager.frontmostApplication())

        let outcome = try manager.applyFrame(target, to: window)

        XCTAssertEqual(outcome, .partial(requested: target.size, actual: clamped))
    }

    func testRefusingWindowThrowsResizeRejectedWithBothSizes() throws {
        let original = manager.storedFrame
        manager.applyBehavior = .refuse
        let window = try manager.focusedWindow(of: manager.frontmostApplication())

        XCTAssertThrowsError(try manager.applyFrame(target, to: window)) { error in
            XCTAssertEqual(
                error as? WindowManagerError,
                .resizeRejected(requested: target.size, actual: original.size)
            )
        }
        XCTAssertEqual(manager.storedFrame, original, "A rejected resize must not change the window")
    }

    func testResizeToCurrentSizeIsExactNotRejected() throws {
        // A window already at the requested size did not "refuse" anything.
        manager.applyBehavior = .refuse
        manager.storedFrame = target
        let window = try manager.focusedWindow(of: manager.frontmostApplication())

        XCTAssertEqual(try manager.applyFrame(target, to: window), .exact)
    }

    // MARK: - Handle safety

    func testForeignHandleIsRejectedWithoutTouchingAccessibility() {
        // AXWindowManager guards the handle type before making any AX call, so
        // this stays true to "tests never touch the real Accessibility API".
        let real = AXWindowManager()
        XCTAssertThrowsError(try real.frame(of: MockWindowHandle())) { error in
            XCTAssertEqual(error as? WindowManagerError, .unsupportedHandle)
        }
    }

    // MARK: - Write ordering

    func testWriteSequenceIsSizeOriginSize() {
        // Locks the empirical ordering documented on WindowWriteSequence.standard.
        // Changing it should require changing this test deliberately.
        XCTAssertEqual(WindowWriteSequence.standard, [.size, .origin, .size])
    }

    // MARK: - Tolerance

    func testSubPointDifferenceCountsAsExact() throws {
        manager.applyBehavior = .clamp(
            to: PointSize(widthInPoints: 1279.6, heightInPoints: 720.4)
        )
        let window = try manager.focusedWindow(of: manager.frontmostApplication())

        XCTAssertEqual(try manager.applyFrame(target, to: window), .exact,
                       "Fractional-point landings must not be reported as partial")
    }
}
