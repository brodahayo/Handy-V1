import Foundation

/// Stores secrets in a JSON file inside Application Support instead of the macOS Keychain.
/// This avoids the "Handy wants to use confidential information stored in..." system prompt
/// that appears for unsigned / locally-built apps accessing the Keychain.
struct KeychainService {
    let service: String
    private let fileManager = FileManager.default

    init(service: String = "com.handy.app") {
        self.service = service
    }

    // MARK: - Public API (same interface as before)

    func save(account: String, value: String) throws {
        var store = loadStore()
        store[account] = value
        try saveStore(store)
    }

    func retrieve(account: String) throws -> String? {
        let store = loadStore()
        return store[account]
    }

    func delete(account: String) throws {
        var store = loadStore()
        store.removeValue(forKey: account)
        try saveStore(store)
    }

    // MARK: - File-based storage

    private var storeURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(service, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("secrets.json")
    }

    private func loadStore() -> [String: String] {
        guard let data = try? Data(contentsOf: storeURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func saveStore(_ store: [String: String]) throws {
        let data = try JSONEncoder().encode(store)
        let url = storeURL
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        // Restrict file permissions to owner-only (read/write)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
}
