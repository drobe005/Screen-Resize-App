import Foundation
import ScreenResizeCore

/// A scriptable `WindowManaging` for tests.
///
/// Touches no Accessibility API and needs no permission, so the whole geometry
/// and control surface can be exercised with no real windows.
final class MockWindowManager: WindowManaging {

    /// How the window under test responds to a frame write.
    enum ApplyBehavior {
        /// The window does exactly what it is told.
        case accept
        /// The window resizes, but clamps to this size. Stands in for a window
        /// with a minimum or maximum size.
        case clamp(to: PointSize)
        /// The window ignores the request entirely. Stands in for a fixed-size
        /// window, an Electron app, or a full-screen space.
        case refuse
    }

    // MARK: - Script

    var isTrusted = true
    var frontmostApp: MockApplicationHandle? = MockApplicationHandle(
        processIdentifier: 1234, localizedName: "MockApp"
    )
    var focusedWindow: MockWindowHandle? = MockWindowHandle()
    var storedFrame = PointFrame(
        origin: PointOrigin(xInPoints: 0, yInPoints: 0),
        size: PointSize(widthInPoints: 800, heightInPoints: 600)
    )
    var applyBehavior: ApplyBehavior = .accept

    // MARK: - Recorded calls

    private(set) var promptCount = 0
    private(set) var appliedFrames: [PointFrame] = []

    // MARK: - WindowManaging

    func isProcessTrusted() -> Bool { isTrusted }

    @discardableResult
    func promptForAccessibilityPermission() -> Bool {
        promptCount += 1
        return isTrusted
    }

    func frontmostApplication() throws -> ApplicationHandle {
        guard isTrusted else { throw WindowManagerError.permissionDenied }
        guard let frontmostApp else { throw WindowManagerError.noFrontmostApp }
        return frontmostApp
    }

    func focusedWindow(of application: ApplicationHandle) throws -> WindowHandle {
        guard isTrusted else { throw WindowManagerError.permissionDenied }
        guard application is MockApplicationHandle else { throw WindowManagerError.unsupportedHandle }
        guard let focusedWindow else { throw WindowManagerError.noFocusedWindow }
        return focusedWindow
    }

    func frame(of window: WindowHandle) throws -> PointFrame {
        guard isTrusted else { throw WindowManagerError.permissionDenied }
        guard window is MockWindowHandle else { throw WindowManagerError.unsupportedHandle }
        return storedFrame
    }

    @discardableResult
    func applyFrame(_ frame: PointFrame, to window: WindowHandle) throws -> ResizeOutcome {
        guard isTrusted else { throw WindowManagerError.permissionDenied }
        guard window is MockWindowHandle else { throw WindowManagerError.unsupportedHandle }
        appliedFrames.append(frame)

        let before = storedFrame
        switch applyBehavior {
        case .accept:
            storedFrame = frame
        case .clamp(let clampedSize):
            storedFrame = PointFrame(origin: frame.origin, size: clampedSize)
        case .refuse:
            break
        }

        // Same classification the real implementation performs after its readback.
        if storedFrame.isApproximately(frame) { return .exact }
        if storedFrame.isApproximately(before) {
            throw WindowManagerError.resizeRejected(requested: frame.size, actual: storedFrame.size)
        }
        return .partial(requested: frame.size, actual: storedFrame.size)
    }
}

final class MockApplicationHandle: ApplicationHandle {
    let processIdentifier: pid_t
    let localizedName: String?
    init(processIdentifier: pid_t, localizedName: String?) {
        self.processIdentifier = processIdentifier
        self.localizedName = localizedName
    }
}

final class MockWindowHandle: WindowHandle {}
