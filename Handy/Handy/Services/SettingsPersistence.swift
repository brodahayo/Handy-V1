import Foundation

final class SettingsPersistence {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            self.directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Handy")
        }
    }

    private var filePath: URL {
        directory.appendingPathComponent("settings.json")
    }

    func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: filePath, options: .atomic)
    }

    func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return AppSettings()
        }
        let data = try Data(contentsOf: filePath)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
}
