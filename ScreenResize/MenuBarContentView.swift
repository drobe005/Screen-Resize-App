import SwiftUI
import ScreenResizeCore

/// Placeholder menu bar content for the scaffold.
///
/// Resolution presets are not here yet, and when they arrive they must be read
/// from the shared preset model rather than hardcoded in this view. See the
/// "Resolution presets live in a single data model" rule in CLAUDE.md.
struct MenuBarContentView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ScreenResize")
                .font(.headline)

            Text("Core \(ScreenResizeCore.version)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Load-bearing, not decoration: an LSUIElement app with no Quit
            // control can only be killed from the command line.
            Button("Quit ScreenResize") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
    }
}
