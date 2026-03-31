import Foundation

final class UserDataManager {
    private let baseDir: URL

    init() {
        baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy")
    }

    func userDirectory(for userId: String?) -> URL {
        if let userId {
            return baseDir.appendingPathComponent("users/\(userId)")
        }
        return baseDir
    }

    func settingsPersistence(for userId: String?) -> SettingsPersistence {
        SettingsPersistence(directory: userDirectory(for: userId))
    }
}
