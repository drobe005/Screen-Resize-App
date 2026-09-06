import AppKit

/// Remembers which application the user was actually working in.
///
/// Necessary because opening the menu can make ScreenResize itself the frontmost
/// application. Asking "what is frontmost?" at the moment a menu item is clicked
/// can therefore answer "ScreenResize", which has no window worth resizing.
/// Tracking activations as they happen gives the right answer instead.
public protocol FrontmostApplicationTracking: AnyObject {
    var lastActiveProcessIdentifier: pid_t? { get }
    var lastActiveApplicationName: String? { get }
}

/// The real tracker, driven by `NSWorkspace` activation notifications.
///
/// Event-driven, never polled: nothing here runs on a timer.
public final class WorkspaceFrontmostTracker: FrontmostApplicationTracking {

    public private(set) var lastActiveProcessIdentifier: pid_t?
    public private(set) var lastActiveApplicationName: String?

    private var observer: NSObjectProtocol?
    private let ownProcessIdentifier: pid_t

    public init() {
        ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  app.processIdentifier != self.ownProcessIdentifier
            else { return }
            self.lastActiveProcessIdentifier = app.processIdentifier
            self.lastActiveApplicationName = app.localizedName
        }

        // Seed from whatever is frontmost at launch so the first menu open works
        // without waiting for an activation to occur.
        if let current = NSWorkspace.shared.frontmostApplication,
           current.processIdentifier != ownProcessIdentifier {
            lastActiveProcessIdentifier = current.processIdentifier
            lastActiveApplicationName = current.localizedName
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
