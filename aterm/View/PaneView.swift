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

    var body: some View {
        TerminalContentView(
            paneID: paneID,
            viewModel: viewModel,
            isFocused: isFocused
        )
        .overlay {
            if showFocusBorder {
                Rectangle()
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
    }
}
