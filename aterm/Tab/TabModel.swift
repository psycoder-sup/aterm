import Foundation
import Observation

/// A single tab within a space. Each tab owns a PaneViewModel (split tree + surfaces).
@MainActor @Observable
final class TabModel: Identifiable {
    let id: UUID
    var name: String
    let paneViewModel: PaneViewModel
    let createdAt: Date

    /// Called when the tab's last pane is closed. The owning SpaceModel should remove this tab.
    var onEmpty: (() -> Void)?

    init(name: String, workingDirectory: String = "~") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.paneViewModel = PaneViewModel(workingDirectory: workingDirectory)

        // Wire cascading close: last pane → tab empty → space removes tab
        self.paneViewModel.onEmpty = { [weak self] in
            self?.onEmpty?()
        }
    }

    /// Restore a tab with a specific ID and pre-built PaneViewModel.
    init(id: UUID, name: String, paneViewModel: PaneViewModel) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.paneViewModel = paneViewModel

        self.paneViewModel.onEmpty = { [weak self] in
            self?.onEmpty?()
        }
    }

    /// The title from the focused pane's terminal (for display in the tab bar).
    var title: String {
        paneViewModel.title
    }

    func cleanup() {
        paneViewModel.cleanup()
    }
}
