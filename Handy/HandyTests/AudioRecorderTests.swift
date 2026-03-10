import XCTest
@testable import Handy

final class AudioRecorderTests: XCTestCase {
    func testInitialState() {
        let recorder = AudioRecorder()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.currentLevel, 0.0)
    }

    func testWAVHeaderCreation() throws {
        let sampleCount = 16000
        var samples = [Int16](repeating: 0, count: sampleCount)
        let pcmData = Data(bytes: &samples, count: sampleCount * 2)

        let wavData = AudioRecorder.createWAVData(from: pcmData, sampleRate: 16000, channels: 1)

        XCTAssertEqual(wavData.count, 44 + pcmData.count)

        let riff = String(data: wavData[0..<4], encoding: .ascii)
        XCTAssertEqual(riff, "RIFF")

        let wave = String(data: wavData[8..<12], encoding: .ascii)
        XCTAssertEqual(wave, "WAVE")
    }
}
