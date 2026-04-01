import SwiftUI

struct SidebarToggleButton: View {
    let workspaceID: UUID

    var body: some View {
        Button {
            NotificationCenter.default.post(
                name: .toggleSidebar,
                object: workspaceID
            )
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle sidebar")
    }
}
