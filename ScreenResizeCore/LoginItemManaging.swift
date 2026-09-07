import Foundation
import ServiceManagement

/// Whether launch-at-login can be offered at all.
public enum LoginItemAvailability: Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool { self == .available }
}

public enum LoginItemError: Error, Equatable {
    case unavailable(reason: String)
}

/// Controls whether the app starts at login.
///
/// State is read from the system, never mirrored into preferences: the user can
/// change this in System Settings, and a cached copy would immediately disagree.
public protocol LoginItemManaging: AnyObject {
    var availability: LoginItemAvailability { get }
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// The real implementation, backed by `SMAppService`.
public final class SMAppServiceLoginItem: LoginItemManaging {

    private let bundlePath: String

    /// - Parameter bundlePath: injectable so the availability rule is testable
    ///   without moving the app around.
    public init(bundlePath: String = Bundle.main.bundlePath) {
        self.bundlePath = bundlePath
    }

    /// `SMAppService` registers whatever path the app currently occupies.
    ///
    /// Registering a build directory would create a login item pointing into
    /// DerivedData that silently stops working after the next clean, so this
    /// refuses and explains instead. Failing loudly beats a login item that
    /// quietly rots — CLAUDE.md's no-silent-failure rule applies here too.
    public var availability: LoginItemAvailability {
        guard Self.isInstalledLocation(bundlePath) else {
            return .unavailable(
                reason: "Move ScreenResize to your Applications folder to enable this. "
                    + "Right now it is running from a build directory, and a login item "
                    + "pointing there would stop working."
            )
        }
        return .available
    }

    /// True when the bundle lives somewhere a login item can reasonably persist.
    public static func isInstalledLocation(_ path: String) -> Bool {
        path.hasPrefix("/Applications/")
            || path.contains("/Applications/")   // e.g. ~/Applications
    }

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if case .unavailable(let reason) = availability {
            throw LoginItemError.unavailable(reason: reason)
        }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
