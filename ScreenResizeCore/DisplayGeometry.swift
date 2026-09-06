import CoreGraphics

/// The numbers the geometry layer needs about a display.
///
/// A plain value type on purpose: CLAUDE.md requires the geometry math be pure
/// and free of `NSScreen`, so a caller reads these off a screen once and passes
/// them in. Nothing here reaches for ambient state.
public struct DisplayGeometry: Equatable, Sendable {

    /// The display's usable area, excluding menu bar and Dock, in AppKit's
    /// bottom-left space — exactly what `NSScreen.visibleFrame` returns.
    public let visibleFrameInAppKitPoints: AppKitPointRect

    /// Points-to-pixels ratio for this display. 2.0 on a Retina panel.
    public let backingScaleFactor: CGFloat

    /// The height of the PRIMARY display, in points.
    ///
    /// The AppKit-to-Accessibility flip is always about the primary display's
    /// height, never this display's own. They differ whenever a secondary
    /// display is a different size, and using the wrong one puts windows on the
    /// wrong part of the screen while looking perfectly correct on a
    /// single-monitor setup.
    public let primaryDisplayHeightInPoints: CGFloat

    public init(
        visibleFrameInAppKitPoints: AppKitPointRect,
        backingScaleFactor: CGFloat,
        primaryDisplayHeightInPoints: CGFloat
    ) {
        self.visibleFrameInAppKitPoints = visibleFrameInAppKitPoints
        self.backingScaleFactor = backingScaleFactor
        self.primaryDisplayHeightInPoints = primaryDisplayHeightInPoints
    }
}
