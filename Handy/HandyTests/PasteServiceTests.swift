import XCTest
@testable import Handy

final class PasteServiceTests: XCTestCase {
    func testCopyToClipboard() {
        let service = PasteService()
        service.copyToClipboard("Hello from Handy")

        let pasteboard = NSPasteboard.general
        let result = pasteboard.string(forType: .string)
        XCTAssertEqual(result, "Hello from Handy")
    }
}
