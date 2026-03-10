import Foundation

struct AppUpdate {
    let version: String
    let downloadURL: URL?
    let releaseNotes: String?
}

final class UpdateChecker {
    private let currentVersion: String
    private let repoOwner: String
    private let repoName: String

    init(
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
        repoOwner: String = "brodahayo",
        repoName: String = "Handy-V1"
    ) {
        self.currentVersion = currentVersion
        self.repoOwner = repoOwner
        self.repoName = repoName
    }

    func checkForUpdates() async throws -> AppUpdate? {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("Handy/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let tagName = json?["tag_name"] as? String else { return nil }
        let version = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

        guard Self.isNewer(version, than: currentVersion) else { return nil }

        let assets = json?["assets"] as? [[String: Any]] ?? []
        let dmgAsset = assets.first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }
        let downloadURL = (dmgAsset?["browser_download_url"] as? String).flatMap { URL(string: $0) }

        let releaseNotes = json?["body"] as? String

        return AppUpdate(version: version, downloadURL: downloadURL, releaseNotes: releaseNotes)
    }

    static func isNewer(_ version: String, than current: String) -> Bool {
        let v1 = version.split(separator: ".").compactMap { Int($0) }
        let v2 = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1.count, v2.count) {
            let a = i < v1.count ? v1[i] : 0
            let b = i < v2.count ? v2[i] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }
}
