import AVFoundation

final class SoundPlayer {
    private var player: AVAudioPlayer?
    private var cache: [String: Data] = [:]
    private let sampleRate: Double = 44100
    private let generateQueue = DispatchQueue(label: "com.handy.soundgen", qos: .userInitiated)

    /// Pre-generate all sounds for a pack on a background thread
    func preload(pack: SoundPack) {
        generateQueue.async { [self] in
            for isStart in [true, false] {
                _ = generateWAVData(pack: pack, isStart: isStart)
            }
        }
    }

    func play(pack: SoundPack, isStart: Bool, enabled: Bool) {
        guard enabled else { return }

        let key = "\(pack.rawValue)-\(isStart ? "start" : "stop")"
        if let cached = cache[key] {
            playData(cached)
            return
        }

        // Generate on background thread, then play
        generateQueue.async { [self] in
            guard let wavData = generateWAVData(pack: pack, isStart: isStart) else { return }
            DispatchQueue.main.async { [self] in
                playData(wavData)
            }
        }
    }

    private func playData(_ data: Data) {
        player = try? AVAudioPlayer(data: data)
        player?.volume = 0.5
        player?.play()
    }

    private func generateWAVData(pack: SoundPack, isStart: Bool) -> Data? {
        let key = "\(pack.rawValue)-\(isStart ? "start" : "stop")"
        if let cached = cache[key] { return cached }

        let duration: Double
        switch pack {
        case .woody: duration = isStart ? 0.18 : 0.14
        case .crystal: duration = isStart ? 0.25 : 0.20
        case .bubble: duration = isStart ? 0.20 : 0.16
        case .chirp: duration = isStart ? 0.15 : 0.12
        case .synth: duration = isStart ? 0.30 : 0.25
        case .bloom: duration = isStart ? 0.22 : 0.18
        case .droplet: duration = isStart ? 0.16 : 0.13
        case .petal: duration = isStart ? 0.28 : 0.22
        }

        let frameCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: frameCount)

        switch pack {
        case .woody: generateWoody(&samples, isStart: isStart)
        case .crystal: generateCrystal(&samples, isStart: isStart)
        case .bubble: generateBubble(&samples, isStart: isStart)
        case .chirp: generateChirp(&samples, isStart: isStart)
        case .synth: generateSynth(&samples, isStart: isStart)
        case .bloom: generateBloom(&samples, isStart: isStart)
        case .droplet: generateDroplet(&samples, isStart: isStart)
        case .petal: generatePetal(&samples, isStart: isStart)
        }

        // Convert float samples to Int16 PCM
        var pcmData = Data(count: frameCount * 2)
        pcmData.withUnsafeMutableBytes { raw in
            let ptr = raw.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                ptr[i] = Int16(max(-1, min(1, samples[i])) * Float(Int16.max))
            }
        }

        let wavData = AudioRecorder.createWAVData(
            from: pcmData,
            sampleRate: UInt32(sampleRate),
            channels: 1
        )

        cache[key] = wavData
        return wavData
    }

    // MARK: - Woody: warm low marimba tap

    private func generateWoody(_ data: inout [Float], isStart: Bool) {
        let fundamental: Float = isStart ? 330 : 262 // E4 / C4
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = min(1.0, t * 150.0)
            let decay = exp(-t * 12.0)
            let envelope = attack * decay

            let f1 = sin(2 * .pi * fundamental * t)
            let f2 = sin(2 * .pi * fundamental * 2.0 * t) * 0.15 * exp(-t * 16.0)
            let sub = sin(2 * .pi * fundamental * 0.5 * t) * 0.2

            data[i] = (f1 + f2 + sub) * envelope * 0.4
        }
    }

    // MARK: - Crystal: soft glass bell

    private func generateCrystal(_ data: inout [Float], isStart: Bool) {
        let fundamental: Float = isStart ? 523 : 392 // C5 / G4
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = 1.0 - exp(-t * 100.0)
            let decay = exp(-t * 6.0)
            let envelope = attack * decay

            let f1 = sin(2 * .pi * fundamental * t)
            let f2 = sin(2 * .pi * fundamental * 2.0 * t) * 0.1 * exp(-t * 10.0)
            let chorus = sin(2 * .pi * (fundamental * 1.003) * t) * 0.12

            data[i] = (f1 + f2 + chorus) * envelope * 0.3
        }
    }

    // MARK: - Bubble: gentle rising/falling tone

    private func generateBubble(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = min(1.0, t * 200.0)
            let decay = exp(-t * 10.0)
            let envelope = attack * decay

            let baseFreq: Float = isStart ? 220 : 350
            let sweep: Float = isStart ? 300 : -200
            let freq = baseFreq + sweep * t * exp(-t * 6.0)

            let main = sin(2 * .pi * freq * t)
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.25

            data[i] = (main + sub) * envelope * 0.35
        }
    }

    // MARK: - Chirp: two-note soft notification

    private func generateChirp(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        let totalDuration = Float(data.count) / rate
        for i in 0..<data.count {
            let t = Float(i) / rate
            let progress = t / totalDuration

            let freq1: Float = isStart ? 392 : 440 // G4 / A4
            let freq2: Float = isStart ? 523 : 330 // C5 / E4
            let freq = freq1 + (freq2 - freq1) * progress

            let attack = min(1.0, t * 200.0)
            let sustain: Float = progress < 0.6 ? 1.0 : (1.0 - (progress - 0.6) / 0.4)
            let envelope = attack * sustain

            let main = sin(2 * .pi * freq * t)
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.15

            data[i] = (main + sub) * envelope * 0.3
        }
    }

    // MARK: - Synth: warm two-note chord

    private func generateSynth(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        let root: Float = isStart ? 262 : 330 // C4 / E4
        let fifth: Float = isStart ? 392 : 392 // G4

        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = 1.0 - exp(-t * 30.0)
            let release = exp(-t * 4.0)
            let envelope = attack * release

            let v1 = sin(2 * .pi * root * t)
            let v2 = sin(2 * .pi * fifth * t) * 0.5
            let sub = sin(2 * .pi * root * 0.5 * t) * 0.15
            let detune = sin(2 * .pi * (root * 1.003) * t) * 0.1

            data[i] = (v1 + v2 + sub + detune) / 2.0 * envelope * 0.3
        }
    }

    // MARK: - Bloom: warm pluck with body

    private func generateBloom(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        let freq: Float = isStart ? 294 : 247 // D4 / B3

        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = 1.0 - exp(-t * 60.0)
            let decay = exp(-t * 8.0)
            let envelope = attack * decay

            let f1 = sin(2 * .pi * freq * t)
            let f2 = sin(2 * .pi * freq * 2.0 * t) * 0.12 * exp(-t * 14.0)
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.2
            let chorus = sin(2 * .pi * (freq * 1.002) * t) * 0.08

            data[i] = (f1 + f2 + sub + chorus) * envelope * 0.35
        }
    }

    // MARK: - Droplet: soft low pop

    private func generateDroplet(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = min(1.0, t * 400.0)
            let decay = exp(-t * 16.0)
            let envelope = attack * decay

            let startFreq: Float = isStart ? 500 : 420
            let endFreq: Float = isStart ? 220 : 180
            let freq = endFreq + (startFreq - endFreq) * exp(-t * 25.0)

            let main = sin(2 * .pi * freq * t)
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.2

            data[i] = (main + sub) * envelope * 0.35
        }
    }

    // MARK: - Petal: gentle low bell

    private func generatePetal(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        let freq: Float = isStart ? 392 : 330 // G4 / E4

        for i in 0..<data.count {
            let t = Float(i) / rate
            let attack = 1.0 - exp(-t * 50.0)
            let decay = exp(-t * 5.0)
            let envelope = attack * decay

            let f1 = sin(2 * .pi * freq * t)
            let f2 = sin(2 * .pi * freq * 2.0 * t) * 0.08 * exp(-t * 8.0)
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.15
            let chorus = sin(2 * .pi * (freq * 0.998) * t) * 0.08

            data[i] = (f1 + f2 + sub + chorus) * envelope * 0.28
        }
    }
}
