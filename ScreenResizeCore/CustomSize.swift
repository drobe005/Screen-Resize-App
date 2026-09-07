import CoreGraphics
import Foundation

/// A user-defined size, authored in pixels like every other preset.
///
/// Deliberately convertible to an ordinary `Resolution`: once it reaches the
/// menu, nothing downstream — fit checking, disabled labels, favorites, the
/// apply pipeline — can tell a custom size from a built-in one.
public struct CustomSize: Codable, Equatable, Identifiable, Sendable {

    public let widthInPixels: Int
    public let heightInPixels: Int

    public var id: String { "\(widthInPixels)x\(heightInPixels)" }

    public init(widthInPixels: Int, heightInPixels: Int) {
        self.widthInPixels = widthInPixels
        self.heightInPixels = heightInPixels
    }

    public var pixelSize: PixelSize {
        PixelSize(widthInPixels: CGFloat(widthInPixels), heightInPixels: CGFloat(heightInPixels))
    }

    /// The catalog entry this size becomes. Labelled with its real reduced
    /// aspect ratio, which is genuinely useful information for a size the user
    /// typed by hand.
    public var resolution: Resolution {
        Resolution(
            name: id,
            pixelSize: pixelSize,
            label: WindowGeometry.aspectRatioDescription(of: pixelSize)
        )
    }
}

/// Why a custom size was refused. Validation is explicit and surfaced, never a
/// silent clamp — see CLAUDE.md, hard constraint 4.
public enum CustomSizeError: Error, Equatable {
    case notPositive
    case tooLarge(maximumInPixels: Int)
    case duplicate(name: String)
}

extension CustomSizeError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notPositive:
            return "Width and height must both be greater than zero."
        case .tooLarge(let maximum):
            return "Width and height must each be \(maximum) pixels or less."
        case .duplicate(let name):
            return "\(name) is already in your custom sizes."
        }
    }
}

public enum CustomSizeLimits {
    /// A sanity guard, not a hardware limit. Comfortably above 8K (7680) so no
    /// realistic capture target is refused, while still rejecting a typo that
    /// adds three zeroes.
    public static let maximumInPixels = 30_000
}
