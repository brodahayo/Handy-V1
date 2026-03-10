import XCTest
@testable import Handy

final class TextCleanupTests: XCTestCase {
    func testChatRequestBody() throws {
        let cleanup = TextCleanup()
        let body = try cleanup.buildChatRequestBody(
            text: "um hello world",
            style: .casual,
            provider: .groq
        )

        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        let model = json["model"] as! String
        XCTAssertEqual(model, "llama-3.3-70b-versatile")

        let messages = json["messages"] as! [[String: String]]
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertTrue(messages[0]["content"]!.contains("natural"))
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "um hello world")

        let temperature = json["temperature"] as! Double
        XCTAssertEqual(temperature, 0.3, accuracy: 0.01)
    }
}
