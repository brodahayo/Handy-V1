import AVFoundation

final class SoundPlayer {
    private var player: AVAudioPlayer?
    private var cache: [String: Data] = [:]
    private let sampleRate: Double = 44100

    func play(pack: SoundPack, isStart: Bool, enabled: Bool) {
        guard enabled else { return }
        guard let wavData = getWAVData(pack: pack, isStart: isStart) else { return }

        player = try? AVAudioPlayer(data: wavData)
        player?.volume = 0.5
        player?.play()
    }

    private func getWAVData(pack: SoundPack, isStart: Bool) -> Data? {
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

    // MARK: - Woody: warm mallet-like tap with resonance

    private func generateWoody(_ data: inout [Float], isStart: Bool) {
        let fundamental: Float = isStart ? 880 : 660
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate

            // Sharp attack, smooth exponential decay
            let attack = min(1.0, t * 200.0)
            let decay = exp(-t * 18.0)
            let envelope = attack * decay

            // Fundamental + soft overtones for warmth
            let f1 = sin(2 * .pi * fundamental * t)
            let f2 = sin(2 * .pi * fundamental * 2.0 * t) * 0.3
            let f3 = sin(2 * .pi * fundamental * 3.0 * t) * 0.1

            // Subtle pitch bend down for that "knock" feel
            let bend = sin(2 * .pi * (fundamental * 1.5) * t * exp(-t * 30.0)) * exp(-t * 40.0) * 0.2

            data[i] = (f1 + f2 + f3 + bend) * envelope * 0.35
        }
    }

    // MARK: - Crystal: shimmering chime with harmonic overtones

    private func generateCrystal(_ data: inout [Float], isStart: Bool) {
        let fundamental: Float = isStart ? 2200 : 1760
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate

            let attack = min(1.0, t * 500.0)

            // Main tone with long shimmer tail
            let env1 = exp(-t * 8.0)
            let f1 = sin(2 * .pi * fundamental * t) * env1

            // Inharmonic overtones for metallic shimmer
            let env2 = exp(-t * 12.0)
            let f2 = sin(2 * .pi * fundamental * 2.37 * t) * env2 * 0.25

            let env3 = exp(-t * 6.0)
            let f3 = sin(2 * .pi * fundamental * 3.71 * t) * env3 * 0.12

            // High sparkle
            let env4 = exp(-t * 20.0)
            let f4 = sin(2 * .pi * fundamental * 5.2 * t) * env4 * 0.06

            // Subtle chorus effect via detuned copy
            let chorus = sin(2 * .pi * (fundamental * 1.003) * t) * env1 * 0.15

            data[i] = (f1 + f2 + f3 + f4 + chorus) * attack * 0.25
        }
    }

    // MARK: - Bubble: playful rising/falling pop

    private func generateBubble(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        for i in 0..<data.count {
            let t = Float(i) / rate

            // Snappy attack, moderate decay
            let attack = min(1.0, t * 300.0)
            let decay = exp(-t * 14.0)
            let envelope = attack * decay

            // Frequency sweep: rising for start, falling for stop
            let baseFreq: Float = isStart ? 350 : 650
            let sweep: Float = isStart ? 1200 : -800
            let freq = baseFreq + sweep * t * exp(-t * 8.0)

            let main = sin(2 * .pi * freq * t)

            // Soft sub-harmonic for roundness
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.3

            // Airy noise burst at the start
            let noiseBurst = Float.random(in: -1...1) * exp(-t * 60.0) * 0.1

            data[i] = (main + sub + noiseBurst) * envelope * 0.35
        }
    }

    // MARK: - Chirp: quick two-tone notification

    private func generateChirp(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        let totalDuration = Float(data.count) / rate

        for i in 0..<data.count {
            let t = Float(i) / rate
            let progress = t / totalDuration

            // Two-tone: pitch rises for start, falls for stop
            let freq1: Float = isStart ? 1100 : 1500
            let freq2: Float = isStart ? 1500 : 1100
            let freq = freq1 + (freq2 - freq1) * progress

            // Smooth envelope with quick attack
            let attack = min(1.0, t * 400.0)
            let sustain: Float = progress < 0.7 ? 1.0 : (1.0 - (progress - 0.7) / 0.3)
            let envelope = attack * sustain

            let main = sin(2 * .pi * freq * t)
            let harmonic = sin(2 * .pi * freq * 2.0 * t) * 0.2

            // Soft triangle wave character
            let triangle = asin(sin(2 * .pi * freq * 0.5 * t)) / (.pi / 2) * 0.1

            data[i] = (main + harmonic + triangle) * envelope * 0.3
        }
    }

    // MARK: - Synth: polished chord with pad-like release

    private func generateSynth(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)

        // Major chord: root, major third, fifth
        let root: Float = isStart ? 523.25 : 659.25 // C5 / E5
        let third: Float = isStart ? 659.25 : 523.25 // E5 / C5
        let fifth: Float = isStart ? 783.99 : 783.99 // G5

        for i in 0..<data.count {
            let t = Float(i) / rate

            // Smooth attack with long pad-like release
            let attack = 1.0 - exp(-t * 40.0)
            let release = exp(-t * 5.0)
            let envelope = attack * release

            // Each voice with slightly different timbre
            let v1 = sin(2 * .pi * root * t) + sin(2 * .pi * root * 2.0 * t) * 0.15
            let v2 = sin(2 * .pi * third * t) * 0.7
            let v3 = sin(2 * .pi * fifth * t) * 0.5

            // Detuned copies for chorus/width
            let detune1 = sin(2 * .pi * (root * 1.004) * t) * 0.2
            let detune2 = sin(2 * .pi * (third * 0.997) * t) * 0.15

            let mix = (v1 + v2 + v3 + detune1 + detune2) / 3.0

            data[i] = mix * envelope * 0.25
        }
    }

    // MARK: - Bloom: soft plucky harp note, warm and gentle

    private func generateBloom(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        // Gentle pentatonic notes — A4 start, E4 stop
        let freq: Float = isStart ? 440.0 : 329.63

        for i in 0..<data.count {
            let t = Float(i) / rate

            // Soft attack (no click), smooth exponential decay
            let attack = 1.0 - exp(-t * 80.0)
            let decay = exp(-t * 10.0)
            let envelope = attack * decay

            // Pure fundamental with a warm second harmonic
            let f1 = sin(2 * .pi * freq * t)
            let f2 = sin(2 * .pi * freq * 2.0 * t) * 0.2

            // Subtle fifth harmonic shimmer that decays faster
            let f3 = sin(2 * .pi * freq * 3.0 * t) * exp(-t * 20.0) * 0.08

            // Gentle detuned copy for a dreamy width
            let chorus = sin(2 * .pi * (freq * 1.002) * t) * 0.12

            data[i] = (f1 + f2 + f3 + chorus) * envelope * 0.3
        }
    }

    // MARK: - Droplet: tiny water-drop plop, cute and minimal

    private func generateDroplet(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)

        for i in 0..<data.count {
            let t = Float(i) / rate

            // Very fast attack for that "plop" transient
            let attack = min(1.0, t * 600.0)
            let decay = exp(-t * 22.0)
            let envelope = attack * decay

            // Downward pitch sweep — starts high, drops quickly (water drop)
            let startFreq: Float = isStart ? 1800 : 1400
            let endFreq: Float = isStart ? 600 : 500
            let freq = endFreq + (startFreq - endFreq) * exp(-t * 35.0)

            let main = sin(2 * .pi * freq * t)

            // Soft sub for body
            let sub = sin(2 * .pi * freq * 0.5 * t) * 0.15 * exp(-t * 18.0)

            // Tiny noise splash at the very start
            let splash = Float.random(in: -1...1) * exp(-t * 100.0) * 0.06

            data[i] = (main + sub + splash) * envelope * 0.3
        }
    }

    // MARK: - Petal: airy, delicate bell with soft overtones

    private func generatePetal(_ data: inout [Float], isStart: Bool) {
        let rate = Float(sampleRate)
        // High delicate notes — D6 start, A5 stop
        let freq: Float = isStart ? 1174.66 : 880.0

        for i in 0..<data.count {
            let t = Float(i) / rate

            // Very gentle attack, long airy decay
            let attack = 1.0 - exp(-t * 60.0)
            let decay = exp(-t * 6.0)
            let envelope = attack * decay

            // Pure sine fundamental — bell-like
            let f1 = sin(2 * .pi * freq * t)

            // Inharmonic partials for that bell/celeste character
            let f2 = sin(2 * .pi * freq * 2.76 * t) * exp(-t * 10.0) * 0.15
            let f3 = sin(2 * .pi * freq * 4.07 * t) * exp(-t * 16.0) * 0.06

            // Breathy layer — filtered noise mixed very quietly
            let breath = sin(2 * .pi * freq * 0.998 * t) * exp(-t * 8.0) * 0.1

            data[i] = (f1 + f2 + f3 + breath) * envelope * 0.22
        }
    }
}
