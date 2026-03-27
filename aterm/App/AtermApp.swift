import SwiftUI

class AtermAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct AtermApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AtermAppDelegate

    init() {
        // Set GHOSTTY_RESOURCES_DIR for shell integration scripts
        if let resourcesPath = Bundle.main.resourceURL?.appendingPathComponent("ghostty").path {
            setenv("GHOSTTY_RESOURCES_DIR", resourcesPath, 0)
        }

        // Initialize the ghostty singleton (triggers ghostty_init + app creation)
        _ = GhosttyApp.shared
    }

    var body: some Scene {
        WindowGroup {
            TerminalWindow()
        }
        .defaultSize(width: 800, height: 600)
    }
}
