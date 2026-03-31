import XCTest
@testable import Handy

final class SettingsPersistenceTests: XCTestCase {
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("HandyTest-\(UUID().uuidString)")

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
    }

    func testSaveAndLoad() throws {
        let persistence = SettingsPersistence(directory: testDir)
        var settings = AppSettings()
        settings.cloudProvider = .openai
        settings.cleanupStyle = .professional

        try persistence.save(settings)
        let loaded = try persistence.load()

        XCTAssertEqual(loaded.cloudProvider, .openai)
        XCTAssertEqual(loaded.cleanupStyle, .professional)
    }

    func testLoadDefaultsWhenNoFile() throws {
        let persistence = SettingsPersistence(directory: testDir)
        let settings = try persistence.load()
        XCTAssertEqual(settings.holdKey, .fn)
        XCTAssertEqual(settings.toggleModifier, "option")
    }
}
