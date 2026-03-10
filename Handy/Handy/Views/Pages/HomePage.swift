import SwiftUI

struct HomePage: View {
    @Bindable var appState: AppState
    let onToggle: () -> Void

    @State private var greeting = "Hello"
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Greeting
                Text("\(greeting), there!")
                    .font(.largeTitle.bold())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                // Word Progress
                WordProgressView(todayWords: appState.todayWords, dailyGoal: $appState.settings.dailyGoal)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                // Stats
                GroupBox {
                    HStack(spacing: 0) {
                        StatItem(value: "\(appState.totalWords)", label: "Total Words", icon: "text.word.spacing")
                        Divider().frame(height: 30)
                        StatItem(value: appState.formattedTimeSaved, label: "Time Saved", icon: "clock.arrow.circlepath")
                        Divider().frame(height: 30)
                        StatItem(value: "\(appState.currentStreak)", label: "Day Streak", icon: appState.currentStreak > 0 ? "flame.fill" : "flame")
                    }
                    .padding(.vertical, 8)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                // Dictation
                RecordingCard(appState: appState, onToggle: onToggle)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                // Processing indicator
                if appState.isProcessing {
                    ProcessingBanner()
                }

                // Error message
                if let error = appState.errorMessage {
                    ErrorBanner(message: error) {
                        appState.errorMessage = nil
                    }
                }

                // History
                HistorySection(appState: appState)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            let hour = Calendar.current.component(.hour, from: Date())
            if hour < 12 { greeting = "Good morning" }
            else if hour < 17 { greeting = "Good afternoon" }
            else { greeting = "Good evening" }

            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let appState: AppState
    let onToggle: () -> Void

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                RecordButton(isRecording: appState.isRecording, action: onToggle)

                Text(appState.isRecording ? "Recording..." : "Hold **Fn** to dictate anywhere")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: appState.isRecording)

                if appState.isRecording {
                    AudioLevelBars(level: appState.audioLevel)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .animation(.spring(duration: 0.35, bounce: 0.2), value: appState.isRecording)
        }
    }
}

// MARK: - Record Button with Pulse

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing rings when recording
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))

                    Circle()
                        .stroke(Color.red.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseScale * 0.85 + 0.15)
                        .opacity(2.0 - Double(pulseScale))
                }

                // Main button circle
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: (isRecording ? Color.red : Color.accentColor).opacity(0.3), radius: 8, y: 2)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .onAppear {
            if isRecording { startPulse() }
        }
        .onChange(of: isRecording) {
            if isRecording { startPulse() } else { pulseScale = 1.0 }
        }
    }

    private func startPulse() {
        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
            pulseScale = 1.8
        }
    }
}

// MARK: - Processing Banner

struct ProcessingBanner: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Transcribing...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.accentColor.opacity(0.08), .clear],
                                startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                                endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 0.5)
                            )
                        )
                }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { onDismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Word Progress

struct WordProgressView: View {
    let todayWords: Int
    @Binding var dailyGoal: Int
    @State private var isEditingGoal = false
    @State private var goalText = ""
    @State private var animatedProgress: Double = 0

    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayWords) / Double(dailyGoal), 1.0)
    }

    var goalReached: Bool {
        dailyGoal > 0 && todayWords >= dailyGoal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Today: \(todayWords) /")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: todayWords)

                if isEditingGoal {
                    TextField("Goal", text: $goalText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .font(.subheadline)
                        .onSubmit {
                            if let value = Int(goalText), value > 0 {
                                dailyGoal = value
                            }
                            isEditingGoal = false
                        }
                } else {
                    Text("\(dailyGoal)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            goalText = "\(dailyGoal)"
                            isEditingGoal = true
                        }
                        .underline()
                        .help("Click to edit daily goal")
                }

                Text("words")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Animated gradient progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: goalReached
                                    ? [.green, .green.opacity(0.8)]
                                    : [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * animatedProgress), height: 6)
                }
            }
            .frame(height: 6)
            .animation(.spring(duration: 0.6, bounce: 0.15), value: goalReached)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) {
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String
    var icon: String = ""

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 4) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Audio Level Bars

struct AudioLevelBars: View {
    let level: Float
    let barCount = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: 24)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let center = Float(barCount) / 2.0
        let distance = abs(Float(index) - center) / center
        let scale = max(0.15, CGFloat(level) * CGFloat(1.0 - distance * 0.5))
        return 24 * scale
    }
}

// MARK: - History Section

struct HistorySection: View {
    let appState: AppState
    @State private var showClearConfirmation = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if appState.lastTranscription != nil {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .confirmationDialog(
                        "Clear History",
                        isPresented: $showClearConfirmation
                    ) {
                        Button("Clear All History", role: .destructive) {
                            withAnimation(.spring(duration: 0.3)) {
                                appState.clearHistory()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will clear all transcription history and reset your stats. This action cannot be undone.")
                    }
                }
            }

            if let text = appState.lastTranscription {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text)
                            .font(.body)
                            .lineLimit(3)
                        HStack(spacing: 8) {
                            Text("\(text.split(separator: " ").count) words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                                withAnimation(.spring(duration: 0.3)) {
                                    copied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { copied = false }
                                }
                            } label: {
                                Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .foregroundStyle(copied ? .green : .accentColor)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                ContentUnavailableView(
                    "No Transcriptions Yet",
                    systemImage: "mic.slash",
                    description: Text("Start dictating to see your history here.")
                )
            }
        }
        .animation(.spring(duration: 0.3), value: appState.lastTranscription == nil)
    }
}
