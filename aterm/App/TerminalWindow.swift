import SwiftUI

struct TerminalWindow: View {
    @State private var core: TerminalCore?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let core {
                TerminalContentView(core: core)
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
        .task {
            do {
                core = try TerminalCore()
            } catch {
                errorMessage = error.localizedDescription
                Log.core.error("Failed to initialize TerminalCore: \(error)")
            }
        }
        .onDisappear {
            core?.terminate()
        }
    }
}
