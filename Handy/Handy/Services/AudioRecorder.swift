import AVFoundation
import Observation

@Observable
final class AudioRecorder: @unchecked Sendable {
    private(set) var isRecording = false
    private(set) var currentLevel: Float = 0.0

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()

        self.recorder = audioRecorder
        self.recordingURL = url
        isRecording = true

        // Poll meter levels on main thread
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let rec = self.recorder, rec.isRecording else { return }
            rec.updateMeters()
            let db = rec.averagePower(forChannel: 0) // -160 to 0
            let normalized = max(0, (db + 50) / 50) // map -50..0 → 0..1
            self.currentLevel = normalized
        }
    }

    func stop() -> Data? {
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        currentLevel = 0.0

        guard let url = recordingURL else { return nil }
        recordingURL = nil

        defer { try? FileManager.default.removeItem(at: url) }
        return try? Data(contentsOf: url)
    }

    // Keep for tests
    static func createWAVData(from pcmData: Data, sampleRate: UInt32, channels: UInt16) -> Data {
        var data = Data()
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize

        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(pcmData)

        return data
    }
}

enum AudioRecorderError: Error {
    case formatError
    case converterError
}
