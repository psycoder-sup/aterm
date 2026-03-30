import SwiftUI

struct TerminalWindow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PaneViewModel?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let viewModel {
                SplitTreeView(node: viewModel.splitTree.root, viewModel: viewModel)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to start terminal")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .terminalBackground))
            } else {
                Color(nsColor: .terminalBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel?.title ?? "aterm")
        .task {
            if GhosttyApp.shared.app == nil {
                errorMessage = "Ghostty failed to initialize"
                return
            }
            viewModel = PaneViewModel()
        }
        .onChange(of: viewModel?.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss == true {
                dismiss()
            }
        }
        .onDisappear {
            viewModel?.cleanup()
        }
    }
}
