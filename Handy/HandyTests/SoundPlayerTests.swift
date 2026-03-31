import XCTest
@testable import Handy

final class SoundPlayerTests: XCTestCase {
    func testPlayDoesNotCrash() {
        let player = SoundPlayer()
        // Just verify play doesn't throw/crash for all packs
        for pack in SoundPack.allCases {
            player.play(pack: pack, isStart: true, enabled: true)
            player.play(pack: pack, isStart: false, enabled: true)
        }
    }

    func testPlayDisabled() {
        let player = SoundPlayer()
        // Should do nothing when disabled
        player.play(pack: .woody, isStart: true, enabled: false)
    }
}
