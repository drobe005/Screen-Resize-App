import XCTest
import ScreenResizeCore

/// Group J — the Accessibility permission lifecycle.
@MainActor
final class PermissionLifecycleTests: XCTestCase {

    private var windowManager: MockWindowManager!
    private var monitor: MockTrustMonitor!
    private var opener: MockSettingsOpener!
    private var model: MenuBarModel!

    override func setUp() {
        super.setUp()
        windowManager = MockWindowManager()
        windowManager.storedFrame = Fixtures.frame(100, 100, 800, 600)
        monitor = MockTrustMonitor()
        opener = MockSettingsOpener()
        model = makeModel()
    }

    private func makeModel() -> MenuBarModel {
        MenuBarModel(
            windowManager: windowManager,
            screens: MockScreenProvider([Fixtures.primary, Fixtures.secondary]),
            frontmostTracker: MockFrontmostTracker(),
            preferences: PreferencesStore(
                defaults: UserDefaults(suiteName: "PermissionLifecycleTests-\(UUID().uuidString)")!),
            trustMonitor: monitor,
            settingsOpener: opener
        )
    }

    override func tearDown() {
        model = nil; opener = nil; monitor = nil; windowManager = nil
        super.tearDown()
    }

    // J1
    func testUntrustedAtLaunchDrivesOnboarding() {
        windowManager.isTrusted = false
        model = makeModel()
        XCTAssertFalse(model.isTrusted)
        model.refresh()
        XCTAssertEqual(model.state, .permissionRequired)
    }

    // J2 — the core of "no restart required".
    func testGrantingPermissionUpdatesStateWithoutRestart() {
        windowManager.isTrusted = false
        model = makeModel()
        XCTAssertFalse(model.isTrusted)

        // The user grants permission in System Settings and switches back.
        windowManager.isTrusted = true
        monitor.fire()

        XCTAssertTrue(model.isTrusted, "Trust must be re-checked, not cached from launch")
        guard case .ready = model.state else {
            return XCTFail("Expected .ready after grant, got \(model.state)")
        }
    }

    // J3
    func testRevokingPermissionReturnsToTheCallToAction() {
        windowManager.isTrusted = true
        model = makeModel()
        model.refresh()
        XCTAssertTrue(model.isTrusted)

        windowManager.isTrusted = false
        monitor.fire()

        XCTAssertFalse(model.isTrusted)
        XCTAssertEqual(model.state, .permissionRequired)
    }

    // J4
    func testRequestPermissionPromptsTheSystem() {
        model.requestPermission()
        XCTAssertEqual(windowManager.promptCount, 1)
    }

    // J5
    func testOpenSettingsUsesTheDeepLinkOnce() {
        model.openAccessibilitySettings()
        XCTAssertEqual(opener.openCount, 1)
    }

    // J6 — activation notifications fire constantly; they must not wipe a failure.
    func testMonitorFiringWithoutATrustChangePreservesFailureMessage() {
        windowManager.isTrusted = true
        windowManager.applyBehavior = .refuse
        model = makeModel()
        model.refresh()

        let option = ResolutionCatalog.groups
            .flatMap { model.options(in: $0) }
            .first { $0.resolution.name == "1280x720" }!
        model.apply(option)
        XCTAssertNotNil(model.failureMessage)

        monitor.fire()   // ordinary app activation, trust unchanged

        XCTAssertNotNil(model.failureMessage,
                        "Switching away and back must not erase why a resize failed")
    }

    // J7
    func testModelSubscribesToTheMonitorOnInit() {
        XCTAssertTrue(monitor.isStarted, "Model must start monitoring without being asked")
        XCTAssertNotNil(monitor.onPossibleTrustChange)
    }

    // J8 — regression guard: no size lists while untrusted.
    func testNoOptionsAreExposedWhileUntrusted() {
        windowManager.isTrusted = false
        model = makeModel()
        model.refresh()
        for group in ResolutionCatalog.groups {
            XCTAssertTrue(model.options(in: group).isEmpty)
        }
    }

    // J9 — the deep link must actually be a valid URL.
    func testAccessibilityDeepLinkIsAWellFormedURL() {
        let url = URL(string: WorkspaceSettingsOpener.accessibilityPaneURL)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }
}
