import SwiftUI

struct HomePage: View {
    @Bindable var appState: AppState
    let onToggle: () -> Void

    @State private var greeting = "Hello"
    @State private var appeared = false
    @State private var isEditingGoal = false
    @State private var goalText = ""

    private var displayName: String {
        if let name = appState.userName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name.components(separatedBy: " ").first ?? name
        }
        return "there"
    }

    private var wordsRemaining: Int {
        max(0, appState.settings.dailyGoal - appState.todayWords)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero header — sentence style
                VStack(spacing: 0) {
                    // "You've spoken X words today"
                    VStack(spacing: 4) {
                        Text("You've spoken")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.tertiary)

                        Text("\(appState.todayWords)")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.4), value: appState.todayWords)

                        Text("words today")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    // Progress bar
                    HeroProgressBar(
                        todayWords: appState.todayWords,
                        dailyGoal: appState.settings.dailyGoal
                    )
                    .frame(maxWidth: .infinity)
                    .frame(width: 260)

                    // Goal subtitle with edit
                    HStack(spacing: 4) {
                        Text("\(wordsRemaining) to reach your goal of \(appState.settings.dailyGoal)")
                            .font(.caption)
                            .foregroundStyle(.quaternary)

                        if !isEditingGoal {
                            Button("edit") {
                                goalText = "\(appState.settings.dailyGoal)"
                                withAnimation(.spring(duration: 0.25)) {
                                    isEditingGoal = true
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.quaternary.opacity(0.6))
                        }
                    }
                    .padding(.top, 6)

                    // Expandable goal editor
                    if isEditingGoal {
                        HStack(spacing: 8) {
                            Text("Goal:")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            TextField("500", text: $goalText)
                                .textFieldStyle(.plain)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(width: 60)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                                .multilineTextAlignment(.center)
                                .onSubmit { saveGoal() }

                            Button("Save") { saveGoal() }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button("Cancel") {
                                withAnimation(.spring(duration: 0.25)) {
                                    isEditingGoal = false
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Stats row
                    HStack(spacing: 32) {
                        StatItem(value: "\(appState.totalWords)", label: "Total")
                        StatItem(value: appState.formattedTimeSaved, label: "Saved")
                        StatItem(value: "\(appState.currentStreak)", label: "Streak")
                    }
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                // Inline recording strip
                RecordingStrip(appState: appState, onToggle: onToggle)
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

                // Divider + History (no header)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.quaternary.opacity(0.3))
                        .frame(height: 1)

                    HistorySection(appState: appState)
                        .padding(.top, 16)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
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

    private func saveGoal() {
        if let value = Int(goalText), value > 0 {
            appState.settings.dailyGoal = value
        }
        withAnimation(.spring(duration: 0.25)) {
            isEditingGoal = false
        }
    }
}

// MARK: - Recording Strip (Inline Pill)

struct RecordingStrip: View {
    let appState: AppState
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if appState.isRecording {
                    HStack(spacing: 8) {
                        AudioLevelBars(level: appState.audioLevel)
                        Text("Recording...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                } else {
                    Text("Hold ")
                        .font(.subheadline)
                        .foregroundStyle(.quaternary)
                    + Text("Fn")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                    + Text(" to dictate anywhere")
                        .font(.subheadline)
                        .foregroundStyle(.quaternary)
                }

                Spacer()

                RecordButton(isRecording: appState.isRecording, action: onToggle)
            }
            .padding(.leading, 20)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(.quaternary.opacity(0.2))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.quaternary.opacity(0.15), lineWidth: 1)
            )
        }
        .animation(.spring(duration: 0.3, bounce: 0.15), value: appState.isRecording)
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
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))
                }

                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 38, height: 38)
                    .shadow(color: (isRecording ? Color.red : Color.accentColor).opacity(0.3), radius: 8, y: 2)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 48, height: 48)
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

/// Unified processing indicator — shimmer sweep + spinner. Used across all screens.
struct ProcessingBanner: View {
    var compact: Bool = false
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        HStack(spacing: 8) {
            SpinnerView(size: compact ? 12 : 14)

            Text("Transcribing...")
                .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: compact ? nil : .infinity)
        .padding(.vertical, compact ? 6 : 10)
        .padding(.horizontal, compact ? 12 : 16)
        .background {
            RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.accentColor.opacity(0.08), .clear],
                                startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                                endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 0.5)
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}

/// Reusable copy button with icon morph feedback — clipboard morphs to checkmark
struct CopyButton: View {
    let text: String
    var label: String = "Copy"
    var compact: Bool = false

    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(.spring(duration: 0.3)) {
                copied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(duration: 0.3)) { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))

                Text(copied ? "Copied" : label)
                    .font(compact ? .caption2.weight(.medium) : .caption.weight(.medium))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}

/// Simple spinning ring
struct SpinnerView: View {
    var size: CGFloat = 14
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotating = true
                }
            }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    Text("Retry")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

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
        .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.orange.opacity(0.1), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Hero Progress Bar

struct HeroProgressBar: View {
    let todayWords: Int
    let dailyGoal: Int
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayWords) / Double(dailyGoal), 1.0)
    }

    private var goalReached: Bool {
        dailyGoal > 0 && todayWords >= dailyGoal
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: goalReached
                                ? [.green, .green.opacity(0.7)]
                                : [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.35, green: 0.78, blue: 0.98)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * animatedProgress), height: 4)
            }
        }
        .frame(height: 4)
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

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if !appState.transcriptionHistory.isEmpty {
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

            if appState.transcriptionHistory.isEmpty {
                VStack(spacing: 8) {
                    Text("No transcriptions yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Text("Hold **Fn** to start dictating — your history will appear here")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    let items = Array(appState.transcriptionHistory.prefix(20))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, record in
                        HistoryItemView(record: record)

                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 4)
                        }
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: appState.transcriptionHistory.count)
    }
}

struct HistoryItemView: View {
    let record: TranscriptionRecord

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .font(.body)
                .lineLimit(3)
            HStack(spacing: 8) {
                Text("\(record.wordCount) words · \(timeAgo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: record.text, compact: true)
            }
        }
        .padding(.vertical, 10)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
