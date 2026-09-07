import CoreGraphics

/// A single resolution preset, authored in physical pixels.
///
/// These numbers are physical pixels, converted to points at the moment of
/// application — see `WindowGeometry.targetPointSize(for:backingScaleFactor:)`.
public struct Resolution: Equatable, Identifiable, Sendable {
    /// Stable identity and display name, e.g. "1920x1080".
    public let name: String
    /// The authored size, in physical pixels.
    public let pixelSize: PixelSize
    /// An optional friendly label, e.g. "1080p / Full HD".
    public let label: String?

    public var id: String { name }

    public init(name: String, pixelSize: PixelSize, label: String? = nil) {
        self.name = name
        self.pixelSize = pixelSize
        self.label = label
    }
}

/// Resolutions gathered under a heading.
///
/// `heading` is a human-facing label such as "21:9". It is **not** a reliable
/// aspect ratio and must never be parsed as one: under "21:9", 2560x1080 is
/// really 64:27 and 3440x1440 is 43:18. Aspect-ratio math always uses a
/// `Resolution`'s own pixel dimensions.
public struct AspectRatioGroup: Equatable, Identifiable, Sendable {
    public let heading: String
    public let resolutions: [Resolution]

    public var id: String { heading }

    public init(heading: String, resolutions: [Resolution]) {
        self.heading = heading
        self.resolutions = resolutions
    }
}
