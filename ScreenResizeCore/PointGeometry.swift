import CoreGraphics

// Every dimension in this file is in POINTS, never pixels. The Accessibility API
// works in points, and on a 2x Retina display 3840x2160 pixels is 1920x1080
// points. The field names carry the unit so the two can never be silently
// swapped at a call site. See CLAUDE.md, hard constraint 2.
//
// There is deliberately no pixel type and no scale factor here. Pixel-authored
// presets and the single point/pixel conversion function arrive in a later phase.

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
public struct PointOrigin: Equatable, Sendable {
    public var xInPoints: CGFloat
    public var yInPoints: CGFloat

    public init(xInPoints: CGFloat, yInPoints: CGFloat) {
        self.xInPoints = xInPoints
        self.yInPoints = yInPoints
    }
}

/// A window frame expressed in points.
public struct PointFrame: Equatable, Sendable {
    public var origin: PointOrigin
    public var size: PointSize

    public init(origin: PointOrigin, size: PointSize) {
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

extension PointOrigin {
    /// True when both coordinates are within `tolerance` points of `other`.
    public func isApproximately(_ other: PointOrigin, tolerance: CGFloat = windowGeometryTolerance) -> Bool {
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
