import Foundation

struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let rawText: String
    let wordCount: Int
    let timestamp: Date
    let date: String

    init(text: String, rawText: String, wordCount: Int) {
        self.id = UUID()
        self.text = text
        self.rawText = rawText
        self.wordCount = wordCount
        self.timestamp = Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.date = formatter.string(from: self.timestamp)
    }
}
