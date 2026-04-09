import SwiftUI

/// Displays a single git repo's status line: [non-repo dots] [repo dots] branch [spacer] badges
struct RepoStatusLineView: View {
    let repoStatus: GitRepoStatus
    var claudeDots: [ClaudeSessionState] = []
    var prependedDots: [ClaudeSessionState] = []

    var body: some View {
        HStack(spacing: 0) {
            if !prependedDots.isEmpty {
                ClaudeSessionDotsView(states: prependedDots)
                Spacer().frame(width: 4)
            }

            if !claudeDots.isEmpty {
                ClaudeSessionDotsView(states: claudeDots)
                Spacer().frame(width: 5)
            }

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
            Text(repoStatus.branchName ?? "unknown")
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            GitBadgesView(diffSummary: repoStatus.diffSummary)
        }
        .foregroundStyle(.secondary)
    }
}
