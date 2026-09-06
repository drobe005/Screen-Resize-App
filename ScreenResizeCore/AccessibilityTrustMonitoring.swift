import AppKit

/// Reports moments at which Accessibility trust might have changed.
///
/// macOS publishes no notification for "the user changed a TCC permission", so
/// this cannot be an exact signal. What it can do is fire at the moments a change
/// is likely to have just happened — the user coming back to the app after
/// visiting System Settings, or the machine waking — and let the caller re-check.
///
/// Event-driven by design. Nothing here polls, per the project's no-timer rule.
@MainActor
public protocol AccessibilityTrustMonitoring: AnyObject {
    /// Invoked on the main thread when trust may have changed.
    var onPossibleTrustChange: (() -> Void)? { get set }
    func start()
    func stop()
}

/// The real monitor, built only from documented notifications.
@MainActor
public final class SystemTrustMonitor: AccessibilityTrustMonitoring {

    public var onPossibleTrustChange: (() -> Void)?

    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    // nonisolated so it can be used as a default argument, which is evaluated
    // outside the main actor. It touches no isolated state.
    public nonisolated init() {}

    public func start() {
        guard observers.isEmpty else { return }

        // The user granting permission in System Settings and switching back is
        // the overwhelmingly common case.
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification)

        // Waking can restore a session in which permissions were altered, and
        // clears any stale trust result cached across sleep.
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification)
    }

    public func stop() {
        for entry in observers {
            entry.center.removeObserver(entry.token)
        }
        observers.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            // Delivered on .main by contract, so hopping actors would only add a
            // runloop turn and make the change observable a beat late.
            MainActor.assumeIsolated {
                self?.onPossibleTrustChange?()
            }
        }
        observers.append((center, token))
    }

    deinit {
        // stop() is main-actor isolated; tear down directly.
        for entry in observers {
            entry.center.removeObserver(entry.token)
        }
    }
}
