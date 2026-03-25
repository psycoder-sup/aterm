import SwiftUI

@main
struct AtermApp: App {
    var body: some Scene {
        WindowGroup {
            TerminalWindow()
        }
        .defaultSize(width: 800, height: 600)
    }
}
