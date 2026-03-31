import Foundation

enum CloudProvider: String, Codable, CaseIterable, Identifiable {
    case groq
    case openai
    case deepgram

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: "Groq"
        case .openai: "OpenAI"
        case .deepgram: "Deepgram"
        }
    }

    var apiKeyPrefix: String? {
        switch self {
        case .groq: "gsk_"
        case .openai: "sk-"
        case .deepgram: nil
        }
    }

    var apiKeyURL: URL {
        switch self {
        case .groq: URL(string: "https://console.groq.com/keys")!
        case .openai: URL(string: "https://platform.openai.com/api-keys")!
        case .deepgram: URL(string: "https://console.deepgram.com/")!
        }
    }

    var whisperModel: String? {
        switch self {
        case .groq: "whisper-large-v3"
        case .openai: "whisper-1"
        case .deepgram: nil
        }
    }

    var chatModel: String? {
        switch self {
        case .groq: "llama-3.3-70b-versatile"
        case .openai: "gpt-4o-mini"
        case .deepgram: nil
        }
    }

    var transcriptionEndpoint: URL {
        switch self {
        case .groq: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        case .openai: URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        case .deepgram: URL(string: "https://api.deepgram.com/v1/listen")!
        }
    }

    var chatEndpoint: URL? {
        switch self {
        case .groq: URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        case .openai: URL(string: "https://api.openai.com/v1/chat/completions")!
        case .deepgram: nil
        }
    }
}
