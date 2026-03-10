import Foundation
import Observation

struct UserStats: Codable {
    var totalWords: Int = 0
    var todayWords: Int = 0
    var currentStreak: Int = 0
    var totalSecondsSaved: Double = 0
    var lastActiveDate: String? // ISO date string "yyyy-MM-dd"
}

@Observable
final class AppState {
    var isRecording = false
    var isProcessing = false
    var audioLevel: Float = 0.0
    var lastTranscription: String?
    var lastRawText: String?
    var errorMessage: String?
    var settings = AppSettings()
    var isSignedIn = false
    var userId: String?
    var userName: String?

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // Stats
    var totalWords: Int = 0
    var todayWords: Int = 0
    var currentStreak: Int = 0
    var totalSecondsSaved: Double = 0

    var formattedTimeSaved: String {
        let hours = Int(totalSecondsSaved) / 3600
        let minutes = (Int(totalSecondsSaved) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Stats Persistence

    private static var statsFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy")
            .appendingPathComponent("stats.json")
    }

    private static var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func loadStats() {
        guard FileManager.default.fileExists(atPath: Self.statsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.statsFileURL)
            let stats = try JSONDecoder().decode(UserStats.self, from: data)
            totalWords = stats.totalWords
            currentStreak = stats.currentStreak
            totalSecondsSaved = stats.totalSecondsSaved

            // Reset today's count if it's a new day
            if stats.lastActiveDate == Self.todayDateString {
                todayWords = stats.todayWords
            } else {
                todayWords = 0
            }
        } catch {
            // Start fresh if stats file is corrupted
        }
    }

    func recordTranscription(text: String, recordingDuration: TimeInterval) {
        let wordCount = text.split(separator: " ").count
        guard wordCount > 0 else { return }

        let today = Self.todayDateString

        // Update streak
        if let lastDate = loadLastActiveDate(), lastDate != today {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let last = formatter.date(from: lastDate) {
                let daysBetween = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
                if daysBetween == 1 {
                    currentStreak += 1
                } else if daysBetween > 1 {
                    currentStreak = 1
                }
            }
        } else if loadLastActiveDate() == nil {
            currentStreak = 1
        }

        todayWords += wordCount
        totalWords += wordCount

        // Estimate time saved: average typing speed ~40 WPM
        let typingTimeSaved = Double(wordCount) / 40.0 * 60.0
        totalSecondsSaved += typingTimeSaved

        saveStats(lastActiveDate: today)
    }

    private func loadLastActiveDate() -> String? {
        guard FileManager.default.fileExists(atPath: Self.statsFileURL.path),
              let data = try? Data(contentsOf: Self.statsFileURL),
              let stats = try? JSONDecoder().decode(UserStats.self, from: data) else {
            return nil
        }
        return stats.lastActiveDate
    }

    func clearHistory() {
        lastTranscription = nil
        lastRawText = nil
        todayWords = 0
        totalWords = 0
        currentStreak = 0
        totalSecondsSaved = 0
        saveStats(lastActiveDate: Self.todayDateString)
    }

    private func saveStats(lastActiveDate: String) {
        let stats = UserStats(
            totalWords: totalWords,
            todayWords: todayWords,
            currentStreak: currentStreak,
            totalSecondsSaved: totalSecondsSaved,
            lastActiveDate: lastActiveDate
        )
        do {
            let dir = Self.statsFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(stats)
            try data.write(to: Self.statsFileURL, options: .atomic)
        } catch {
            // Stats save failed — non-critical
        }
    }
}
