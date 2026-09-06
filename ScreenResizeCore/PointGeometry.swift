import CoreGraphics

// Every dimension in this file is in POINTS, never pixels. The Accessibility API
// works in points, and on a 2x Retina display 3840x2160 pixels is 1920x1080
// points. The field names carry the unit so the two can never be silently
// swapped at a call site. See CLAUDE.md, hard constraint 2.
//
// TWO COORDINATE SPACES live here, and mixing them is a compile error by design:
//
//   AXPointOrigin     - the Accessibility API's space. Top-left origin, y
//                       increasing DOWNWARD, 0,0 at the top-left of the screen
//                       showing the menu bar. This is what kAXPositionAttribute
//                       documents and what window writes must use.
//   AppKitPointOrigin - NSScreen's space. Bottom-left origin, y increasing
//                       UPWARD. This is what visibleFrame reports.
//
// They differ by a vertical flip about the PRIMARY display's height. On a
// single display whose origin is 0,0 the two coincide, which is exactly why
// getting this wrong stays invisible until a second monitor appears.
//
// PointSize is deliberately shared: a size is the same number in either space.
// Only origins differ.

/// A window size expressed in points.
public struct PointSize: Equatable, Sendable {
    public var widthInPoints: CGFloat
    public var heightInPoints: CGFloat

    public init(widthInPoints: CGFloat, heightInPoints: CGFloat) {
        self.widthInPoints = widthInPoints
        self.heightInPoints = heightInPoints
    }
}

/// A window origin expressed in points, in the Accessibility API's coordinate
/// space: top-left origin, y increasing downward.
public struct AXPointOrigin: Equatable, Sendable {
    public var xInPoints: CGFloat
    public var yInPoints: CGFloat

    public init(xInPoints: CGFloat, yInPoints: CGFloat) {
        self.xInPoints = xInPoints
        self.yInPoints = yInPoints
    }
}

/// A window frame expressed in points.
public struct PointFrame: Equatable, Sendable {
    public var origin: AXPointOrigin
    public var size: PointSize

    public init(origin: AXPointOrigin, size: PointSize) {
        self.origin = origin
        self.size = size
    }
}

// MARK: - Tolerant comparison

/// Points within which two coordinates are considered the same.
///
/// Windows legitimately land on fractional points, and some apps round to their
/// own increments. Comparing with `==` would report a window that did exactly
/// what we asked as a partial resize.
public let windowGeometryTolerance: CGFloat = 1.0

extension PointSize {
    /// True when both dimensions are within `tolerance` points of `other`.
    public func isApproximately(_ other: PointSize, tolerance: CGFloat = windowGeometryTolerance) -> Bool {
        abs(widthInPoints - other.widthInPoints) <= tolerance
            && abs(heightInPoints - other.heightInPoints) <= tolerance
    }
}

extension AXPointOrigin {
    /// True when both coordinates are within `tolerance` points of `other`.
    public func isApproximately(_ other: AXPointOrigin, tolerance: CGFloat = windowGeometryTolerance) -> Bool {
        abs(xInPoints - other.xInPoints) <= tolerance
            && abs(yInPoints - other.yInPoints) <= tolerance
    }
}

extension PointFrame {
    /// True when origin and size are both within `tolerance` points of `other`.
    public func isApproximately(_ other: PointFrame, tolerance: CGFloat = windowGeometryTolerance) -> Bool {
        origin.isApproximately(other.origin, tolerance: tolerance)
            && size.isApproximately(other.size, tolerance: tolerance)
    }
}


// MARK: - Pixels

/// A size in physical pixels.
///
/// Resolution presets are authored in pixels because that is how users think
/// about resolutions. Converting to points is the job of `WindowGeometry`, and
/// happens in exactly one place. See CLAUDE.md, hard constraint 2.
public struct PixelSize: Equatable, Sendable {
    public var widthInPixels: CGFloat
    public var heightInPixels: CGFloat

    public init(widthInPixels: CGFloat, heightInPixels: CGFloat) {
        self.widthInPixels = widthInPixels
        self.heightInPixels = heightInPixels
    }
}

// MARK: - AppKit coordinate space

/// An origin in AppKit's screen space: bottom-left origin, y increasing upward.
/// This is the space `NSScreen.frame` and `NSScreen.visibleFrame` report in.
///
/// Never hand one of these to the Accessibility API. Convert it first with
/// `WindowGeometry.axOrigin(fromAppKit:heightInPoints:primaryDisplayHeightInPoints:)`.
public struct AppKitPointOrigin: Equatable, Sendable {
    public var xInPoints: CGFloat
    public var yInPoints: CGFloat

    public init(xInPoints: CGFloat, yInPoints: CGFloat) {
        self.xInPoints = xInPoints
        self.yInPoints = yInPoints
    }
}

/// A rectangle in AppKit's screen space, such as a display's visible frame.
public struct AppKitPointRect: Equatable, Sendable {
    public var origin: AppKitPointOrigin
    public var size: PointSize

    public init(origin: AppKitPointOrigin, size: PointSize) {
        self.origin = origin
        self.size = size
    }

    /// The largest x inside the rectangle.
    public var maxXInPoints: CGFloat { origin.xInPoints + size.widthInPoints }
    /// The largest y inside the rectangle (its TOP edge, since y increases upward).
    public var maxYInPoints: CGFloat { origin.yInPoints + size.heightInPoints }
}
