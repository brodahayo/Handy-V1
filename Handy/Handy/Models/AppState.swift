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
    var transcriptionHistory: [TranscriptionRecord] = []
    var wordFrequencies: [(word: String, count: Int)] = []
    var settings = AppSettings()
    var selectedPage: String? = "Home"
    var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    var isRecordingHotkey = false
    var isMeetingRecording = false
    var isMeetingProcessing = false
    var meetingAudioLevel: Float = 0.0
    var isSignedIn = false
    var userId: String?

    var userName: String? {
        get { UserDefaults.standard.string(forKey: "userName") }
        set { UserDefaults.standard.set(newValue, forKey: "userName") }
    }

    var userEmail: String? {
        get { UserDefaults.standard.string(forKey: "userEmail") }
        set { UserDefaults.standard.set(newValue, forKey: "userEmail") }
    }

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
        guard FileManager.default.fileExists(atPath: Self.statsFileURL.path) else {
            loadHistory()
            return
        }
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
        loadHistory()
        loadWordFrequencies()
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

        // Update word frequencies
        updateWordFrequencies(text: text)

        // Save to history
        let record = TranscriptionRecord(
            text: text,
            rawText: lastRawText ?? text,
            wordCount: wordCount
        )
        transcriptionHistory.insert(record, at: 0)
        // Keep last 100 transcriptions
        if transcriptionHistory.count > 100 {
            transcriptionHistory = Array(transcriptionHistory.prefix(100))
        }
        saveHistory()

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
        transcriptionHistory = []
        todayWords = 0
        totalWords = 0
        currentStreak = 0
        totalSecondsSaved = 0
        saveStats(lastActiveDate: Self.todayDateString)
        saveHistory()
    }

    // MARK: - History Persistence

    private static var historyFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy")
            .appendingPathComponent("history.json")
    }

    func loadHistory() {
        guard FileManager.default.fileExists(atPath: Self.historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.historyFileURL)
            transcriptionHistory = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            // Start fresh if history file is corrupted
        }
    }

    private func saveHistory() {
        do {
            let dir = Self.historyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(transcriptionHistory)
            try data.write(to: Self.historyFileURL, options: .atomic)
        } catch {
            // History save failed — non-critical
        }
    }

    // MARK: - Word Frequency

    private static var wordFreqFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy")
            .appendingPathComponent("word_freq.json")
    }

    private static let stopWords: Set<String> = [
        "the", "a", "an", "is", "it", "in", "on", "to", "and", "of", "for",
        "that", "this", "with", "was", "are", "be", "at", "or", "as", "by",
        "but", "not", "we", "i", "you", "he", "she", "they", "my", "me",
        "do", "so", "if", "no", "up", "all", "just", "can", "will", "has",
        "have", "had", "been", "would", "could", "should", "did", "does",
        "am", "im", "its", "than", "then", "them", "their", "there", "from",
        "what", "when", "where", "which", "who", "how", "about", "into",
        "our", "out", "also", "very", "too", "here", "some", "more",
    ]

    private func updateWordFrequencies(text: String) {
        // Load existing frequencies
        var freqMap = loadWordFreqMap()

        // Extract words, lowercase, filter short/stop words
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 3 && !Self.stopWords.contains($0) }

        for word in words {
            freqMap[word, default: 0] += 1
        }

        // Sort and update
        wordFrequencies = freqMap
            .sorted { $0.value > $1.value }
            .map { (word: $0.key, count: $0.value) }

        saveWordFreq(freqMap)
    }

    func loadWordFrequencies() {
        let freqMap = loadWordFreqMap()
        wordFrequencies = freqMap
            .sorted { $0.value > $1.value }
            .map { (word: $0.key, count: $0.value) }
    }

    private func loadWordFreqMap() -> [String: Int] {
        guard FileManager.default.fileExists(atPath: Self.wordFreqFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: Self.wordFreqFileURL)
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveWordFreq(_ freqMap: [String: Int]) {
        do {
            let dir = Self.wordFreqFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(freqMap)
            try data.write(to: Self.wordFreqFileURL, options: .atomic)
        } catch {
            // Non-critical
        }
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
