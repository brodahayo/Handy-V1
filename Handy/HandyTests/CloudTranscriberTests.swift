import XCTest
@testable import Handy

final class CloudTranscriberTests: XCTestCase {
    func testMultipartBodyConstruction() throws {
        let transcriber = CloudTranscriber()
        let wavData = Data(repeating: 0, count: 100)
        let boundary = "test-boundary"

        let body = transcriber.buildMultipartBody(
            wavData: wavData,
            model: "whisper-large-v3",
            language: "en",
            boundary: boundary
        )

        let bodyString = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"file\""))
        XCTAssertTrue(bodyString.contains("filename=\"recording.wav\""))
        XCTAssertTrue(bodyString.contains("name=\"model\""))
        XCTAssertTrue(bodyString.contains("whisper-large-v3"))
        XCTAssertTrue(bodyString.contains("name=\"language\""))
        XCTAssertTrue(bodyString.contains("en"))
    }

    func testDeepgramURLConstruction() {
        let transcriber = CloudTranscriber()
        let url = transcriber.buildDeepgramURL(language: "es")
        XCTAssertTrue(url.absoluteString.contains("model=nova-2"))
        XCTAssertTrue(url.absoluteString.contains("language=es"))
    }

    func testDeepgramURLAutoLanguage() {
        let transcriber = CloudTranscriber()
        let url = transcriber.buildDeepgramURL(language: "auto")
        XCTAssertTrue(url.absoluteString.contains("detect_language=true"))
        // "detect_language" contains "language=", so check there's no standalone language param
        XCTAssertFalse(url.absoluteString.contains("&language="))
        XCTAssertFalse(url.absoluteString.contains("?language="))
    }
}
