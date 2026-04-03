import Foundation

/// Information about a surface with a running foreground process.
struct RunningProcessInfo: Sendable {
    let workspaceName: String
    let spaceName: String
    let tabName: String
    let paneID: UUID
}

/// Detects foreground processes across all terminal surfaces using ghostty's built-in
/// `ghostty_surface_needs_confirm_quit` API.
@MainActor
enum ProcessDetector {

    /// Returns info about every surface that has a running foreground process.
    static func detectRunningProcesses(
        in collections: [WorkspaceCollection]
    ) -> [RunningProcessInfo] {
        var results: [RunningProcessInfo] = []

        for collection in collections {
            for workspace in collection.workspaces {
                for space in workspace.spaceCollection.spaces {
                    for tab in space.tabs {
                        for (paneID, terminalSurface) in tab.paneViewModel.surfaces {
                            guard let surface = terminalSurface.surface,
                                  ghostty_surface_needs_confirm_quit(surface) else { continue }
                            results.append(RunningProcessInfo(
                                workspaceName: workspace.name,
                                spaceName: space.name,
                                tabName: tab.name,
                                paneID: paneID
                            ))
                        }
                    }
                }
            }
        }

        return results
    }

    /// Quick check: returns true if any surface needs quit confirmation.
    static func needsConfirmation(
        in collections: [WorkspaceCollection]
    ) -> Bool {
        !detectRunningProcesses(in: collections).isEmpty
    }
}
