import XCTest
@testable import Handy

final class ContextDetectorTests: XCTestCase {
    func testBundleIdMapping() {
        XCTAssertEqual(ContextDetector.cleanupStyle(forBundleId: "com.apple.mail"), .professional)
        XCTAssertEqual(ContextDetector.cleanupStyle(forBundleId: "com.microsoft.Outlook"), .professional)
        XCTAssertEqual(ContextDetector.cleanupStyle(forBundleId: "com.apple.MobileSMS"), .casual)
        XCTAssertEqual(ContextDetector.cleanupStyle(forBundleId: "com.tinyspeck.slackmacgap"), .casual)
        XCTAssertEqual(ContextDetector.cleanupStyle(forBundleId: "com.apple.Terminal"), .minimal)
        XCTAssertEqual(ContextDetector.cleanupStyle(forBundleId: "com.googlecode.iterm2"), .minimal)
        XCTAssertNil(ContextDetector.cleanupStyle(forBundleId: "com.unknown.app"))
    }
}
