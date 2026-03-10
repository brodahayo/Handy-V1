import XCTest
@testable import Handy

final class SettingsTests: XCTestCase {
    func testDefaultSettings() {
        let settings = AppSettings()
        XCTAssertEqual(settings.holdKey, .fn)
        XCTAssertEqual(settings.toggleModifier, "option")
        XCTAssertEqual(settings.toggleKey, "v")
        XCTAssertEqual(settings.cloudProvider, .groq)
        XCTAssertTrue(settings.cleanupEnabled)
        XCTAssertEqual(settings.cleanupStyle, .casual)
        XCTAssertEqual(settings.overlayStyle, .mini)
        XCTAssertEqual(settings.overlayPosition, .topCenter)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertEqual(settings.soundPack, .woody)
        XCTAssertEqual(settings.language, "auto")
        XCTAssertEqual(settings.transcriptionMode, .cloud)
        XCTAssertFalse(settings.contextAware)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testSettingsEncodeDecode() throws {
        var settings = AppSettings()
        settings.cloudProvider = .openai
        settings.cleanupStyle = .professional
        settings.overlayPosition = .bottomRight

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.cloudProvider, .openai)
        XCTAssertEqual(decoded.cleanupStyle, .professional)
        XCTAssertEqual(decoded.overlayPosition, .bottomRight)
    }

    func testCleanupPrompts() {
        XCTAssertTrue(CleanupStyle.casual.prompt.contains("natural"))
        XCTAssertTrue(CleanupStyle.professional.prompt.contains("polished"))
        XCTAssertTrue(CleanupStyle.minimal.prompt.lowercased().contains("preserve"))
    }
}
