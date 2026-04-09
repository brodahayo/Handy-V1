import XCTest
@testable import Handy

final class SettingsTests: XCTestCase {
    func testDefaultSettings() {
        let settings = AppSettings()
        XCTAssertEqual(settings.holdModifierFlags, 8388608) // .function (Fn)
        XCTAssertEqual(settings.toggleKeyCode, 9) // V
        XCTAssertEqual(settings.toggleModifierFlags, 524288) // .option
        XCTAssertEqual(settings.cloudProvider, .groq)
        XCTAssertTrue(settings.cleanupEnabled)
        XCTAssertEqual(settings.cleanupStyle, .casual)
        XCTAssertEqual(settings.overlayStyle, .mini)
        XCTAssertEqual(settings.overlayPosition, .bottomCenter)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertEqual(settings.soundPack, .droplet)
        XCTAssertEqual(settings.language, "auto")
        XCTAssertEqual(settings.transcriptionMode, .cloud)
        XCTAssertTrue(settings.contextAware)
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

    func testDefaultHotkeyEnableFlags() {
        let settings = AppSettings()
        XCTAssertTrue(settings.holdToDictateEnabled)
        XCTAssertTrue(settings.toggleRecordingEnabled)
    }

    func testHotkeyEnableFlagsEncodeDecode() throws {
        var settings = AppSettings()
        settings.holdToDictateEnabled = false
        settings.toggleRecordingEnabled = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(decoded.holdToDictateEnabled)
        XCTAssertFalse(decoded.toggleRecordingEnabled)
    }

    func testBackwardCompatibility_missingEnableFlags() throws {
        // Simulate old settings JSON without the new fields
        let oldJSON = """
        {"holdKey":"fn","toggleModifier":"option","toggleKey":"v","cloudProvider":"groq",
         "language":"auto","transcriptionMode":"cloud","localModelSize":"base",
         "cleanupEnabled":true,"cleanupStyle":"casual","contextAware":true,
         "overlayStyle":"mini","overlayPosition":"bottom_center",
         "soundEnabled":true,"soundPack":"droplet","launchAtLogin":false,
         "dailyGoal":500,"appearanceMode":"dark","hotkeyMode":"hold_fn"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: oldJSON)
        XCTAssertTrue(decoded.holdToDictateEnabled)
        XCTAssertTrue(decoded.toggleRecordingEnabled)
    }

    func testBackwardCompatibility_migratesOldHotkeyFields() throws {
        // Old format with holdKey/toggleModifier/toggleKey strings
        let oldJSON = """
        {"holdKey":"option","toggleModifier":"command","toggleKey":"d","cloudProvider":"groq",
         "language":"auto","transcriptionMode":"cloud","localModelSize":"base",
         "cleanupEnabled":true,"cleanupStyle":"casual","contextAware":true,
         "overlayStyle":"mini","overlayPosition":"bottom_center",
         "soundEnabled":true,"soundPack":"droplet","launchAtLogin":false,
         "dailyGoal":500,"appearanceMode":"dark","hotkeyMode":"hold_fn"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: oldJSON)
        XCTAssertEqual(decoded.holdModifierFlags, 524288)  // .option
        XCTAssertEqual(decoded.toggleKeyCode, 2)            // D
        XCTAssertEqual(decoded.toggleModifierFlags, 1048576) // .command
    }

    func testNewFormatEncodeDecode() throws {
        var settings = AppSettings()
        settings.holdModifierFlags = 262144  // .control
        settings.toggleKeyCode = 49          // Space
        settings.toggleModifierFlags = 524288 // .option

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.holdModifierFlags, 262144)
        XCTAssertEqual(decoded.toggleKeyCode, 49)
        XCTAssertEqual(decoded.toggleModifierFlags, 524288)
    }

    func testCleanupPrompts() {
        XCTAssertTrue(CleanupStyle.casual.prompt.contains("natural"))
        XCTAssertTrue(CleanupStyle.professional.prompt.contains("polished"))
        XCTAssertTrue(CleanupStyle.minimal.prompt.lowercased().contains("preserving"))
    }
}
