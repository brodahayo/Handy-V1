import Foundation

final class CloudTranscriber: Sendable {

    private let maxRetries = 3
    private let initialBackoff: UInt64 = 500_000_000 // 0.5 seconds in nanoseconds

    func transcribe(wavData: Data, provider: CloudProvider, apiKey: String, language: String) async throws -> String {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                switch provider {
                case .groq, .openai:
                    return try await transcribeOpenAICompat(wavData: wavData, provider: provider, apiKey: apiKey, language: language)
                case .deepgram:
                    return try await transcribeDeepgram(wavData: wavData, apiKey: apiKey, language: language)
                }
            } catch {
                lastError = error
                // Only retry on transient errors (5xx, timeouts, network errors)
                guard isRetryable(error) && attempt < maxRetries - 1 else { throw error }
                let backoff = initialBackoff * UInt64(1 << attempt)
                try await Task.sleep(nanoseconds: backoff)
            }
        }
        throw lastError ?? TranscriptionError.emptyTranscription
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let transcriptionError = error as? TranscriptionError {
            switch transcriptionError {
            case .apiError(let statusCode, _):
                return statusCode >= 500 || statusCode == 429
            default:
                return false
            }
        }
        // Retry on network errors (URLError)
        return (error as? URLError) != nil
    }

    private func transcribeOpenAICompat(wavData: Data, provider: CloudProvider, apiKey: String, language: String) async throws -> String {
        guard let model = provider.whisperModel else {
            throw TranscriptionError.unsupportedProvider
        }

        let boundary = UUID().uuidString
        let body = buildMultipartBody(wavData: wavData, model: model, language: language, boundary: boundary)

        var request = URLRequest(url: provider.transcriptionEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            // Only include a truncated message to avoid leaking sensitive API response details
            let body = String(data: data.prefix(200), encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.apiError(statusCode: statusCode, message: body)
        }

        let json = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return json.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transcribeDeepgram(wavData: Data, apiKey: String, language: String) async throws -> String {
        let url = buildDeepgramURL(language: language)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = wavData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data.prefix(200), encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.apiError(statusCode: statusCode, message: body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [String: Any]
        let channels = results?["channels"] as? [[String: Any]]
        let alternatives = channels?.first?["alternatives"] as? [[String: Any]]
        let transcript = alternatives?.first?["transcript"] as? String

        guard let text = transcript, !text.isEmpty else {
            throw TranscriptionError.emptyTranscription
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func buildMultipartBody(wavData: Data, model: String, language: String, boundary: String) -> Data {
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        if language != "auto" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    func buildDeepgramURL(language: String) -> URL {
        var components = URLComponents(url: CloudProvider.deepgram.transcriptionEndpoint, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "model", value: "nova-2")]

        if language == "auto" {
            queryItems.append(URLQueryItem(name: "detect_language", value: "true"))
        } else {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }

        components.queryItems = queryItems
        return components.url!
    }
}

struct WhisperResponse: Decodable {
    let text: String
}

enum TranscriptionError: Error {
    case unsupportedProvider
    case apiError(statusCode: Int, message: String)
    case emptyTranscription
}
