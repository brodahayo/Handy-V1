import SwiftUI

struct ModelManagerView: View {
    @State private var models: [(name: String, size: String, downloaded: Bool)] = [
        ("Tiny", "tiny", false),
        ("Base", "base", false),
        ("Small", "small", false),
        ("Medium", "medium", false),
        ("Large v3", "large-v3", false),
    ]
    @State private var downloading: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(models, id: \.name) { model in
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.name)
                            .font(.body)
                    }

                    Spacer()

                    if model.downloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("Delete") {
                            // TODO: delete model
                        }
                        .buttonStyle(.borderless)
                    } else if downloading == model.size {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Download") {
                            downloading = model.size
                            // TODO: download model via LocalTranscriber
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            for i in models.indices {
                models[i].downloaded = LocalTranscriber.isModelDownloaded(models[i].size)
            }
        }
    }
}
