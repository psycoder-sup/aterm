import AppKit

@MainActor
final class WindowCoordinator {
    private var controllers: [UUID: WorkspaceWindowController] = [:]
    weak var workspaceManager: WorkspaceManager?

    /// Tracks workspace IDs being closed programmatically to prevent re-entrant delete.
    var closingWorkspaceIDs: Set<UUID> = []

    func openWindow(for workspaceID: UUID) {
        guard controllers[workspaceID] == nil else {
            bringToFront(for: workspaceID)
            return
        }
        guard let manager = workspaceManager,
              let workspace = manager.workspaces.first(where: { $0.id == workspaceID }) else { return }

        let controller = WorkspaceWindowController(
            workspace: workspace,
            workspaceManager: manager,
            windowCoordinator: self
        )
        controllers[workspaceID] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow(for workspaceID: UUID) {
        guard let controller = controllers[workspaceID] else { return }
        closingWorkspaceIDs.insert(workspaceID)
        controller.window?.close()
    }

    func bringToFront(for workspaceID: UUID) {
        guard let controller = controllers[workspaceID] else {
            openWindow(for: workspaceID)
            return
        }
        controller.window?.makeKeyAndOrderFront(nil)
    }

    func removeController(for workspaceID: UUID) {
        closingWorkspaceIDs.remove(workspaceID)
        controllers.removeValue(forKey: workspaceID)
    }

    var windowCount: Int { controllers.count }
}
