import AppKit
import SwiftUI
import ScreenResizeCore

/// First-run explanation and the two routes to granting permission.
///
/// Shown only while the app is untrusted, and dismissed automatically the moment
/// permission is granted.
struct OnboardingView: View {

    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to ScreenResize")
                    .font(.title2.weight(.semibold))
                Text("Resize any app's window to a preset size from your menu bar.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Why macOS is about to ask for permission")
                    .font(.headline)

                Text("""
                     To change another app's window, macOS requires you to grant \
                     ScreenResize Accessibility access. It is the only way any app \
                     can move or resize windows that do not belong to it.
                     """)
                    .fixedSize(horizontal: false, vertical: true)

                Label("ScreenResize reads a window's position and size, and sets a new one.",
                      systemImage: "rectangle.inset.filled")
                Label("It sends nothing anywhere. There is no network access, no analytics, "
                      + "and nothing leaves your Mac.",
                      systemImage: "wifi.slash")
                Label("It cannot read what is inside your windows — only their size and position.",
                      systemImage: "eye.slash")
            }
            .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button("Grant Access…") { model.requestPermission() }
                        .keyboardShortcut(.defaultAction)
                    Button("Open System Settings…") { model.openAccessibilitySettings() }
                }
                // The system prompt appears at most once per app. If it has
                // already been dismissed, the second button is the only route
                // left, so both are always offered.
                Text("If no prompt appears, use Open System Settings, then turn on "
                     + "ScreenResize under Privacy & Security → Accessibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("This window closes by itself once access is granted.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 460, alignment: .leading)
        .onAppear {
            // Without a Dock icon an LSUIElement app's window can open behind
            // everything else, which a first-time user would never find. Become
            // a regular app for the duration of onboarding so the window is
            // focused and reachable.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            // Back to menu-bar-only for normal operation.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
