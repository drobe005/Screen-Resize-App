import Foundation

/// Fixed sizes used only by debug affordances.
///
/// These live here, not in a view. CLAUDE.md forbids hardcoding a resolution in
/// UI code, and that rule does not get an exception because the caller happens
/// to be a debug menu item. Superseded by the resolution preset model.
public enum DebugTargets {

    /// Phase 2 verification target: 1280x720 points.
    public static let verificationSize = PointSize(widthInPoints: 1280, heightInPoints: 720)
}
