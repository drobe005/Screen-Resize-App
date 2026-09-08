import CoreGraphics

/// A single resolution preset, authored in physical pixels.
///
/// These numbers are physical pixels, converted to points at the moment of
/// application — see `WindowGeometry.targetPointSize(for:backingScaleFactor:)`.
public struct Resolution: Equatable, Identifiable, Sendable {
    /// Stable identity and display name, e.g. "1920x1080".
    public let name: String
    /// The authored size, in physical pixels.
    public let pointSize: PointSize
    /// An optional friendly label, e.g. "1080p / Full HD".
    public let label: String?

    public var id: String { name }

    public init(name: String, pointSize: PointSize, label: String? = nil) {
        self.name = name
        self.pointSize = pointSize
        self.label = label
    }
}
