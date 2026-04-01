import SwiftUI

struct SidebarPanelView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 12, style: .continuous))
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 6, trailing: 4))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace sidebar")
    }
}
