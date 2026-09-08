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
        for resolution: Resolution, backingScaleFactor: CGFloat
    ) -> PointSize {
        precondition(
            backingScaleFactor > 0,
            "backingScaleFactor must be positive, got \(backingScaleFactor)"
        )
        // The only interpretation: a preset's numbers are physical pixels, and
        // dividing by the display's own scale factor is what makes the result
        // relative to whichever display it is applied on. A screen recording of
        // the resulting window is then exactly the preset's pixel dimensions —
        // 3840x2160 on a 2x display becomes a 1920x1080 point window that
        // captures at 3840x2160 pixels; the same preset on a 1x display stays
        // 3840x2160 points. See CLAUDE.md, hard constraint 2.
        return PointSize(
            widthInPoints: resolution.pixelSize.widthInPixels / backingScaleFactor,
            heightInPoints: resolution.pixelSize.heightInPixels / backingScaleFactor
        )
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

    /// `size` reduced so it cannot exceed the display's visible area, without
    /// preserving aspect ratio.
    ///
    /// A safety net, not the primary fit path: options that do not fit are
    /// disabled in the menu, so this only bites when the window moved to a
    /// different display between the menu opening and the click. Callers must
    /// compare the result against their input and tell the user if it shrank —
    /// CLAUDE.md constraint 4 forbids absorbing that silently.
    public static func sizeThatFits(_ size: PointSize, in display: DisplayGeometry) -> PointSize {
        let visible = display.visibleFrameInAppKitPoints.size
        return PointSize(
            widthInPoints: min(size.widthInPoints, visible.widthInPoints),
            heightInPoints: min(size.heightInPoints, visible.heightInPoints)
        )
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

    // MARK: - Aspect ratio

    /// The aspect ratio of a size, reduced to its lowest terms.
    ///
    /// Returns nil for a non-positive size rather than dividing by zero.
    ///
    /// This computes the *real* ratio, which is frequently not the one a display
    /// is marketed as: 2560x1080 reduces to 64:27, not 21:9. See the note on
    /// `AspectRatioGroup.heading`.
    public static func aspectRatio(of size: PixelSize) -> (widthTerm: Int, heightTerm: Int)? {
        let width = Int(size.widthInPixels.rounded())
        let height = Int(size.heightInPixels.rounded())
        guard width > 0, height > 0 else { return nil }

        let divisor = greatestCommonDivisor(width, height)
        return (width / divisor, height / divisor)
    }

    /// Formatted for display, e.g. "64:27". Nil for a non-positive size.
    public static func aspectRatioDescription(of size: PixelSize) -> String? {
        guard let ratio = aspectRatio(of: size) else { return nil }
        return "\(ratio.widthTerm):\(ratio.heightTerm)"
    }

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var a = abs(a), b = abs(b)
        while b != 0 { (a, b) = (b, a % b) }
        return a == 0 ? 1 : a
    }
}
