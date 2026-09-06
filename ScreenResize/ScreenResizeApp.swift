import SwiftUI

/// ScreenResize is a menu bar only app: `LSUIElement` is true in Info.plist, so
/// there is no Dock icon and no main window. `MenuBarExtra` is the only scene.
@main
struct ScreenResizeApp: App {

    var body: some Scene {
        MenuBarExtra("ScreenResize", systemImage: "rectangle.inset.filled") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
