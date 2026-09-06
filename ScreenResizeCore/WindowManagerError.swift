import Foundation

/// Everything that can go wrong while inspecting or resizing a window.
///
/// `axErrorCode` is a raw `Int32` rather than an `AXError` so that this type,
/// the `WindowManaging` protocol, and any mock stay free of an
/// ApplicationServices dependency.
public enum WindowManagerError: Error, Equatable {

    /// The process is not trusted for Accessibility, or the API reported
    /// `kAXErrorAPIDisabled`. The user must grant permission in
    /// System Settings > Privacy & Security > Accessibility.
    case permissionDenied

    /// No application is currently frontmost.
    case noFrontmostApp

    /// The frontmost application has no focused window. Common when only a
    /// panel is open, or when the app is in a full-screen space.
    case noFocusedWindow

    /// An attribute could not be read or written for a reason that is not one
    /// of the cases above. Carries the attribute name and the raw `AXError`.
    case attributeUnavailable(attribute: String, axErrorCode: Int32)

    /// The window did not move at all. Fixed-size windows, some Electron apps,
    /// and windows in full-screen spaces behave this way. Carries what was
    /// asked for and what the window actually is, per CLAUDE.md constraint 3.
    case resizeRejected(requested: PointSize, actual: PointSize)

    /// A handle minted by one `WindowManaging` implementation was passed to
    /// another. A programmer error, surfaced as a typed throw rather than a crash.
    case unsupportedHandle
}

extension WindowManagerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .permissionDenied:
            return "ScreenResize is not trusted for Accessibility."
        case .noFrontmostApp:
            return "No application is frontmost."
        case .noFocusedWindow:
            return "The frontmost application has no focused window."
        case .attributeUnavailable(let attribute, let code):
            return "Accessibility attribute \(attribute) unavailable (AXError \(code))."
        case .resizeRejected(let requested, let actual):
            return "Window refused to resize. Requested "
                + "\(Int(requested.widthInPoints))x\(Int(requested.heightInPoints)) pt, "
                + "still \(Int(actual.widthInPoints))x\(Int(actual.heightInPoints)) pt."
        case .unsupportedHandle:
            return "Window handle came from a different WindowManaging implementation."
        }
    }
}
