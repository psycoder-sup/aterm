import AppKit
import SwiftUI

@MainActor
final class WorkspaceWindowController: NSWindowController, NSWindowDelegate {
    let workspaceID: UUID
    private weak var workspace: Workspace?
    private weak var workspaceManager: WorkspaceManager?
    private weak var windowCoordinator: WindowCoordinator?
    private var eventMonitor: Any?

    init(
        workspace: Workspace,
        workspaceManager: WorkspaceManager,
        windowCoordinator: WindowCoordinator
    ) {
        self.workspaceID = workspace.id
        self.workspace = workspace
        self.workspaceManager = workspaceManager
        self.windowCoordinator = windowCoordinator

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = workspace.name
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .terminalBackground
        window.setFrameAutosaveName("workspace-\(workspace.id.uuidString)")
        window.center()

        let contentView = WorkspaceWindowContent(workspaceID: workspace.id)
            .environment(workspaceManager)

        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.initialFirstResponder = hostingView

        super.init(window: window)
        window.delegate = self

        observeNameChanges(workspace: workspace)
        installKeyboardMonitor(workspace: workspace)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Name Observation

    private func observeNameChanges(workspace: Workspace) {
        withObservationTracking {
            _ = workspace.name
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let window = self.window else { return }
                window.title = workspace.name
                self.observeNameChanges(workspace: workspace)
            }
        }
    }

    // MARK: - Keyboard Monitor

    private func installKeyboardMonitor(workspace: Workspace) {
        let collection = workspace.spaceCollection

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Only handle events for our window
            guard event.window === self.window else { return event }

            guard let action = KeyBindingRegistry.shared.action(for: event) else {
                return event
            }

            // Don't consume shortcuts when a text field is focused
            if let responder = event.window?.firstResponder, responder is NSText {
                return event
            }

            switch action {
            case .newTab:
                guard let space = collection.activeSpace else { return event }
                let wd = collection.resolveWorkingDirectory()
                space.createTab(workingDirectory: wd)
            case .nextTab:
                collection.activeSpace?.nextTab()
            case .previousTab:
                collection.activeSpace?.previousTab()
            case .goToTab(let index):
                collection.activeSpace?.goToTab(index: index)
            case .newSpace:
                let wd = collection.resolveWorkingDirectory()
                collection.createSpace(workingDirectory: wd)
            case .nextSpace:
                collection.nextSpace()
            case .previousSpace:
                collection.previousSpace()
            case .newWorkspace:
                let manager = self.workspaceManager
                let count = manager?.workspaces.count ?? 0
                manager?.createWorkspace(name: "Workspace \(count + 1)")
                return nil
            case .closeWorkspace:
                self.workspaceManager?.deleteWorkspace(id: self.workspaceID)
                return nil
            }

            // Sync container size to the newly active tab
            collection.activeSpace?.activeTab?.paneViewModel.containerSize =
                self.window?.contentView?.frame.size ?? .zero
            return nil
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if windowCoordinator?.closingWorkspaceIDs.contains(workspaceID) == false {
            // User-initiated close (red button)
            workspaceManager?.deleteWorkspace(id: workspaceID)
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyboardMonitor()
        windowCoordinator?.removeController(for: workspaceID)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        workspaceManager?.activeWorkspaceID = workspaceID
    }
}
