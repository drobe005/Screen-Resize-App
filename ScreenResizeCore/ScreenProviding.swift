import AppKit

/// Supplies the displays currently attached, as plain geometry values.
///
/// Behind a protocol for the same reason the Accessibility layer is: the menu's
/// logic must be testable against a synthetic multi-display arrangement on a
/// machine that only has one screen.
public protocol ScreenProviding: AnyObject {
    /// Every attached display. The order is not significant.
    func displays() -> [DisplayGeometry]
}

/// The real provider, reading `NSScreen`.
///
/// Deliberately thin: it converts and nothing else. Choosing *which* display a
/// window belongs to is pure math in `WindowGeometry.displayContaining`.
public final class NSScreenProvider: ScreenProviding {

    public init() {}

    public func displays() -> [DisplayGeometry] {
        // NSScreen.screens[0] is the screen showing the menu bar, which is also
        // the origin of both coordinate spaces. Its height is the flip reference
        // for every display, not just itself.
        guard let primary = NSScreen.screens.first else { return [] }
        let primaryHeightInPoints = primary.frame.height

        return NSScreen.screens.map { screen in
            DisplayGeometry(
                visibleFrameInAppKitPoints: AppKitPointRect(
                    origin: AppKitPointOrigin(
                        xInPoints: screen.visibleFrame.origin.x,
                        yInPoints: screen.visibleFrame.origin.y
                    ),
                    size: PointSize(
                        widthInPoints: screen.visibleFrame.width,
                        heightInPoints: screen.visibleFrame.height
                    )
                ),
                backingScaleFactor: screen.backingScaleFactor,
                primaryDisplayHeightInPoints: primaryHeightInPoints
            )
        }
    }
}
