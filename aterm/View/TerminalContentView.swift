import SwiftUI
import AppKit

struct TerminalContentView: NSViewRepresentable {
    let surface: GhosttyTerminalSurface

    func makeNSView(context: Context) -> TerminalSurfaceView {
        let view = TerminalSurfaceView()
        view.terminalSurface = surface
        return view
    }

    func updateNSView(_ nsView: TerminalSurfaceView, context: Context) {}
}
