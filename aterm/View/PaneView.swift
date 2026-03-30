import SwiftUI

/// Renders a single terminal pane by looking up its surface view from the view model.
struct PaneView: View {
    let paneID: UUID
    let viewModel: PaneViewModel

    var body: some View {
        TerminalContentView(
            paneID: paneID,
            viewModel: viewModel,
            isFocused: viewModel.splitTree.focusedPaneID == paneID
        )
    }
}
