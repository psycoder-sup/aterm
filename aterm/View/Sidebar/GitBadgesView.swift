import SwiftUI

/// Displays compact count badges for non-zero git diff categories.
/// Shows a hover popover with the full file list.
struct GitBadgesView: View {
    let diffSummary: GitDiffSummary
    var changedFiles: [GitChangedFile] = []

    @State private var isPopoverPresented = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        if !diffSummary.isEmpty {
            HStack(spacing: 4) {
                if diffSummary.modified > 0 {
                    badgePill(count: diffSummary.modified, letter: "M")
                }
                if diffSummary.added > 0 {
                    badgePill(count: diffSummary.added, letter: "A")
                }
                if diffSummary.deleted > 0 {
                    badgePill(count: diffSummary.deleted, letter: "D")
                }
                if diffSummary.renamed > 0 {
                    badgePill(count: diffSummary.renamed, letter: "R")
                }
                if diffSummary.unmerged > 0 {
                    badgePill(count: diffSummary.unmerged, letter: "U")
                }
            }
            .onHover { hovering in
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        isPopoverPresented = true
                    }
                } else {
                    hoverTask = Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled else { return }
                        isPopoverPresented = false
                    }
                }
            }
            .popover(isPresented: $isPopoverPresented) {
                GitFileListPopover(changedFiles: changedFiles)
                    .onHover { hovering in
                        hoverTask?.cancel()
                        if !hovering {
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                guard !Task.isCancelled else { return }
                                isPopoverPresented = false
                            }
                        }
                    }
            }
        }
    }

    private func badgePill(count: Int, letter: String) -> some View {
        Text("\(count)\(letter)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color(white: 0.45))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
            )
    }
}
