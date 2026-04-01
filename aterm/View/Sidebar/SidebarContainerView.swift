import SwiftUI

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let focusSidebar = Notification.Name("focusSidebar")
}

struct SidebarContainerView: View {
    let workspaceID: UUID
    let spaceCollection: SpaceCollection

    @State private var sidebarState = SidebarState()
    @State private var lastContainerSize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Sidebar panel — extends full height behind the titlebar
            SidebarPanelView()
                .frame(width: sidebarState.mode.width)

            // Content layer
            VStack(spacing: 0) {
                // Tab bar row — traffic lights + sidebar toggle + tabs
                HStack(spacing: 6) {
                    // Traffic light clearance + sidebar toggle (always visible)
                    HStack(spacing: 6) {
                        Color.clear.frame(width: 80)
                        SidebarToggleButton(workspaceID: workspaceID)
                    }
                    .frame(width: max(sidebarState.mode.width, 104), alignment: .leading)

                    tabBar
                }
                .frame(height: 44)

                // Terminal area — offset to the right of the sidebar
                terminalZStack
                    .padding(.leading, sidebarState.mode.width)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { notification in
            guard let id = notification.object as? UUID, id == workspaceID else { return }
            sidebarState.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSidebar)) { notification in
            guard let id = notification.object as? UUID, id == workspaceID else { return }
            if !sidebarState.isExpanded {
                sidebarState.toggle()
            }
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        if let space = spaceCollection.activeSpace {
            TabBarView(space: space) {
                let wd = spaceCollection.resolveWorkingDirectory()
                space.createTab(workingDirectory: wd)
            }
        } else {
            Color.clear.frame(height: 44)
        }
    }

    // MARK: - Terminal Panes

    @ViewBuilder
    private var terminalZStack: some View {
        ZStack {
            ForEach(spaceCollection.spaces) { space in
                ForEach(space.tabs) { tab in
                    let isVisible = space.id == spaceCollection.activeSpaceID
                        && tab.id == space.activeTabID
                    SplitTreeView(
                        node: tab.paneViewModel.splitTree.root,
                        viewModel: tab.paneViewModel
                    )
                    .opacity(isVisible ? 1 : 0)
                    .allowsHitTesting(isVisible)
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { handleContainerSizeChange(geo.size) }
                    .onChange(of: geo.size) { _, newSize in
                        lastContainerSize = newSize
                        if !sidebarState.isAnimating {
                            handleContainerSizeChange(newSize)
                        }
                    }
            }
        )
        .onChange(of: sidebarState.isAnimating) { wasAnimating, isAnimating in
            if wasAnimating && !isAnimating {
                handleContainerSizeChange(lastContainerSize)
            }
        }
        .onChange(of: spaceCollection.activeSpace?.activeTabID) { _, _ in
            spaceCollection.activeSpace?.activeTab?.paneViewModel.containerSize = lastContainerSize
        }
        .onChange(of: spaceCollection.activeSpaceID) { _, _ in
            spaceCollection.activeSpace?.activeTab?.paneViewModel.containerSize = lastContainerSize
        }
    }

    // MARK: - Container Size

    private func handleContainerSizeChange(_ size: CGSize) {
        lastContainerSize = size
        guard let space = spaceCollection.activeSpace,
              let tab = space.activeTab else { return }
        tab.paneViewModel.containerSize = size
    }
}
