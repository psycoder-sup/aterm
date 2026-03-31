import SwiftUI

struct TabBarView: View {
    let space: SpaceModel
    var onNewTab: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(space.tabs) { tab in
                        TabBarItemView(
                            tab: tab,
                            isActive: tab.id == space.activeTabID,
                            onSelect: { space.activateTab(id: tab.id) },
                            onClose: { space.removeTab(id: tab.id) },
                            onCloseOthers: { space.closeOtherTabs(keepingID: tab.id) },
                            onCloseToRight: { space.closeTabsToRight(ofID: tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 6)
            }
            .dropDestination(for: TabDragItem.self) { items, _ in
                guard let item = items.first,
                      let sourceIndex = space.tabs.firstIndex(where: { $0.id == item.tabID }) else {
                    return false
                }
                let destIndex = space.tabs.count - 1
                if sourceIndex != destIndex {
                    space.reorderTab(from: sourceIndex, to: destIndex)
                }
                return true
            }

            Spacer()

            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .accessibilityLabel("New tab")
            .padding(.trailing, 6)
        }
        .frame(height: 30)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }
}
