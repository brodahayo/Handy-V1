import XCTest
@testable import Handy

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("1.2.0", than: "1.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("1.1.0", than: "1.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.1.1", than: "1.1.0"))
    }
}
