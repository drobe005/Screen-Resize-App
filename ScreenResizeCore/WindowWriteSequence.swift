import Foundation

/// One attribute write in a frame application.
public enum WindowWriteStep: Equatable, Sendable {
    case size
    case origin
}

/// The order in which a frame's parts are written to a window.
///
/// This is data, not a comment, so the ordering below is covered by a unit test
/// rather than resting on a reviewer noticing a prose explanation.
public enum WindowWriteSequence {

    /// Size, then origin, then size again.
    ///
    /// The Accessibility API has no atomic frame set: position and size are two
    /// independent writes, and either can be clamped by the app or the window
    /// server.
    ///
    /// 1. **Size first.** May be clamped by the space available from the window's
    ///    *current* origin — a window near a screen edge cannot grow into it.
    /// 2. **Then origin.** A window that is now smaller is less likely to have its
    ///    move constrained.
    /// 3. **Size again.** Re-applies the request now that the window sits at the
    ///    target origin, recovering from any clamping in step 1.
    ///
    /// This ordering is empirical; Apple does not document the clamping behaviour.
    /// That is exactly why callers must read the frame back afterwards rather than
    /// trusting these writes. See CLAUDE.md, hard constraint 3.
    public static let standard: [WindowWriteStep] = [.size, .origin, .size]
}
