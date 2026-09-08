import XCTest
import ScreenResizeCore

/// Groups B–F — the pure geometry functions.
///
/// Two synthetic displays. Nothing here touches NSScreen, so the secondary
/// display exists even though this machine only has one panel.
final class WindowGeometryTests: XCTestCase {

    // P (primary): 2000x1200, 25pt menu bar at top, 100pt Dock at bottom, @2x.
    // visibleFrame spans AppKit y 100...1175.
    private let primary = DisplayGeometry(
        visibleFrameInAppKitPoints: AppKitPointRect(
            origin: AppKitPointOrigin(xInPoints: 0, yInPoints: 100),
            size: PointSize(widthInPoints: 2000, heightInPoints: 1075)
        ),
        backingScaleFactor: 2.0,
        primaryDisplayHeightInPoints: 1200
    )

    // S (secondary): 1600x1000, positioned ABOVE and LEFT of P.
    // AppKit x -1600...0, y 1200...2200. Note primaryDisplayHeightInPoints is
    // still P's 1200 — the flip is always about the primary display.
    private let secondary = DisplayGeometry(
        visibleFrameInAppKitPoints: AppKitPointRect(
            origin: AppKitPointOrigin(xInPoints: -1600, yInPoints: 1200),
            size: PointSize(widthInPoints: 1600, heightInPoints: 975)
        ),
        backingScaleFactor: 1.0,
        primaryDisplayHeightInPoints: 1200
    )

    private func resolution(_ w: CGFloat, _ h: CGFloat) -> Resolution {
        Resolution(
            name: "\(Int(w))x\(Int(h))",
            pixelSize: PixelSize(widthInPixels: w, heightInPixels: h),
            label: nil
        )
    }

    private func assertSize(
        _ actual: PointSize, _ w: CGFloat, _ h: CGFloat,
        accuracy: CGFloat = 0.0001, _ message: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(actual.widthInPoints, w, accuracy: accuracy, "width \(message)", file: file, line: line)
        XCTAssertEqual(actual.heightInPoints, h, accuracy: accuracy, "height \(message)", file: file, line: line)
    }

    // MARK: - B. targetPointSize
    //
    // There is exactly one interpretation: a preset's numbers are physical
    // pixels, divided by the target display's own scale factor. This makes the
    // result relative to whichever display it is applied on — the same preset
    // yields a different point size (and thus a different on-screen pixel
    // footprint match) on a 1x display than on a 2x one. That is the point.

    func testB1_at1xPointsEqualPixels() {
        assertSize(WindowGeometry.targetPointSize(
            for: resolution(1920, 1080), backingScaleFactor: 1.0), 1920, 1080)
    }

    func testB2_at2xHalvesTheSize() {
        assertSize(WindowGeometry.targetPointSize(
            for: resolution(1920, 1080), backingScaleFactor: 2.0), 960, 540)
    }

    func testB3_at2xMatchesTheClaudeMdWorkedExample() {
        // 3840x2160 pixels == 1920x1080 points on a 2x display.
        assertSize(WindowGeometry.targetPointSize(
            for: resolution(3840, 2160), backingScaleFactor: 2.0), 1920, 1080)
    }

    func testB4_at2xOfEightK() {
        assertSize(WindowGeometry.targetPointSize(
            for: resolution(7680, 4320), backingScaleFactor: 2.0), 3840, 2160)
    }

    func testB5_atFractionalScaleKeepsFractionalPoints() {
        // 1024/1.5 = 682.666..., must not be rounded away.
        assertSize(WindowGeometry.targetPointSize(
            for: resolution(1024, 768), backingScaleFactor: 1.5), 1024.0 / 1.5, 512)
    }

    func testB6_sameResolutionYieldsDifferentPointSizesOnDifferentDisplays() {
        // This is the whole feature: relative to the active display.
        let r = resolution(2560, 1440)
        let at1x = WindowGeometry.targetPointSize(for: r, backingScaleFactor: 1.0)
        let at2x = WindowGeometry.targetPointSize(for: r, backingScaleFactor: 2.0)

        assertSize(at1x, 2560, 1440)
        assertSize(at2x, 1280, 720)
        XCTAssertNotEqual(at1x, at2x)
    }

    // MARK: - C. fits

    func testC1_smallerFits() {
        XCTAssertTrue(WindowGeometry.fits(PointSize(widthInPoints: 1000, heightInPoints: 600), in: primary))
    }

    func testC2_exactlyEqualFits() {
        XCTAssertTrue(WindowGeometry.fits(PointSize(widthInPoints: 2000, heightInPoints: 1075), in: primary))
    }

    func testC3_onePointWiderDoesNotFit() {
        XCTAssertFalse(WindowGeometry.fits(PointSize(widthInPoints: 2001, heightInPoints: 1075), in: primary))
    }

    func testC4_onePointTallerDoesNotFit() {
        XCTAssertFalse(WindowGeometry.fits(PointSize(widthInPoints: 2000, heightInPoints: 1076), in: primary))
    }

    func testC5_ultrawideDoesNotFitStandardDisplay() {
        XCTAssertFalse(WindowGeometry.fits(PointSize(widthInPoints: 3440, heightInPoints: 1440), in: primary))
    }

    // MARK: - D. largestFittingSize

    func testD1_alreadyFittingSizeIsUnchanged() {
        let size = PointSize(widthInPoints: 1000, heightInPoints: 600)
        XCTAssertEqual(WindowGeometry.largestFittingSize(matchingAspectRatioOf: size, in: primary), size)
    }

    func testD2_ultrawideIsWidthBound() {
        let result = WindowGeometry.largestFittingSize(
            matchingAspectRatioOf: PointSize(widthInPoints: 3440, heightInPoints: 1440), in: primary)
        assertSize(result, 2000, 2000.0 * 1440.0 / 3440.0)   // 837.2093...
    }

    func testD3_tallTargetIsHeightBound() {
        let result = WindowGeometry.largestFittingSize(
            matchingAspectRatioOf: PointSize(widthInPoints: 1000, heightInPoints: 2000), in: primary)
        assertSize(result, 537.5, 1075)
    }

    func testD4_tooWideAndTooTallUsesTheBindingDimension() {
        let result = WindowGeometry.largestFittingSize(
            matchingAspectRatioOf: PointSize(widthInPoints: 4000, heightInPoints: 3000), in: primary)
        assertSize(result, 1075.0 * 4.0 / 3.0, 1075)          // 1433.333...
    }

    func testD5_exactlyEqualIsUnchanged() {
        let size = PointSize(widthInPoints: 2000, heightInPoints: 1075)
        XCTAssertEqual(WindowGeometry.largestFittingSize(matchingAspectRatioOf: size, in: primary), size)
    }

    func testD6_fitDownUsesTheResolutionsOwnRatioNotTheGroupHeading() {
        // 2560x1080 is 64:27 (2.3704), not 21:9 (2.3333).
        let result = WindowGeometry.largestFittingSize(
            matchingAspectRatioOf: PointSize(widthInPoints: 2560, heightInPoints: 1080), in: primary)
        assertSize(result, 2000, 843.75)
        XCTAssertEqual(result.widthInPoints / result.heightInPoints, 2560.0 / 1080.0, accuracy: 0.0001)
        XCTAssertNotEqual(result.widthInPoints / result.heightInPoints, 21.0 / 9.0, accuracy: 0.01)
    }

    func testD7_aspectRatioIsPreservedAcrossEveryShrink() {
        let inputs = [
            PointSize(widthInPoints: 3440, heightInPoints: 1440),
            PointSize(widthInPoints: 1000, heightInPoints: 2000),
            PointSize(widthInPoints: 4000, heightInPoints: 3000),
            PointSize(widthInPoints: 2560, heightInPoints: 1080),
            PointSize(widthInPoints: 7680, heightInPoints: 4320),
        ]
        for input in inputs {
            let result = WindowGeometry.largestFittingSize(matchingAspectRatioOf: input, in: primary)
            XCTAssertEqual(result.widthInPoints / result.heightInPoints,
                           input.widthInPoints / input.heightInPoints,
                           accuracy: 0.0001, "ratio drifted for \(input)")
            XCTAssertTrue(WindowGeometry.fits(result, in: primary), "\(input) still does not fit")
        }
    }

    // MARK: - E. Centering and the AppKit -> AX flip

    func testE1_centeredOnPrimary() {
        let origin = WindowGeometry.centeredOriginInAXSpace(
            for: PointSize(widthInPoints: 1000, heightInPoints: 600), in: primary)
        // 25pt menu bar + (1075-600)/2 = 237.5 slack
        XCTAssertEqual(origin.xInPoints, 500, accuracy: 0.0001)
        XCTAssertEqual(origin.yInPoints, 262.5, accuracy: 0.0001)
    }

    func testE2_windowFillingVisibleFrameSitsUnderTheMenuBar() {
        let origin = WindowGeometry.centeredOriginInAXSpace(
            for: PointSize(widthInPoints: 2000, heightInPoints: 1075), in: primary)
        XCTAssertEqual(origin.xInPoints, 0, accuracy: 0.0001)
        XCTAssertEqual(origin.yInPoints, 25, accuracy: 0.0001)
    }

    func testE3_displayAbovePrimaryYieldsNegativeAXY() {
        let origin = WindowGeometry.centeredOriginInAXSpace(
            for: PointSize(widthInPoints: 800, heightInPoints: 500), in: secondary)
        XCTAssertLessThan(origin.yInPoints, 0,
                          "A display above the primary must have a negative AX y")
    }

    func testE4_displayLeftOfPrimaryYieldsNegativeAXX() {
        let origin = WindowGeometry.centeredOriginInAXSpace(
            for: PointSize(widthInPoints: 800, heightInPoints: 500), in: secondary)
        XCTAssertLessThan(origin.xInPoints, 0,
                          "A display left of the primary must have a negative AX x")
    }

    func testE5_centeredOnDisplayAboveAndLeft() {
        let origin = WindowGeometry.centeredOriginInAXSpace(
            for: PointSize(widthInPoints: 800, heightInPoints: 500), in: secondary)
        XCTAssertEqual(origin.xInPoints, -1200, accuracy: 0.0001)
        XCTAssertEqual(origin.yInPoints, -737.5, accuracy: 0.0001)
    }

    func testE6_flipRoundTripsToIdentity() {
        let appKit = AppKitPointOrigin(xInPoints: -1200, yInPoints: 1437.5)
        let height: CGFloat = 500

        let ax = WindowGeometry.axOrigin(
            fromAppKit: appKit, heightInPoints: height, primaryDisplayHeightInPoints: 1200)
        let back = WindowGeometry.appKitOrigin(
            fromAX: ax, heightInPoints: height, primaryDisplayHeightInPoints: 1200)

        XCTAssertEqual(back.xInPoints, appKit.xInPoints, accuracy: 0.0001)
        XCTAssertEqual(back.yInPoints, appKit.yInPoints, accuracy: 0.0001)
    }

    func testE7_flipUsesPrimaryHeightNotTheTargetDisplayHeight() {
        // The secondary display is 1000pt tall while the primary is 1200pt.
        // Flipping about the wrong one gives -937.5 instead of -737.5.
        let origin = WindowGeometry.centeredOriginInAXSpace(
            for: PointSize(widthInPoints: 800, heightInPoints: 500), in: secondary)

        XCTAssertEqual(origin.yInPoints, -737.5, accuracy: 0.0001)
        XCTAssertNotEqual(origin.yInPoints, -937.5, accuracy: 0.0001,
                          "Flip must use the primary display height, not the target display's")
    }

    // MARK: - F. clamped (AX space: x 0...2000, y 25...1100)

    private func frame(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> PointFrame {
        PointFrame(origin: AXPointOrigin(xInPoints: x, yInPoints: y),
                   size: PointSize(widthInPoints: w, heightInPoints: h))
    }

    private func assertFrame(
        _ actual: PointFrame, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(actual.origin.xInPoints, x, accuracy: 0.0001, "x", file: file, line: line)
        XCTAssertEqual(actual.origin.yInPoints, y, accuracy: 0.0001, "y", file: file, line: line)
        XCTAssertEqual(actual.size.widthInPoints, w, accuracy: 0.0001, "w", file: file, line: line)
        XCTAssertEqual(actual.size.heightInPoints, h, accuracy: 0.0001, "h", file: file, line: line)
    }

    func testF1_frameFullyInsideIsUnchanged() {
        let result = WindowGeometry.clamped(frame(500, 262.5, 1000, 600), to: primary)
        assertFrame(result.frame, 500, 262.5, 1000, 600)
        XCTAssertEqual(result.adjustment, .none)
    }

    func testF2_frameOffRightEdgeIsMovedLeft() {
        let result = WindowGeometry.clamped(frame(1500, 100, 1000, 600), to: primary)
        assertFrame(result.frame, 1000, 100, 1000, 600)
        XCTAssertEqual(result.adjustment, .moved)
    }

    func testF3_frameOffBottomIsMovedUp() {
        let result = WindowGeometry.clamped(frame(0, 900, 1000, 600), to: primary)
        assertFrame(result.frame, 0, 500, 1000, 600)
        XCTAssertEqual(result.adjustment, .moved)
    }

    func testF4_frameOffTopLeftIsMovedInside() {
        let result = WindowGeometry.clamped(frame(-100, 0, 500, 300), to: primary)
        assertFrame(result.frame, 0, 25, 500, 300)
        XCTAssertEqual(result.adjustment, .moved)
    }

    func testF5_oversizeFrameAlreadyPositionedIsOnlyResized() {
        let result = WindowGeometry.clamped(frame(0, 25, 3000, 1500), to: primary)
        assertFrame(result.frame, 0, 25, 2000, 1075)
        XCTAssertEqual(result.adjustment, .resized)
    }

    func testF6_oversizeAndMisplacedFrameIsMovedAndResized() {
        let result = WindowGeometry.clamped(frame(500, 500, 3000, 1500), to: primary)
        assertFrame(result.frame, 0, 25, 2000, 1075)
        XCTAssertEqual(result.adjustment, .movedAndResized)
    }

    func testF7_frameExactlyFillingVisibleRegionIsUnchanged() {
        let result = WindowGeometry.clamped(frame(0, 25, 2000, 1075), to: primary)
        assertFrame(result.frame, 0, 25, 2000, 1075)
        XCTAssertEqual(result.adjustment, .none)
    }

    // MARK: - P. sizeThatFits (safety net for a display change mid-menu)

    func testP1_sizeAlreadyFittingIsUnchanged() {
        let size = PointSize(widthInPoints: 1000, heightInPoints: 600)
        XCTAssertEqual(WindowGeometry.sizeThatFits(size, in: primary), size)
    }

    func testP2_oversizedWidthAndHeightAreBothCapped() {
        let result = WindowGeometry.sizeThatFits(
            PointSize(widthInPoints: 5000, heightInPoints: 5000), in: primary)
        assertSize(result, 2000, 1075)
    }

    func testP3_onlyTheOverflowingDimensionIsCapped() {
        // Unlike largestFittingSize, this does NOT preserve aspect ratio: it is a
        // last-resort clamp, and the caller must report that it happened.
        let result = WindowGeometry.sizeThatFits(
            PointSize(widthInPoints: 5000, heightInPoints: 600), in: primary)
        assertSize(result, 2000, 600)
    }

    func testP4_exactlyEqualIsUnchanged() {
        let size = PointSize(widthInPoints: 2000, heightInPoints: 1075)
        XCTAssertEqual(WindowGeometry.sizeThatFits(size, in: primary), size)
    }
}
