import SwiftUI

struct TerminalWindow: View {
    @State private var spaceCollection: SpaceCollection?
    @State private var errorMessage: String?
    @State private var eventMonitor: Any?
    @State private var lastContainerSize: CGSize = .zero

    var body: some View {
        Group {
            if let spaceCollection {
                VStack(spacing: 0) {
                    SpaceBarView(spaceCollection: spaceCollection) {
                        let wd = spaceCollection.resolveWorkingDirectory()
                        spaceCollection.createSpace(workingDirectory: wd)
                    }
                    Divider()

                    if let space = spaceCollection.activeSpace {
                        TabBarView(space: space) {
                            let wd = spaceCollection.resolveWorkingDirectory()
                            space.createTab(workingDirectory: wd)
                        }
                    }

                    // All tabs across all spaces are kept alive in a ZStack.
                    // Only the active tab of the active space is visible.
                    // This avoids destroying/rebuilding NSView hierarchies on
                    // every tab or space switch, which caused 1s+ lag from
                    // Metal layer reattachment and ghostty surface refresh.
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
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to start terminal")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .terminalBackground))
            } else {
                Color(nsColor: .terminalBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(windowTitle)
        .task {
            if GhosttyApp.shared.app == nil {
                errorMessage = "Ghostty failed to initialize"
                return
            }
            let collection = SpaceCollection()
            spaceCollection = collection
            installKeyboardMonitor(collection)
        }
        .onChange(of: spaceCollection?.shouldQuit) { _, shouldQuit in
            if shouldQuit == true {
                NSApplication.shared.terminate(nil)
            }
        }
        .onChange(of: spaceCollection?.activeSpace?.activeTabID) { _, _ in
            spaceCollection?.activeSpace?.activeTab?.paneViewModel.containerSize = lastContainerSize
        }
        .onChange(of: spaceCollection?.activeSpaceID) { _, _ in
            spaceCollection?.activeSpace?.activeTab?.paneViewModel.containerSize = lastContainerSize
        }
        .onDisappear {
            cleanupAll()
        }
    }

    // MARK: - Computed

    private var windowTitle: String {
        guard let spaceCollection,
              let space = spaceCollection.activeSpace,
              let tab = space.activeTab else {
            return "aterm"
        }
        return tab.paneViewModel.title
    }

    // MARK: - Container Size

    private func syncContainerSize(_ size: CGSize) {
        lastContainerSize = size
        guard let spaceCollection,
              let space = spaceCollection.activeSpace,
              let tab = space.activeTab else { return }
        tab.paneViewModel.containerSize = size
    }

    // MARK: - Keyboard Monitor

    private func installKeyboardMonitor(_ collection: SpaceCollection) {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let action = KeyBindingRegistry.shared.action(for: event) else {
                return event
            }

            // Don't consume shortcuts when a text field (e.g., inline rename) is focused
            if let responder = event.window?.firstResponder, responder is NSText {
                return event
            }

            guard let space = collection.activeSpace else { return event }

            switch action {
            case .newTab:
                let wd = collection.resolveWorkingDirectory()
                space.createTab(workingDirectory: wd)
            case .nextTab:
                space.nextTab()
            case .previousTab:
                space.previousTab()
            case .goToTab(let index):
                space.goToTab(index: index)
            case .newSpace:
                let wd = collection.resolveWorkingDirectory()
                collection.createSpace(workingDirectory: wd)
            case .nextSpace:
                collection.nextSpace()
            case .previousSpace:
                collection.previousSpace()
            }

            // Sync container size to the newly active tab
            collection.activeSpace?.activeTab?.paneViewModel.containerSize = self.lastContainerSize
            return nil
        }
    }

    // MARK: - Cleanup

    private func cleanupAll() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        guard let spaceCollection else { return }
        for space in spaceCollection.spaces {
            for tab in space.tabs {
                tab.cleanup()
            }
        }
    }
}
