import SwiftUI

struct TerminalWindow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var surface: GhosttyTerminalSurface?
    @State private var errorMessage: String?
    @State private var title: String = "aterm"
    @State private var isClosed = false

    var body: some View {
        Group {
            if let surface, !isClosed {
                TerminalContentView(surface: surface)
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
        .navigationTitle(title)
        .task {
            if GhosttyApp.shared.app == nil {
                errorMessage = "Ghostty failed to initialize"
                return
            }
            let newSurface = GhosttyTerminalSurface()
            self.surface = newSurface
        }
        .onReceive(NotificationCenter.default.publisher(for: GhosttyApp.surfaceCloseNotification)) { notification in
            guard let surfaceId = notification.userInfo?["surfaceId"] as? UUID,
                  surfaceId == surface?.id else { return }
            surface?.freeSurface()
            isClosed = true
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: GhosttyApp.surfaceTitleNotification)) { notification in
            guard let surfaceId = notification.userInfo?["surfaceId"] as? UUID,
                  surfaceId == surface?.id,
                  let newTitle = notification.userInfo?["title"] as? String else { return }
            title = newTitle
        }
        .onDisappear {
            surface?.freeSurface()
        }
    }
}
