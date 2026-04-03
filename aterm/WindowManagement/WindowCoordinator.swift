import AppKit

@MainActor
final class WindowCoordinator {
    private var controllers: [WorkspaceWindowController] = []
    weak var workspaceManager: WorkspaceManager?

    func openWindow() {
        guard let manager = workspaceManager else { return }

        let collection = WorkspaceCollection()
        let controller = WorkspaceWindowController(
            workspaceCollection: collection,
            workspaceManager: manager,
            windowCoordinator: self
        )
        controllers.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// Opens a window with a restored WorkspaceCollection, applying saved window geometry.
    func openRestoredWindow(
        collection: WorkspaceCollection,
        frame: WindowFrame?,
        isFullscreen: Bool?
    ) {
        guard let manager = workspaceManager else { return }

        let controller = WorkspaceWindowController(
            workspaceCollection: collection,
            workspaceManager: manager,
            windowCoordinator: self
        )
        controllers.append(controller)

        if let frame, frame.isOnScreen(screenFrames: NSScreen.screens.map(\.frame)) {
            controller.window?.setFrame(frame.cgRect, display: false)
        } else {
            controller.window?.center()
        }

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)

        if isFullscreen == true {
            controller.window?.toggleFullScreen(nil)
        }
    }

    func removeController(_ controller: WorkspaceWindowController) {
        controllers.removeAll(where: { $0 === controller })
    }

    func controllerForKeyWindow() -> WorkspaceWindowController? {
        let keyWindow = NSApplication.shared.keyWindow
        return controllers.first(where: { $0.window === keyWindow })
    }

    var allWorkspaceCollections: [WorkspaceCollection] {
        controllers.map(\.workspaceCollection)
    }

    var allControllers: [WorkspaceWindowController] {
        controllers
    }

    var windowCount: Int { controllers.count }
}
