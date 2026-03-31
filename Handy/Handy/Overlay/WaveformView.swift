import SwiftUI

struct WaveformView: View {
    let level: Float
    let barCount: Int
    let style: OverlayStyle

    @State private var phase: Double = 0

    private var maxBarHeight: CGFloat {
        style == .mini ? 18 : 28
    }

    private var barWidth: CGFloat {
        style == .mini ? 3 : 3.5
    }

    var body: some View {
        HStack(spacing: style == .mini ? 6 : 8) {
            // Mic icon with glow
            ZStack {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .font(style == .mini ? .caption : .callout)
                    .blur(radius: level > 0.1 ? 4 : 0)
                    .opacity(level > 0.1 ? 0.5 : 0)

                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .font(style == .mini ? .caption : .callout)
            }

            // Waveform bars
            HStack(spacing: style == .mini ? 2.5 : 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveBar(
                        height: barHeightFor(index: index),
                        maxHeight: maxBarHeight,
                        width: barWidth,
                        color: barColor(for: index)
                    )
                }
            }

            // Stop button
            Button(action: {
                NotificationCenter.default.post(name: .stopRecording, object: nil)
            }) {
                Image(systemName: "stop.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 16, height: 16)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, style == .mini ? 12 : 16)
        .padding(.vertical, style == .mini ? 8 : 10)
        .background {
            ZStack {
                // Base dark capsule
                Capsule()
                    .fill(Color(white: 0.06, opacity: 0.92))

                // Subtle gradient border
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.12),
                                .white.opacity(0.04),
                                .white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )

                // Reactive glow behind bars when loud
                Capsule()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(Double(level) * 0.15),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private func barHeightFor(index: Int) -> CGFloat {
        let center = Float(barCount) / 2.0
        let normalizedIndex = Float(index) - center

        // Wave shape: taller in the middle, shorter on edges
        let bellCurve = exp(-normalizedIndex * normalizedIndex / (center * center * 0.8))

        // Organic wave motion using phase + index offset
        let wave = sin(phase + Double(index) * 0.7) * 0.15 + 0.85

        // Combine: base idle height + audio level scaling + organic motion
        let idle: CGFloat = 0.2
        let audioContribution = CGFloat(level) * CGFloat(bellCurve) * CGFloat(wave)
        let height = (idle + audioContribution) * maxBarHeight

        return max(3, min(maxBarHeight, height))
    }

    private func barColor(for index: Int) -> Color {
        let center = Double(barCount) / 2.0
        let t = abs(Double(index) - center) / center
        // Center bars are brighter, edge bars dimmer
        return .white.opacity(0.5 + (1.0 - t) * 0.4)
    }
}

// MARK: - Individual Wave Bar

struct WaveBar: View {
    let height: CGFloat
    let maxHeight: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: height)
    }
}

// MARK: - Fluid Wave Visualizer

struct FluidWaveVisualizer: View {
    let level: Float
    var compact: Bool = false

    @State private var phase: Double = 0

    private var height: CGFloat { compact ? 60 : 120 }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width
                let h = size.height
                let baseY = h * 0.6
                let amplitude = CGFloat(level) * h * 0.35

                // Draw 3 wave layers back to front
                for layer in (0..<3).reversed() {
                    let layerF = CGFloat(layer)
                    let opacity = (0.12 + CGFloat(level) * 0.12) * (1.0 - layerF * 0.25)
                    let speed = 1.0 + Double(layer) * 0.3
                    let freq1 = 0.015 - Double(layer) * 0.002
                    let freq2 = 0.008 + Double(layer) * 0.001
                    let amp = amplitude * (1.0 - layerF * 0.2)

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: h))

                    for x in stride(from: 0, through: w, by: 2) {
                        let y = baseY
                            + sin(Double(x) * freq1 + time * speed + Double(layer) * 0.8) * Double(amp)
                            + sin(Double(x) * freq2 + time * speed * 0.7 + Double(layer)) * Double(amp) * 0.5
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()

                    // Gradient fill
                    let colors: [Color] = layer == 0
                        ? [Color(red: 0.04, green: 0.52, blue: 1.0).opacity(opacity),
                           Color(red: 0.35, green: 0.78, blue: 0.98).opacity(opacity * 0.6),
                           .clear]
                        : layer == 1
                        ? [Color(red: 0.55, green: 0.36, blue: 0.96).opacity(opacity),
                           Color(red: 0.04, green: 0.52, blue: 1.0).opacity(opacity * 0.5),
                           .clear]
                        : [Color(red: 0.08, green: 0.72, blue: 0.65).opacity(opacity),
                           Color(red: 0.35, green: 0.78, blue: 0.98).opacity(opacity * 0.4),
                           .clear]

                    context.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: colors),
                            startPoint: CGPoint(x: w / 2, y: baseY - Double(amp)),
                            endPoint: CGPoint(x: w / 2, y: h)
                        )
                    )
                }
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Processing Wave Visualizer

struct ProcessingVisualizer: View {
    var compact: Bool = false

    private var height: CGFloat { compact ? 40 : 80 }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                drawProcessingWaves(context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }

    private func drawProcessingWaves(context: GraphicsContext, size: CGSize, time: Double) {
        let w = size.width
        let h = size.height
        let baseY = h * 0.5
        let amp = 8.0 + sin(time * 0.5) * 4.0

        for layer in (0..<2).reversed() {
            let opacity = 0.08 - CGFloat(layer) * 0.02

            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))

            for x in stride(from: CGFloat(0), through: w, by: 2) {
                let wave1 = sin(Double(x) * 0.02 + time * 0.8 + Double(layer) * 1.5) * amp
                let wave2 = sin(Double(x) * 0.01 + time * 0.4) * amp * 0.5
                let y = baseY + wave1 + wave2
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()

            let blue = Color(red: 0.04, green: 0.52, blue: 1.0).opacity(opacity)
            let purple = Color(red: 0.55, green: 0.36, blue: 0.96).opacity(opacity)
            let color = layer == 0 ? blue : purple

            let gradient = Gradient(colors: [color, .clear])
            let startPt = CGPoint(x: w / 2, y: baseY - amp)
            let endPt = CGPoint(x: w / 2, y: h)

            context.fill(path, with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt))
        }
    }
}

extension Notification.Name {
    static let stopRecording = Notification.Name("stopRecording")
}
