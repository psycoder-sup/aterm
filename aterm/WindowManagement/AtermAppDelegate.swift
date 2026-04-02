import AppKit

@MainActor
class AtermAppDelegate: NSObject, NSApplicationDelegate {
    let workspaceManager = WorkspaceManager()
    let windowCoordinator = WindowCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowCoordinator.workspaceManager = workspaceManager

        if let state = SessionRestorer.loadState() {
            Log.persistence.info("Restoring session with \(state.workspaces.count) workspace(s)")
            // Currently single-window: all workspaces go into one WorkspaceCollection.
            // Multi-window support (one collection per window) is a future enhancement.
            let collection = SessionRestorer.buildWorkspaceCollection(from: state)
            let frame = state.workspaces.first?.windowFrame
            let isFullscreen = state.workspaces.first?.isFullscreen
            windowCoordinator.openRestoredWindow(
                collection: collection,
                frame: frame,
                isFullscreen: isFullscreen
            )
        } else {
            windowCoordinator.openWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for collection in windowCoordinator.allWorkspaceCollections {
            for workspace in collection.workspaces {
                workspace.cleanup()
            }
        }
        return .terminateNow
    }
}
