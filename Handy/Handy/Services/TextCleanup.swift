import Foundation

final class TextCleanup: Sendable {

    func cleanup(text: String, style: CleanupStyle, provider: CloudProvider, apiKey: String) async throws -> String {
        // Skip LLM call if there's nothing to clean up
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        let chatProvider: CloudProvider
        let chatKey: String

        if provider.chatEndpoint != nil {
            chatProvider = provider
            chatKey = apiKey
        } else {
            throw CleanupError.noChatSupport
        }

        guard let endpoint = chatProvider.chatEndpoint else {
            throw CleanupError.noChatSupport
        }

        let body = try buildChatRequestBody(text: text, style: style, provider: chatProvider)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(chatKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw CleanupError.apiError(statusCode: statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        guard let result = content?.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty else {
            return text
        }

        // Safety: if the LLM returned meta-commentary instead of cleaned text,
        // fall back to the original. A cleaned-up version shouldn't be drastically
        // longer than the input unless the input was very short.
        let inputWords = text.split(separator: " ").count
        let outputWords = result.split(separator: " ").count
        if inputWords > 0 && outputWords > inputWords * 3 + 10 {
            print("[Handy] Cleanup returned suspiciously long response (\(outputWords) vs \(inputWords) words), using raw text")
            return text
        }

        return result
    }

    func buildChatRequestBody(text: String, style: CleanupStyle, provider: CloudProvider) throws -> Data {
        guard let model = provider.chatModel else {
            throw CleanupError.noChatSupport
        }

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "max_tokens": 2048,
            "messages": [
                ["role": "system", "content": style.prompt],
                ["role": "user", "content": "<transcription>\(text)</transcription>"],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}

enum CleanupError: Error {
    case noChatSupport
    case apiError(statusCode: Int)
}
