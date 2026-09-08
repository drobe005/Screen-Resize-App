import Foundation
import ScreenResizeCore

/// Synthetic display arrangement, so multi-display behaviour is testable on a
/// machine with one screen.
final class MockScreenProvider: ScreenProviding {
    var configuredDisplays: [DisplayGeometry]
    init(_ displays: [DisplayGeometry]) { configuredDisplays = displays }
    func displays() -> [DisplayGeometry] { configuredDisplays }
}

final class MockFrontmostTracker: FrontmostApplicationTracking {
    var lastActiveProcessIdentifier: pid_t?
    var lastActiveApplicationName: String?

    init(processIdentifier: pid_t? = 4321, name: String? = "Safari") {
        lastActiveProcessIdentifier = processIdentifier
        lastActiveApplicationName = name
    }
}

@MainActor
final class MockTrustMonitor: AccessibilityTrustMonitoring {
    var onPossibleTrustChange: (() -> Void)?
    private(set) var isStarted = false

    func start() { isStarted = true }
    func stop() { isStarted = false }

    /// Simulates the moment the user comes back from System Settings, or a wake.
    func fire() { onPossibleTrustChange?() }
}

@MainActor
final class MockSettingsOpener: SystemSettingsOpening {
    private(set) var openCount = 0
    func openAccessibilityPane() { openCount += 1 }
}

final class MockLoginItem: LoginItemManaging {
    var availability: LoginItemAvailability = .available
    var isEnabled = false
    private(set) var setEnabledCalls: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        setEnabledCalls.append(enabled)
        if case .unavailable(let reason) = availability {
            throw LoginItemError.unavailable(reason: reason)
        }
        isEnabled = enabled
    }
}

/// Test fixtures shared by the geometry and model suites.
enum Fixtures {

    /// Primary: 2000x1200, 25pt menu bar, 100pt Dock, @2x.
    static let primary = DisplayGeometry(
        visibleFrameInAppKitPoints: AppKitPointRect(
            origin: AppKitPointOrigin(xInPoints: 0, yInPoints: 100),
            size: PointSize(widthInPoints: 2000, heightInPoints: 1075)
        ),
        backingScaleFactor: 2.0,
        primaryDisplayHeightInPoints: 1200
    )

    /// Secondary: 1600x1000, above and to the left of the primary, @1x.
    static let secondary = DisplayGeometry(
        visibleFrameInAppKitPoints: AppKitPointRect(
            origin: AppKitPointOrigin(xInPoints: -1600, yInPoints: 1200),
            size: PointSize(widthInPoints: 1600, heightInPoints: 975)
        ),
        backingScaleFactor: 1.0,
        primaryDisplayHeightInPoints: 1200
    )

    static func frame(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> PointFrame {
        PointFrame(origin: AXPointOrigin(xInPoints: x, yInPoints: y),
                   size: PointSize(widthInPoints: w, heightInPoints: h))
    }

    /// A resolution from the real catalog, by name.
    static func catalogResolution(_ name: String) -> Resolution {
        ResolutionCatalog.all.first { $0.name == name }!
    }
}
