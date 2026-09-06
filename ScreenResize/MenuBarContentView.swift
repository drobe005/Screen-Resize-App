import SwiftUI
import ScreenResizeCore

/// Placeholder menu bar content.
///
/// Resolution presets are not here yet, and when they arrive they must be read
/// from the shared preset model rather than hardcoded in this view. See the
/// "Resolution presets live in a single data model" rule in CLAUDE.md — which is
/// also why the debug item below takes its size from `DebugTargets` instead of
/// spelling out 1280x720 here.
struct MenuBarContentView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ScreenResize")
                .font(.headline)

            Text("Core \(ScreenResizeCore.version)")
                .font(.caption)
                .foregroundStyle(.secondary)

            #if DEBUG
            Divider()
            DebugResizeSection()
            #endif

            Divider()

            // Load-bearing, not decoration: an LSUIElement app with no Quit
            // control can only be killed from the command line.
            Button("Quit ScreenResize") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }
}

#if DEBUG
/// Temporary Phase 2 verification affordance. Not product UI, and absent from
/// Release builds. Superseded by the preset menu.
private struct DebugResizeSection: View {

    @StateObject private var tracker = FrontmostAppTracker()
    @State private var status: String = "No resize attempted yet."

    private let windowManager = AXWindowManager()

    private var targetDescription: String {
        let size = DebugTargets.verificationSize
        return "\(Int(size.widthInPoints))x\(Int(size.heightInPoints)) pt"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button("Resize \(tracker.lastActiveName ?? "frontmost window") to \(targetDescription)") {
                resize()
            }

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resize() {
        do {
            guard windowManager.isProcessTrusted() else {
                windowManager.promptForAccessibilityPermission()
                status = "Not trusted for Accessibility. Grant permission, then try again."
                return
            }

            // Prefer the app that was active before the menu opened; opening the
            // menu can make ScreenResize itself frontmost.
            let application: ApplicationHandle
            if let pid = tracker.lastActiveProcessIdentifier {
                application = AXApplicationHandle(
                    processIdentifier: pid, localizedName: tracker.lastActiveName
                )
            } else {
                application = try windowManager.frontmostApplication()
            }

            let window = try windowManager.focusedWindow(of: application)
            let current = try windowManager.frame(of: window)
            // Resize in place: keep the window's existing origin so verification
            // never flings the target app off-screen.
            let target = PointFrame(origin: current.origin, size: DebugTargets.verificationSize)

            // All three outcomes are surfaced. Silent failure is the worst bug
            // this app can have — CLAUDE.md, hard constraint 3.
            switch try windowManager.applyFrame(target, to: window) {
            case .exact:
                status = "exact — \(application.localizedName ?? "window") is now \(targetDescription)."
            case .partial(let requested, let actual):
                status = "partial — asked for "
                    + "\(Int(requested.widthInPoints))x\(Int(requested.heightInPoints)) pt, "
                    + "got \(Int(actual.widthInPoints))x\(Int(actual.heightInPoints)) pt."
            }
        } catch let error as WindowManagerError {
            status = error.description
        } catch {
            status = "Unexpected failure: \(error)"
        }
    }
}
#endif
