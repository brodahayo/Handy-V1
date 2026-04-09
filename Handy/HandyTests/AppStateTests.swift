import XCTest
@testable import Handy

final class AppStateTests: XCTestCase {
    func testInitialState() {
        let state = AppState()
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertEqual(state.audioLevel, 0.0)
        XCTAssertNil(state.lastTranscription)
        XCTAssertNil(state.errorMessage)
    }

    func testSettingsDefaultsLoaded() {
        let state = AppState()
        XCTAssertEqual(state.settings.holdModifierFlags, 8388608) // .function
        XCTAssertEqual(state.settings.toggleModifierFlags, 524288) // .option
        XCTAssertEqual(state.settings.cloudProvider, .groq)
    }
}
