import XCTest
@testable import Handy

final class TranscriptionTests: XCTestCase {
    func testTranscriptionCreation() {
        let t = TranscriptionRecord(
            text: "Hello world",
            rawText: "hello um world",
            wordCount: 2
        )
        XCTAssertEqual(t.text, "Hello world")
        XCTAssertEqual(t.rawText, "hello um world")
        XCTAssertEqual(t.wordCount, 2)
        XCTAssertNotNil(t.id)
        XCTAssertNotNil(t.timestamp)
    }

    func testTranscriptionEncodeDecode() throws {
        let t = TranscriptionRecord(text: "Test", rawText: "test", wordCount: 1)
        let data = try JSONEncoder().encode(t)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        XCTAssertEqual(decoded.text, "Test")
        XCTAssertEqual(decoded.id, t.id)
    }
}
