import SwiftUI

struct DictionaryPage: View {
    let appState: AppState
    @State private var appeared = false

    private var words: [(word: String, count: Int)] {
        appState.wordFrequencies
    }

    private var maxCount: Int {
        words.first?.count ?? 1
    }

    var body: some View {
        Group {
            if words.isEmpty {
                emptyState
            } else {
                wordList
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            Text("No Words Yet")
                .font(.title3.weight(.semibold))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            Text("Your most-used words will appear here\nas you dictate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Word List

    private var wordList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(words.prefix(60).enumerated()), id: \.element.word) { index, item in
                    wordRow(item: item, rank: index + 1)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(index) * 0.02),
                            value: appeared
                        )
                }
            }
            .padding(20)
        }
    }

    private func wordRow(item: (word: String, count: Int), rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .trailing)

            Text(item.word)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 4)

            barIndicator(count: item.count)

            Text("\(item.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private func barIndicator(count: Int) -> some View {
        let fraction = CGFloat(count) / CGFloat(maxCount)
        return GeometryReader { geo in
            Capsule()
                .fill(Color.accentColor.opacity(0.25))
                .frame(width: max(4, geo.size.width * fraction))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 60, height: 6)
    }
}
