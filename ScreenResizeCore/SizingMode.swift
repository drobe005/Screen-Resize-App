import CoreGraphics

/// How a preset's authored numbers should be interpreted.
public enum SizingMode: String, CaseIterable, Sendable {

    /// The preset's numbers are treated as points and applied directly. The
    /// display's backing scale factor is deliberately ignored: a 1920x1080
    /// preset produces a 1920x1080 point window on a 1x and a 2x display alike.
    case logical

    /// The preset's numbers are treated as physical pixels and divided by the
    /// backing scale factor. A screen recording of the resulting window is then
    /// exactly the preset's pixel dimensions — 3840x2160 on a 2x display becomes
    /// a 1920x1080 point window that captures at 3840x2160 pixels.
    case capture
}
