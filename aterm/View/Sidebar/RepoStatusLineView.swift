import SwiftUI

/// Displays a single git repo's branch name in the sidebar status area.
struct RepoStatusLineView: View {
    let repoStatus: GitRepoStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
            Text(repoStatus.branchName ?? "unknown")
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(.secondary)
    }
}
