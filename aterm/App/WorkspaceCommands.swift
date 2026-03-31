import SwiftUI

struct WorkspaceCommands: Commands {
    let workspaceManager: WorkspaceManager

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()

            Button("New Workspace") {
                let count = workspaceManager.workspaces.count
                workspaceManager.createWorkspace(name: "Workspace \(count + 1)")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Close Workspace") {
                guard let activeID = workspaceManager.activeWorkspaceID else { return }
                workspaceManager.deleteWorkspace(id: activeID)
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }
    }
}
