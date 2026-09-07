import XCTest
import ScreenResizeCore

/// Group N — launch at login.
@MainActor
final class LoginItemTests: XCTestCase {

    private var loginItem: MockLoginItem!
    private var model: MenuBarModel!

    override func setUp() {
        super.setUp()
        loginItem = MockLoginItem()
        model = makeModel()
    }

    private func makeModel() -> MenuBarModel {
        MenuBarModel(
            windowManager: MockWindowManager(),
            screens: MockScreenProvider([Fixtures.primary]),
            frontmostTracker: MockFrontmostTracker(),
            preferences: PreferencesStore(
                defaults: UserDefaults(suiteName: "LoginItemTests-\(UUID().uuidString)")!),
            trustMonitor: MockTrustMonitor(),
            settingsOpener: MockSettingsOpener(),
            loginItem: loginItem
        )
    }

    override func tearDown() {
        model = nil; loginItem = nil
        super.tearDown()
    }

    // MARK: - The installed-location rule

    func testN1_appInApplicationsIsEligible() {
        XCTAssertTrue(SMAppServiceLoginItem.isInstalledLocation("/Applications/ScreenResize.app"))
        XCTAssertTrue(SMAppServiceLoginItem.isInstalledLocation(
            "/Users/someone/Applications/ScreenResize.app"))
    }

    func testN2_appInDerivedDataIsNotEligible() {
        let path = "/Users/someone/Library/Developer/Xcode/DerivedData/ScreenResize/"
            + "Build/Products/Debug/ScreenResize.app"
        XCTAssertFalse(SMAppServiceLoginItem.isInstalledLocation(path))
    }

    func testN3_ineligibleLocationExplainsItselfRatherThanFailingSilently() {
        let item = SMAppServiceLoginItem(bundlePath: "/tmp/ScreenResize.app")
        guard case .unavailable(let reason) = item.availability else {
            return XCTFail("Expected .unavailable")
        }
        XCTAssertTrue(reason.contains("Applications"), reason)
    }

    // MARK: - Model behaviour

    func testN4_enablingRegistersAndReflectsSystemState() {
        model.setLaunchesAtLogin(true)
        XCTAssertEqual(loginItem.setEnabledCalls, [true])
        XCTAssertTrue(model.launchesAtLogin)
        XCTAssertNil(model.launchAtLoginError)
    }

    func testN5_disablingUnregisters() {
        model.setLaunchesAtLogin(true)
        model.setLaunchesAtLogin(false)
        XCTAssertEqual(loginItem.setEnabledCalls, [true, false])
        XCTAssertFalse(model.launchesAtLogin)
    }

    func testN6_refusedChangeSurfacesTheReasonAndLeavesTheToggleHonest() {
        loginItem.availability = .unavailable(reason: "Move it to Applications.")
        model.setLaunchesAtLogin(true)

        XCTAssertFalse(model.launchesAtLogin, "The toggle must not claim a state the system refused")
        XCTAssertEqual(model.launchAtLoginError, "Move it to Applications.")
    }

    func testN7_stateIsReadFromTheSystemAtLaunchNotFromPreferences() {
        loginItem.isEnabled = true
        XCTAssertTrue(makeModel().launchesAtLogin,
                      "SMAppService is the source of truth; nothing is cached in defaults")
    }
}
