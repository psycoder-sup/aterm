import SwiftUI

/// Renders a single terminal pane by looking up its surface view from the view model.
struct PaneView: View {
    let paneID: UUID
    let viewModel: PaneViewModel

    private var isFocused: Bool {
        viewModel.splitTree.focusedPaneID == paneID
    }

    private var showFocusBorder: Bool {
        isFocused && viewModel.splitTree.leafCount > 1
    }

    private var showBellGlow: Bool {
        viewModel.bellNotifications.contains(paneID)
    }

    var body: some View {
        TerminalContentView(
            paneID: paneID,
            viewModel: viewModel,
            isFocused: isFocused
        )
        .overlay {
            if showFocusBorder {
                RainbowBorder()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showFocusBorder)
        .overlay {
            if showBellGlow {
                RainbowGlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showBellGlow)
        .overlay {
            let state = viewModel.paneState(for: paneID)
            if state != .running {
                PaneExitOverlay(
                    state: state,
                    onRestart: { viewModel.restartShell(paneID: paneID) },
                    onClose: { viewModel.closePane(paneID: paneID) }
                )
            }
        }
    }
}
