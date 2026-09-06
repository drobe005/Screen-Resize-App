import XCTest

// Plain import, not @testable. ScreenResizeCore is a separate framework, so
// everything the app consumes from it must be public anyway — which leaves
// little for @testable to reach. It also requires ENABLE_TESTABILITY, which is
// Debug-only, so @testable here would break `./scripts/build.sh Release`.
import ScreenResizeCore

/// Scaffold wiring check.
///
/// This proves the test bundle compiles, links ScreenResizeCore, and runs with
/// no test host — meaning tests never launch the app and never require
/// Accessibility permission, as CLAUDE.md requires.
final class ScaffoldSanityTests: XCTestCase {

    func testCoreVersionIsNotEmpty() {
        XCTAssertFalse(ScreenResizeCore.version.isEmpty)
    }
}
