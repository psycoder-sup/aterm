import SwiftUI

extension Notification.Name {
    static let toggleWorkspaceSwitcher = Notification.Name("toggleWorkspaceSwitcher")
}

struct WorkspaceWindowContent: View {
    let workspaceID: UUID
    @Environment(WorkspaceManager.self) private var workspaceManager

    @State private var lastContainerSize: CGSize = .zero
    @State private var showWorkspaceSwitcher = false

    private var workspace: Workspace? {
        workspaceManager.workspaces.first(where: { $0.id == workspaceID })
    }

    private var spaceCollection: SpaceCollection? {
        workspace?.spaceCollection
    }

    var body: some View {
        Group {
            if let spaceCollection {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        if let workspace {
                            WorkspaceIndicatorView(workspace: workspace)
                            Divider()
                                .frame(height: 16)
                        }
                        SpaceBarView(spaceCollection: spaceCollection) {
                            let wd = spaceCollection.resolveWorkingDirectory()
                            spaceCollection.createSpace(workingDirectory: wd)
                        }
                    }
                    .frame(height: 28)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                    Divider()

                    if let space = spaceCollection.activeSpace {
                        TabBarView(space: space) {
                            let wd = spaceCollection.resolveWorkingDirectory()
                            space.createTab(workingDirectory: wd)
                        }
                    }

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
                                .onAppear { syncContainerSize(geo.size) }
                                .onChange(of: geo.size) { _, newSize in
                                    syncContainerSize(newSize)
                                }
                        }
                    )
                }
            } else {
                // Workspace not found — defensive; window should close
                Color(nsColor: .terminalBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: spaceCollection?.activeSpace?.activeTabID) { _, _ in
            spaceCollection?.activeSpace?.activeTab?.paneViewModel.containerSize = lastContainerSize
        }
        .onChange(of: spaceCollection?.activeSpaceID) { _, _ in
            spaceCollection?.activeSpace?.activeTab?.paneViewModel.containerSize = lastContainerSize
        }
        .overlay {
            if showWorkspaceSwitcher {
                WorkspaceSwitcherOverlay(isPresented: $showWorkspaceSwitcher)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleWorkspaceSwitcher)) { notification in
            guard let id = notification.object as? UUID, id == workspaceID else { return }
            showWorkspaceSwitcher.toggle()
        }
    }

    // MARK: - Container Size

    private func syncContainerSize(_ size: CGSize) {
        lastContainerSize = size
        guard let spaceCollection,
              let space = spaceCollection.activeSpace,
              let tab = space.activeTab else { return }
        tab.paneViewModel.containerSize = size
    }
}
