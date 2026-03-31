import AppKit

@MainActor
class AtermAppDelegate: NSObject, NSApplicationDelegate {
    let workspaceManager = WorkspaceManager()
    let windowCoordinator = WindowCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        workspaceManager.windowCoordinator = windowCoordinator
        windowCoordinator.workspaceManager = workspaceManager

        workspaceManager.createWorkspace(name: "default")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for workspace in workspaceManager.workspaces {
            workspace.cleanup()
        }
        return .terminateNow
    }
}
