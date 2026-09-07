import AppKit

/// Keeps `NSApp`'s activation policy correct while windows come and go.
///
/// An `LSUIElement` app has no Dock icon, so its windows can open behind
/// everything else where a user will never find them. Becoming `.regular` while
/// a window is up fixes that, but the switch cannot be a simple pair of
/// onAppear/onDisappear calls: with onboarding and Settings both open, closing
/// either one would drop the app back to `.accessory` and bury the other.
///
/// So presentations are counted, and `.accessory` is restored only when the last
/// window goes away.
@MainActor
final class ActivationPolicyCoordinator {

    static let shared = ActivationPolicyCoordinator()

    private var presentedWindowCount = 0

    private init() {}

    /// Call when a window that needs focus appears.
    func windowDidAppear() {
        presentedWindowCount += 1
        if presentedWindowCount == 1 {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Call when such a window goes away.
    func windowDidDisappear() {
        presentedWindowCount = max(0, presentedWindowCount - 1)
        if presentedWindowCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
