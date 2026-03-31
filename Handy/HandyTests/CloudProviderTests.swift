import XCTest
@testable import Handy

final class CloudProviderTests: XCTestCase {
    func testProviderProperties() {
        XCTAssertEqual(CloudProvider.groq.displayName, "Groq")
        XCTAssertEqual(CloudProvider.groq.apiKeyPrefix, "gsk_")
        XCTAssertEqual(CloudProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(CloudProvider.openai.apiKeyPrefix, "sk-")
        XCTAssertEqual(CloudProvider.deepgram.displayName, "Deepgram")
        XCTAssertNil(CloudProvider.deepgram.apiKeyPrefix)
    }

    func testProviderKeyURLs() {
        XCTAssertTrue(CloudProvider.groq.apiKeyURL.absoluteString.contains("groq.com"))
        XCTAssertTrue(CloudProvider.openai.apiKeyURL.absoluteString.contains("openai.com"))
        XCTAssertTrue(CloudProvider.deepgram.apiKeyURL.absoluteString.contains("deepgram.com"))
    }

    func testProviderWhisperModel() {
        XCTAssertEqual(CloudProvider.groq.whisperModel, "whisper-large-v3")
        XCTAssertEqual(CloudProvider.openai.whisperModel, "whisper-1")
        XCTAssertNil(CloudProvider.deepgram.whisperModel)
    }
}
