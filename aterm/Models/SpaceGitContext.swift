import Foundation
import Observation
import OSLog

/// Per-Space git repository context. Detects repos from pane working directories,
/// tracks pane-to-repo assignments, and maintains branch name status for the sidebar.
@MainActor @Observable
final class SpaceGitContext {

    // MARK: - Observable State

    /// Map of detected repos to their current status. Drives sidebar re-renders.
    private(set) var repoStatuses: [GitRepoID: GitRepoStatus] = [:]

    /// Maps each pane ID to its detected repo (nil entry = not yet detected or not in a repo).
    private(set) var paneRepoAssignments: [UUID: GitRepoID] = [:]

    /// Ordered list of pinned repos for display. First is worktree-derived repo if applicable.
    private(set) var pinnedRepoOrder: [GitRepoID] = []

    // MARK: - Private State

    /// Tracks in-flight refresh tasks per repo for cancellation on rapid re-triggers.
    private var inFlightTasks: [GitRepoID: Task<Void, Never>] = [:]

    /// Last-known working directory per pane.
    private var paneDirectories: [UUID: String] = [:]

    /// A directory we know maps to a specific repo, used for branch refresh.
    private var repoDirectories: [GitRepoID: String] = [:]

    // MARK: - Init

    /// Creates a git context for a Space.
    /// - Parameter worktreePath: If non-nil, eagerly detects the repo from this path.
    init(worktreePath: URL?) {
        if let worktreePath {
            let path = worktreePath.path
            Task { [weak self] in
                await self?.detectAndRefresh(paneID: nil, directory: path)
            }
        }
    }

    // MARK: - Public Methods

    /// Called when a pane's working directory changes (OSC 7).
    func paneWorkingDirectoryChanged(paneID: UUID, newDirectory: String) {
        paneDirectories[paneID] = newDirectory

        // Skip re-detection if this pane is already assigned to a repo
        // whose directory is a parent of the new directory (same repo, different subdir).
        if let existingRepoID = paneRepoAssignments[paneID],
           let repoDir = repoDirectories[existingRepoID],
           newDirectory == repoDir || newDirectory.hasPrefix(repoDir.hasSuffix("/") ? repoDir : repoDir + "/") {
            // Same repo — just refresh branch info without re-detecting
            refreshRepo(repoID: existingRepoID, directory: newDirectory)
            repoDirectories[existingRepoID] = newDirectory
            return
        }

        detectAndRefresh(paneID: paneID, directory: newDirectory)
    }

    /// Called when a new pane is created or restored with a known working directory.
    func paneAdded(paneID: UUID, workingDirectory: String?) {
        guard let wd = workingDirectory, !wd.isEmpty, wd != "~" else { return }
        paneDirectories[paneID] = wd
        detectAndRefresh(paneID: paneID, directory: wd)
    }

    /// Called when a pane is closed. Cleans up assignments and garbage-collects orphaned repos.
    func paneRemoved(paneID: UUID) {
        paneDirectories.removeValue(forKey: paneID)
        guard let repoID = paneRepoAssignments.removeValue(forKey: paneID) else { return }

        // Check if any remaining pane still references this repo
        let stillReferenced = paneRepoAssignments.values.contains(repoID)
        if !stillReferenced {
            inFlightTasks[repoID]?.cancel()
            inFlightTasks.removeValue(forKey: repoID)
            repoStatuses.removeValue(forKey: repoID)
            repoDirectories.removeValue(forKey: repoID)
            pinnedRepoOrder.removeAll { $0 == repoID }
            Log.git.debug("Unpinned orphaned repo: \(repoID.path)")
        }
    }

    /// Manually triggers a git status refresh for all pinned repos.
    func refresh() {
        for repoID in pinnedRepoOrder {
            guard let directory = repoDirectories[repoID] else { continue }
            refreshRepo(repoID: repoID, directory: directory)
        }
    }

    /// Cancels all in-flight tasks and clears state. Called on Space close.
    func teardown() {
        for task in inFlightTasks.values {
            task.cancel()
        }
        inFlightTasks.removeAll()
        repoStatuses.removeAll()
        paneRepoAssignments.removeAll()
        pinnedRepoOrder.removeAll()
        paneDirectories.removeAll()
        repoDirectories.removeAll()
    }

    // MARK: - Private

    /// Detects the git repo for a directory and refreshes its status.
    /// - Parameters:
    ///   - paneID: The pane that triggered detection (nil for worktree-path init).
    ///   - directory: The working directory to detect from.
    private func detectAndRefresh(paneID: UUID?, directory: String) {
        Task { [weak self] in
            guard let self else { return }

            guard let repo = await GitStatusService.detectRepo(directory: directory) else {
                if let paneID {
                    self.paneRepoAssignments.removeValue(forKey: paneID)
                }
                return
            }

            let repoID = GitRepoID(path: repo.commonDir)

            if let paneID {
                self.paneRepoAssignments[paneID] = repoID
            }
            self.repoDirectories[repoID] = directory

            // Add to pinned order if new
            if !self.pinnedRepoOrder.contains(repoID) {
                self.pinnedRepoOrder.append(repoID)
                Log.git.debug("Pinned new repo: \(repoID.path)")
            }

            self.refreshRepo(repoID: repoID, directory: directory)
        }
    }

    /// Refreshes branch info for a specific repo, with in-flight cancellation.
    private func refreshRepo(repoID: GitRepoID, directory: String) {
        // Cancel any existing in-flight task for this repo
        inFlightTasks[repoID]?.cancel()

        let task = Task { [weak self] in
            let branchResult = await GitStatusService.currentBranch(directory: directory)

            guard !Task.isCancelled else { return }
            guard let self else { return }

            let status = GitRepoStatus(
                repoID: repoID,
                branchName: branchResult?.name,
                isDetachedHead: branchResult?.isDetached ?? false,
                lastUpdated: Date()
            )

            self.repoStatuses[repoID] = status
            self.inFlightTasks.removeValue(forKey: repoID)
        }

        inFlightTasks[repoID] = task
    }
}
