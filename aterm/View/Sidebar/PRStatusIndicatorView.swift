import SwiftUI

/// Color-coded PR state label, tappable to open PR URL in browser.
struct PRStatusIndicatorView: View {
    let prStatus: PRStatus

    var body: some View {
        Text("PR")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(prStatus.state.color)
            .onTapGesture {
                NSWorkspace.shared.open(prStatus.url)
            }
            .accessibilityLabel("Pull request \(prStatus.state.rawValue)")
            .accessibilityHint("Tap to open in browser")
    }
}
