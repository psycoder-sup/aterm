import Foundation

/// Top-level configuration parsed from `.aterm/config.toml`.
struct WorktreeConfig: Sendable, Equatable {
    /// Directory relative to repo root where worktrees are created.
    var worktreeDir: String = ".worktrees"
    /// Timeout in seconds per setup command.
    var setupTimeout: TimeInterval = 300
    /// Fallback delay in seconds for shell readiness when OSC 7 is not received.
    var shellReadyDelay: TimeInterval = 0.5
    /// Files to copy from main worktree to new worktree.
    var copyRules: [CopyRule] = []
    /// Ordered shell commands to run during setup.
    var setupCommands: [String] = []
    /// Pane layout tree for the first tab.
    var layout: LayoutNode?
}

/// A single file copy directive.
struct CopyRule: Sendable, Equatable {
    /// Glob pattern relative to repo root (e.g., `.env*`).
    var source: String
    /// Destination path relative to repo root. If it ends with `/`, files are placed inside that directory.
    var dest: String
}

/// A recursive layout tree node, mirroring `PaneNode` structure.
indirect enum LayoutNode: Sendable, Equatable {
    /// A terminal pane. `command` is the startup command (nil means plain shell).
    case pane(command: String?)
    /// A split container with two children.
    case split(direction: SplitDirection, ratio: Double, first: LayoutNode, second: LayoutNode)
}
