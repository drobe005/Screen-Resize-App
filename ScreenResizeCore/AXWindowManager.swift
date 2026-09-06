import AppKit
import ApplicationServices
import CoreGraphics

/// A window handle wrapping a real `AXUIElement`.
public final class AXWindowHandle: WindowHandle {
    internal let element: AXUIElement
    internal init(element: AXUIElement) { self.element = element }
}

/// An application handle wrapping a real `AXUIElement` built from a pid.
public final class AXApplicationHandle: ApplicationHandle {
    public let processIdentifier: pid_t
    public let localizedName: String?
    internal let element: AXUIElement

    /// Builds a handle for a specific process.
    ///
    /// Public so callers can target an application other than the frontmost one.
    /// This matters for menu-bar-driven actions: opening the menu can make
    /// ScreenResize itself frontmost, so the caller usually needs to name the
    /// application it actually means.
    public init(processIdentifier: pid_t, localizedName: String?) {
        self.processIdentifier = processIdentifier
        self.localizedName = localizedName
        self.element = AXUIElementCreateApplication(processIdentifier)
    }
}

/// The real `WindowManaging`, backed by the Accessibility API.
///
/// Call from the main thread: `NSWorkspace.frontmostApplication` is a main-thread
/// API, and the AX calls are synchronous and can block.
public final class AXWindowManager: WindowManaging {

    public init() {}

    // MARK: - Permission

    public func isProcessTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    @discardableResult
    public func promptForAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Application and window lookup

    public func frontmostApplication() throws -> ApplicationHandle {
        guard isProcessTrusted() else { throw WindowManagerError.permissionDenied }
        // There is no Accessibility call that returns the frontmost application.
        // AXUIElementCreateApplication needs a pid, and AppKit is where it comes from.
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw WindowManagerError.noFrontmostApp
        }
        return AXApplicationHandle(
            processIdentifier: app.processIdentifier,
            localizedName: app.localizedName
        )
    }

    public func focusedWindow(of application: ApplicationHandle) throws -> WindowHandle {
        guard let application = application as? AXApplicationHandle else {
            throw WindowManagerError.unsupportedHandle
        }
        let attribute = kAXFocusedWindowAttribute as String
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(application.element, attribute as CFString, &value)

        switch status {
        case .success:
            break
        case .apiDisabled:
            throw WindowManagerError.permissionDenied
        case .noValue, .attributeUnsupported:
            // The app is running but has nothing focused: only panels open, or
            // it is sitting in a full-screen space.
            throw WindowManagerError.noFocusedWindow
        default:
            throw WindowManagerError.attributeUnavailable(
                attribute: attribute, axErrorCode: status.rawValue
            )
        }

        guard let element = value, CFGetTypeID(element) == AXUIElementGetTypeID() else {
            throw WindowManagerError.noFocusedWindow
        }
        return AXWindowHandle(element: element as! AXUIElement)
    }

    // MARK: - Reading

    public func frame(of window: WindowHandle) throws -> PointFrame {
        let element = try axElement(of: window)
        return PointFrame(origin: try readOrigin(element), size: try readSize(element))
    }

    // MARK: - Writing

    public func applyFrame(_ frame: PointFrame, to window: WindowHandle) throws -> ResizeOutcome {
        let element = try axElement(of: window)
        let before = PointFrame(origin: try readOrigin(element), size: try readSize(element))

        // Write order comes from WindowWriteSequence.standard (size, origin, size)
        // where the reasoning lives and is unit tested. Applying it as data keeps
        // the documented order and the executed order from drifting apart.
        for step in WindowWriteSequence.standard {
            switch step {
            case .size:   try write(size: frame.size, to: element)
            case .origin: try write(origin: frame.origin, to: element)
            }
        }

        // Never trust the AXError returned by a write. Read the window back and
        // compare. See CLAUDE.md, hard constraint 3.
        let after = PointFrame(origin: try readOrigin(element), size: try readSize(element))

        if after.isApproximately(frame) {
            return .exact
        }
        if after.isApproximately(before) {
            // Nothing moved at all: a fixed-size window, an Electron app that
            // ignores the request, or a window in a full-screen space.
            throw WindowManagerError.resizeRejected(requested: frame.size, actual: after.size)
        }
        return .partial(requested: frame.size, actual: after.size)
    }

    // MARK: - AX plumbing

    private func axElement(of window: WindowHandle) throws -> AXUIElement {
        guard let window = window as? AXWindowHandle else {
            throw WindowManagerError.unsupportedHandle
        }
        return window.element
    }

    private func readSize(_ element: AXUIElement) throws -> PointSize {
        var size = CGSize.zero
        try readAXValue(element, attribute: kAXSizeAttribute as String, type: .cgSize, into: &size)
        return PointSize(widthInPoints: size.width, heightInPoints: size.height)
    }

    private func readOrigin(_ element: AXUIElement) throws -> AXPointOrigin {
        var point = CGPoint.zero
        try readAXValue(element, attribute: kAXPositionAttribute as String, type: .cgPoint, into: &point)
        return AXPointOrigin(xInPoints: point.x, yInPoints: point.y)
    }

    private func write(size: PointSize, to element: AXUIElement) throws {
        var cgSize = CGSize(width: size.widthInPoints, height: size.heightInPoints)
        try writeAXValue(element, attribute: kAXSizeAttribute as String, type: .cgSize, from: &cgSize)
    }

    private func write(origin: AXPointOrigin, to element: AXUIElement) throws {
        var cgPoint = CGPoint(x: origin.xInPoints, y: origin.yInPoints)
        try writeAXValue(element, attribute: kAXPositionAttribute as String, type: .cgPoint, from: &cgPoint)
    }

    /// CGSize and CGPoint are not CoreFoundation types, so they must be boxed in
    /// an AXValue to cross the Accessibility API. This and `writeAXValue` are the
    /// only places where our point types meet the AX representation.
    private func readAXValue<T>(
        _ element: AXUIElement, attribute: String, type: AXValueType, into out: inout T
    ) throws {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else { throw mapReadFailure(status, attribute: attribute) }

        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            throw WindowManagerError.attributeUnavailable(
                attribute: attribute, axErrorCode: AXError.noValue.rawValue
            )
        }
        guard AXValueGetValue(value as! AXValue, type, &out) else {
            throw WindowManagerError.attributeUnavailable(
                attribute: attribute, axErrorCode: AXError.illegalArgument.rawValue
            )
        }
    }

    private func writeAXValue<T>(
        _ element: AXUIElement, attribute: String, type: AXValueType, from source: inout T
    ) throws {
        guard let boxed = AXValueCreate(type, &source) else {
            throw WindowManagerError.attributeUnavailable(
                attribute: attribute, axErrorCode: AXError.illegalArgument.rawValue
            )
        }
        let status = AXUIElementSetAttributeValue(element, attribute as CFString, boxed)

        // A write failing outright is worth reporting, but a write "succeeding"
        // proves nothing — the caller still reads the frame back.
        switch status {
        case .success:
            return
        case .apiDisabled:
            throw WindowManagerError.permissionDenied
        case .attributeUnsupported, .illegalArgument:
            // A fixed-size window reports its size attribute as unsettable. That is
            // a rejection, not a hard failure, so let the readback classify it.
            return
        default:
            throw WindowManagerError.attributeUnavailable(
                attribute: attribute, axErrorCode: status.rawValue
            )
        }
    }

    private func mapReadFailure(_ status: AXError, attribute: String) -> WindowManagerError {
        switch status {
        case .apiDisabled:
            return .permissionDenied
        case .invalidUIElement:
            return .noFocusedWindow
        default:
            return .attributeUnavailable(attribute: attribute, axErrorCode: status.rawValue)
        }
    }
}
