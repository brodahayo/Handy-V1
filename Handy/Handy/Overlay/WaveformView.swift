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

extension Notification.Name {
    static let stopRecording = Notification.Name("stopRecording")
}
