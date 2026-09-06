#if DEBUG
import AppKit
import Combine

/// Remembers the most recently activated application that is not ScreenResize.
///
/// Debug scaffolding for the Phase 2 verification. Opening a `MenuBarExtra` can
/// make ScreenResize itself the frontmost application, in which case asking for
/// "the frontmost app" at the moment the menu item is clicked returns us, not
/// the app the user was actually looking at. Observing activations instead gives
/// the right target.
///
/// The product UI will need a considered answer to this same problem; this class
/// is not it.
final class FrontmostAppTracker: ObservableObject {

    @Published private(set) var lastActiveProcessIdentifier: pid_t?
    @Published private(set) var lastActiveName: String?

    private var observer: NSObjectProtocol?

    init() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  app.processIdentifier != ownPID
            else { return }
            self?.lastActiveProcessIdentifier = app.processIdentifier
            self?.lastActiveName = app.localizedName
        }

        // Seed from whatever is frontmost at launch, so the first click works
        // without waiting for an activation to happen.
        if let current = NSWorkspace.shared.frontmostApplication,
           current.processIdentifier != ownPID {
            lastActiveProcessIdentifier = current.processIdentifier
            lastActiveName = current.localizedName
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
#endif
