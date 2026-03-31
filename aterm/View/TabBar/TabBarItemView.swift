import SwiftUI

struct TabBarItemView: View {
    @Bindable var tab: TabModel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var lastClickTime: Date?

    var body: some View {
        HStack(spacing: 4) {
            InlineRenameView(
                text: tab.name,
                isRenaming: $isRenaming,
                onCommit: { tab.name = $0 }
            )
            .foregroundStyle(isActive ? .primary : .secondary)

            if isActive || isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
                .accessibilityLabel("Close tab \(tab.name)")
            } else {
                Color.clear
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
            }
        }
        .onHover { isHovering = $0 }
        .onTapGesture {
            let now = Date()
            if let last = lastClickTime, now.timeIntervalSince(last) < 0.3 {
                lastClickTime = nil
                isRenaming = true
            } else {
                lastClickTime = now
                onSelect()
            }
        }
        .contentShape(Rectangle())
        .draggable(TabDragItem(tabID: tab.id))
        .contextMenu {
            Button("Rename") { isRenaming = true }
            Divider()
            Button("Close Tab", action: onClose)
            Button("Close Other Tabs", action: onCloseOthers)
            Button("Close Tabs to the Right", action: onCloseToRight)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tab.name)
        .accessibilityValue(isActive ? "selected" : "not selected")
    }
}
