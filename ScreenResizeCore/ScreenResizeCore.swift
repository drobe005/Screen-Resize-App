import Foundation

/// Namespace for the ScreenResize core library.
///
/// This framework holds the parts of the app that must be testable without a
/// running app or a real window: pure geometry math, the resolution preset
/// model, and the protocol the Accessibility layer sits behind.
///
/// It is deliberately near-empty at the scaffold stage. See CLAUDE.md for the
/// rules that govern what may be added here.
public enum ScreenResizeCore {

    /// The version of the core library, mirroring the app's marketing version.
    public static let version = "0.1.0"
}
