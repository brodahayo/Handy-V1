import XCTest
@testable import Handy

final class KeychainServiceTests: XCTestCase {
    let keychain = KeychainService(service: "com.handy.app.tests")

    override func tearDown() {
        try? keychain.delete(account: "test-key")
        // Clean up the test storage directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let testDir = appSupport.appendingPathComponent("com.handy.app.tests")
        try? FileManager.default.removeItem(at: testDir)
    }

    func testSaveAndRetrieve() throws {
        try keychain.save(account: "test-key", value: "gsk_abc123")
        let retrieved = try keychain.retrieve(account: "test-key")
        XCTAssertEqual(retrieved, "gsk_abc123")
    }

    func testRetrieveNonexistent() throws {
        let result = try keychain.retrieve(account: "nonexistent")
        XCTAssertNil(result)
    }

    func testDelete() throws {
        try keychain.save(account: "test-key", value: "value")
        try keychain.delete(account: "test-key")
        let result = try keychain.retrieve(account: "test-key")
        XCTAssertNil(result)
    }

    func testOverwrite() throws {
        try keychain.save(account: "test-key", value: "old")
        try keychain.save(account: "test-key", value: "new")
        let result = try keychain.retrieve(account: "test-key")
        XCTAssertEqual(result, "new")
    }
}
