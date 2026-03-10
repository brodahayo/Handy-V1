import SwiftUI

struct DictionaryPage: View {
    @State private var words: [(word: String, count: Int)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your most frequently used words across all transcriptions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .top])
                .padding(.bottom, 12)

            if words.isEmpty {
                ContentUnavailableView(
                    "No Words Yet",
                    systemImage: "textformat.abc",
                    description: Text("Start dictating to build your word frequency list.")
                )
            } else {
                List(words.prefix(60), id: \.word) { item in
                    HStack {
                        Text(item.word)
                            .font(.body)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
