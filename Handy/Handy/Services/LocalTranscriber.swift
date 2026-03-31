import Foundation

// Note: Requires WhisperKit package dependency
// import WhisperKit

final class LocalTranscriber {
    // private var whisperKit: WhisperKit?
    private var loadedModel: String?

    func transcribe(wavData: Data, modelSize: String) async throws -> String {
        // TODO: Implement with WhisperKit once package is added
        // let model = "openai_whisper-\(modelSize)"
        // if whisperKit == nil || loadedModel != model {
        //     whisperKit = try await WhisperKit(model: model)
        //     loadedModel = model
        // }
        // let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        // try wavData.write(to: tempURL)
        // defer { try? FileManager.default.removeItem(at: tempURL) }
        // let results = try await whisperKit!.transcribe(audioPath: tempURL.path)
        // return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        throw LocalTranscriberError.modelNotLoaded
    }

    static func isModelDownloaded(_ modelSize: String) -> Bool {
        let model = "openai_whisper-\(modelSize)"
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/\(model)")
        return FileManager.default.fileExists(atPath: cacheDir.path)
    }
}

enum LocalTranscriberError: Error {
    case modelNotLoaded
    case emptyResult
}
