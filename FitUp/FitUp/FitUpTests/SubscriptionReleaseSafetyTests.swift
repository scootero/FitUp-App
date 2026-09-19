import XCTest
@testable import FitUp

final class SubscriptionReleaseSafetyTests: XCTestCase {
    func testBypassFlagIsNotPresentInInfoPlist() {
        let value = Bundle.main.object(forInfoDictionaryKey: "FITUP_TESTFLIGHT_BYPASS")
        XCTAssertNil(value, "FITUP_TESTFLIGHT_BYPASS must not ship in the app Info.plist")
    }

    func testDevModeIsUnavailableOutsideDebug() {
        #if DEBUG
        XCTAssertTrue(DevMode.isAvailable)
        XCTAssertTrue(DevMode.isActive)
        #else
        XCTAssertFalse(DevMode.isAvailable)
        XCTAssertFalse(DevMode.isActive)
        #endif
    }
}
