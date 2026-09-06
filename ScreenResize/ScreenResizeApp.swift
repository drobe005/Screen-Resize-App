import AppKit
import SwiftUI
import ScreenResizeCore

/// Identifier for the onboarding window scene.
let onboardingWindowID = "onboarding"

/// ScreenResize lives in the menu bar. `LSUIElement` is true, so there is no Dock
/// icon and no main window in normal use.
///
/// The onboarding window is the one exception, and it exists because a first-time
/// user has no way to know the app needs Accessibility permission — or even that
/// the app launched at all. It is shown only while untrusted.
@main
struct ScreenResizeApp: App {

    @StateObject private var model = MenuBarModel(
        windowManager: AXWindowManager(),
        screens: NSScreenProvider(),
        frontmostTracker: WorkspaceFrontmostTracker()
    )

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
        } label: {
            // The label renders as soon as the status item exists, i.e. at
            // launch. MenuBarContentView does not exist until the menu is first
            // opened, so this is the only place that can present onboarding on
            // first run.
            MenuBarLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to ScreenResize", id: onboardingWindowID) {
            OnboardingView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// The menu bar icon, which doubles as the onboarding presenter.
private struct MenuBarLabel: View {

    @EnvironmentObject private var model: MenuBarModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Image(systemName: "rectangle.inset.filled")
            .onAppear {
                if !model.isTrusted { openWindow(id: onboardingWindowID) }
            }
            .onChange(of: model.isTrusted) { _, isTrusted in
                // Granting permission dismisses onboarding on the spot; losing it
                // brings onboarding back. Neither needs a relaunch.
                if isTrusted {
                    dismissWindow(id: onboardingWindowID)
                } else {
                    openWindow(id: onboardingWindowID)
                }
            }
    }
}
