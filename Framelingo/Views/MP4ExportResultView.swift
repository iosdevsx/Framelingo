import SwiftUI

struct MP4ExportResultView: View {
    let result: MP4ExportResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.title)
                .font(.headline)

            switch result {
            case .success:
                EmptyView()
            case .failure(let message, let debugOutput):
                Text(message)

                if let debugOutput, !debugOutput.isEmpty {
                    DisclosureGroup("Debug") {
                        ScrollView {
                            Text(debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(minHeight: 120, maxHeight: 260)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack {
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
