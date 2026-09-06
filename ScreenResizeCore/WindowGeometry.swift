import CoreGraphics

/// What `clamped` had to do to bring a frame inside a display.
///
/// Oversize is reported rather than silently absorbed: CLAUDE.md constraint 4
/// requires that a resolution larger than the display be handled explicitly and
/// surfaced, never quietly shrunk.
public enum ClampAdjustment: Equatable, Sendable {
    case none
    case moved
    case resized
    case movedAndResized
}

/// Pure geometry. No AppKit, no NSScreen, no AXUIElement, no app state — every
/// input arrives as a parameter, so all of it is testable without a real window.
/// See CLAUDE.md, "All geometry math is pure".
public enum WindowGeometry {

    // MARK: - Pixels to points

    /// Turns a preset into a target size in points.
    ///
    /// This is the one place where a preset's authored pixel numbers become
    /// points, and the scale factor is an explicit parameter rather than
    /// something read from ambient state. See CLAUDE.md, hard constraint 2.
    public static func targetPointSize(
        for resolution: Resolution, mode: SizingMode, backingScaleFactor: CGFloat
    ) -> PointSize {
        switch mode {
        case .logical:
            // A reinterpretation, not a conversion: the authored numbers are
            // taken to be points as-is. The scale factor is deliberately unused.
            return PointSize(
                widthInPoints: resolution.pixelSize.widthInPixels,
                heightInPoints: resolution.pixelSize.heightInPixels
            )

        case .capture:
            precondition(
                backingScaleFactor > 0,
                "backingScaleFactor must be positive, got \(backingScaleFactor)"
            )
            // Points chosen so that a capture of the window is exactly the
            // preset's pixel dimensions.
            return PointSize(
                widthInPoints: resolution.pixelSize.widthInPixels / backingScaleFactor,
                heightInPoints: resolution.pixelSize.heightInPixels / backingScaleFactor
            )
        }
    }

    // MARK: - Fitting

    /// Whether `size` fits inside the display's visible frame. Boundary-inclusive:
    /// a size exactly equal to the visible frame fits.
    ///
    /// Compared exactly, not with `windowGeometryTolerance` — a size one point
    /// too large genuinely does not fit, and a tolerant compare here would let
    /// it through.
    public static func fits(_ size: PointSize, in display: DisplayGeometry) -> Bool {
        let visible = display.visibleFrameInAppKitPoints.size
        return size.widthInPoints <= visible.widthInPoints
            && size.heightInPoints <= visible.heightInPoints
    }

    /// The largest size with the same aspect ratio as `size` that fits inside the
    /// display's visible frame. Returns `size` unchanged when it already fits.
    ///
    /// The ratio comes from `size` itself, never from a group heading — under
    /// "21:9" the real ratios are 64:27 and 43:18.
    public static func largestFittingSize(
        matchingAspectRatioOf size: PointSize, in display: DisplayGeometry
    ) -> PointSize {
        guard size.widthInPoints > 0, size.heightInPoints > 0 else { return size }
        if fits(size, in: display) { return size }

        let visible = display.visibleFrameInAppKitPoints.size
        let widthScale = visible.widthInPoints / size.widthInPoints
        let heightScale = visible.heightInPoints / size.heightInPoints

        // Pin the binding dimension to the bound exactly rather than multiplying
        // it back out, so floating-point drift can never leave the result a
        // hair too large to fit.
        if widthScale <= heightScale {
            return PointSize(
                widthInPoints: visible.widthInPoints,
                heightInPoints: size.heightInPoints * widthScale
            )
        } else {
            return PointSize(
                widthInPoints: size.widthInPoints * heightScale,
                heightInPoints: visible.heightInPoints
            )
        }
    }

    // MARK: - Coordinate space conversion

    /// Converts an AppKit origin (bottom-left, y up) to an Accessibility origin
    /// (top-left, y down).
    ///
    /// The flip is about the PRIMARY display's height, whatever display the
    /// window is on. `heightInPoints` is the window's height, needed because the
    /// two spaces anchor opposite edges of the window.
    ///
    /// A window on a display above or left of the primary correctly yields
    /// negative coordinates.
    public static func axOrigin(
        fromAppKit origin: AppKitPointOrigin,
        heightInPoints: CGFloat,
        primaryDisplayHeightInPoints: CGFloat
    ) -> AXPointOrigin {
        AXPointOrigin(
            xInPoints: origin.xInPoints,
            yInPoints: primaryDisplayHeightInPoints - (origin.yInPoints + heightInPoints)
        )
    }

    /// Converts an Accessibility origin back to AppKit's space. The flip is its
    /// own inverse, so this round-trips exactly.
    public static func appKitOrigin(
        fromAX origin: AXPointOrigin,
        heightInPoints: CGFloat,
        primaryDisplayHeightInPoints: CGFloat
    ) -> AppKitPointOrigin {
        AppKitPointOrigin(
            xInPoints: origin.xInPoints,
            yInPoints: primaryDisplayHeightInPoints - (origin.yInPoints + heightInPoints)
        )
    }

    // MARK: - Centering

    /// The origin that centres a window of `size` in the display's visible frame,
    /// returned ready for the Accessibility API.
    ///
    /// Centring is computed in AppKit's space, where `visibleFrame` lives, then
    /// flipped once. Callers get an AX-ready origin and cannot forget the flip.
    public static func centeredOriginInAXSpace(
        for size: PointSize, in display: DisplayGeometry
    ) -> AXPointOrigin {
        let visible = display.visibleFrameInAppKitPoints
        let centered = AppKitPointOrigin(
            xInPoints: visible.origin.xInPoints
                + (visible.size.widthInPoints - size.widthInPoints) / 2,
            yInPoints: visible.origin.yInPoints
                + (visible.size.heightInPoints - size.heightInPoints) / 2
        )
        return axOrigin(
            fromAppKit: centered,
            heightInPoints: size.heightInPoints,
            primaryDisplayHeightInPoints: display.primaryDisplayHeightInPoints
        )
    }

    // MARK: - Clamping

    /// Brings `frame` inside the display's visible area, and reports what it had
    /// to do. Operates in Accessibility space, since that is what gets written.
    ///
    /// Moves first. Only shrinks when the frame is larger than the visible area,
    /// which no amount of moving can fix. The returned `ClampAdjustment` makes
    /// that shrink visible to the caller instead of silent.
    public static func clamped(
        _ frame: PointFrame, to display: DisplayGeometry
    ) -> (frame: PointFrame, adjustment: ClampAdjustment) {
        let visible = visibleRectInAXSpace(of: display)

        let minX = visible.origin.xInPoints
        let maxX = visible.origin.xInPoints + visible.size.widthInPoints
        let minY = visible.origin.yInPoints
        let maxY = visible.origin.yInPoints + visible.size.heightInPoints

        let availableWidth = maxX - minX
        let availableHeight = maxY - minY

        var size = frame.size
        var didResize = false
        if size.widthInPoints > availableWidth {
            size.widthInPoints = availableWidth
            didResize = true
        }
        if size.heightInPoints > availableHeight {
            size.heightInPoints = availableHeight
            didResize = true
        }

        var x = frame.origin.xInPoints
        if x + size.widthInPoints > maxX { x = maxX - size.widthInPoints }
        if x < minX { x = minX }

        var y = frame.origin.yInPoints
        if y + size.heightInPoints > maxY { y = maxY - size.heightInPoints }
        if y < minY { y = minY }

        let didMove = x != frame.origin.xInPoints || y != frame.origin.yInPoints

        let adjustment: ClampAdjustment
        switch (didMove, didResize) {
        case (false, false): adjustment = .none
        case (true, false):  adjustment = .moved
        case (false, true):  adjustment = .resized
        case (true, true):   adjustment = .movedAndResized
        }

        return (
            PointFrame(origin: AXPointOrigin(xInPoints: x, yInPoints: y), size: size),
            adjustment
        )
    }

    // MARK: - Display selection

    /// The display's visible area expressed in Accessibility space.
    ///
    /// The AppKit rect's TOP edge becomes the AX rect's origin, because the two
    /// spaces anchor opposite edges. Extracted so display selection and clamping
    /// share one definition of "where this display actually is".
    public static func visibleRectInAXSpace(of display: DisplayGeometry) -> PointFrame {
        let visible = display.visibleFrameInAppKitPoints
        let topLeft = axOrigin(
            fromAppKit: visible.origin,
            heightInPoints: visible.size.heightInPoints,
            primaryDisplayHeightInPoints: display.primaryDisplayHeightInPoints
        )
        return PointFrame(origin: topLeft, size: visible.size)
    }

    /// The display a window most occupies, by overlapping area.
    ///
    /// Area rather than the window's centre: a window dragged across a boundary
    /// should follow whichever display holds most of it, and a centre-point test
    /// flips abruptly at the halfway line.
    ///
    /// Returns nil when the frame overlaps no display at all, which the caller
    /// must handle rather than guessing a default.
    public static func displayContaining(
        _ frame: PointFrame, among displays: [DisplayGeometry]
    ) -> DisplayGeometry? {
        var best: (display: DisplayGeometry, area: CGFloat)?
        for display in displays {
            let area = overlapArea(frame, visibleRectInAXSpace(of: display))
            guard area > 0 else { continue }
            if area > (best?.area ?? 0) { best = (display, area) }
        }
        return best?.display
    }

    /// Area shared by two AX-space rectangles. Zero when they do not overlap.
    private static func overlapArea(_ a: PointFrame, _ b: PointFrame) -> CGFloat {
        let overlapWidth = min(a.origin.xInPoints + a.size.widthInPoints,
                               b.origin.xInPoints + b.size.widthInPoints)
            - max(a.origin.xInPoints, b.origin.xInPoints)
        let overlapHeight = min(a.origin.yInPoints + a.size.heightInPoints,
                                b.origin.yInPoints + b.size.heightInPoints)
            - max(a.origin.yInPoints, b.origin.yInPoints)
        guard overlapWidth > 0, overlapHeight > 0 else { return 0 }
        return overlapWidth * overlapHeight
    }
}
