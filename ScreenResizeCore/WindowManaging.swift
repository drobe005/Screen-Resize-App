import Foundation

/// An opaque reference to a window, minted by a `WindowManaging` implementation.
///
/// Deliberately empty: it keeps `AXUIElement` out of the protocol so the whole
/// surface can be mocked without an associated type. Each implementation
/// recognises only its own handles and throws `.unsupportedHandle` otherwise.
public protocol WindowHandle: AnyObject {}

/// An opaque reference to a running application.
public protocol ApplicationHandle: AnyObject {
    var processIdentifier: pid_t { get }
    var localizedName: String? { get }
}

/// The result of a resize that was at least partly accepted.
///
/// The third state from CLAUDE.md constraint 3 — rejected — is not here: it
/// arrives as a thrown `WindowManagerError.resizeRejected`, so a caller cannot
/// ignore it by discarding the return value.
public enum ResizeOutcome: Equatable {

    /// The window ended up at the requested size, within tolerance.
    case exact

    /// The window resized, but not to what was asked. Carries both sizes so the
    /// UI can tell the user what actually happened.
    case partial(requested: PointSize, actual: PointSize)
}

/// The window control surface. All Accessibility access in the app goes through
/// this protocol, so tests can run against a mock with no real windows and no
/// Accessibility permission. See CLAUDE.md, "The Accessibility layer sits behind
/// a protocol".
public protocol WindowManaging: AnyObject {

    /// Whether this process is currently trusted for Accessibility. Does not prompt.
    func isProcessTrusted() -> Bool

    /// Whether this process is trusted, prompting the user if it is not.
    /// Shows the system permission dialog as a side effect.
    @discardableResult
    func promptForAccessibilityPermission() -> Bool

    /// The application currently in the foreground.
    /// - Throws: `.permissionDenied`, `.noFrontmostApp`.
    func frontmostApplication() throws -> ApplicationHandle

    /// The focused window of `application`.
    /// - Throws: `.permissionDenied`, `.noFocusedWindow`, `.attributeUnavailable`,
    ///   `.unsupportedHandle`.
    func focusedWindow(of application: ApplicationHandle) throws -> WindowHandle

    /// The current frame of `window`, in points.
    /// - Throws: `.permissionDenied`, `.attributeUnavailable`, `.unsupportedHandle`.
    func frame(of window: WindowHandle) throws -> PointFrame

    /// Writes `frame` to `window`, then reads the frame back to find out what
    /// actually happened. The write's own return value is never treated as
    /// proof of success.
    ///
    /// - Returns: `.exact` or `.partial`.
    /// - Throws: `.resizeRejected` when the window did not move at all, plus
    ///   `.permissionDenied`, `.attributeUnavailable`, `.unsupportedHandle`.
    @discardableResult
    func applyFrame(_ frame: PointFrame, to window: WindowHandle) throws -> ResizeOutcome
}
