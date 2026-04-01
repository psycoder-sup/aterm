import SwiftUI

struct WorkspaceWindowContent: View {
    let workspaceID: UUID
    @Environment(WorkspaceManager.self) private var workspaceManager

    private var workspace: Workspace? {
        workspaceManager.workspaces.first(where: { $0.id == workspaceID })
    }

    private var spaceCollection: SpaceCollection? {
        workspace?.spaceCollection
    }

    var body: some View {
        Group {
            if let spaceCollection {
                SidebarContainerView(
                    workspaceID: workspaceID,
                    spaceCollection: spaceCollection
                )
            } else {
                // Workspace not found — defensive; window should close
                Color(nsColor: .terminalBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
