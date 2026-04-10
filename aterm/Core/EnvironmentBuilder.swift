import Foundation

/// Builds the `ATERM_*` environment dictionary injected into every
/// spawned terminal shell so the CLI binary can identify its pane,
/// tab, space, and workspace.
enum EnvironmentBuilder {

    /// Returns a dictionary of environment variables for a new pane.
    ///
    /// The dictionary includes `ATERM_*` identifiers, `PATH` with the
    /// app bundle directories prepended, and shell integration variables
    /// (`ZDOTDIR`, `ATERM_SHELL_INTEGRATION_DIR`, `ATERM_RESOURCES_DIR`)
    /// so the claude wrapper and CLI are discoverable from any shell.
    static func buildPaneEnvironment(
        socketPath: String,
        paneID: UUID,
        tabID: UUID,
        spaceID: UUID,
        workspaceID: UUID,
        cliPath: String
    ) -> [String: String] {
        let macOSDir = Bundle.main.executableURL!
            .deletingLastPathComponent()
            .path
        let resourcesDir = Bundle.main.resourceURL?.path ?? ""
        let existingPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let shellIntegrationDir = resourcesDir + "/shell-integration"
        let zdotdir = shellIntegrationDir + "/zsh"

        // Preserve the user's original ZDOTDIR so our .zshenv can restore it.
        let originalZdotdir = ProcessInfo.processInfo.environment["ZDOTDIR"]
            ?? ProcessInfo.processInfo.environment["HOME"]
            ?? ""

        var env: [String: String] = [
            "ATERM_SOCKET": socketPath,
            "ATERM_PANE_ID": paneID.uuidString,
            "ATERM_TAB_ID": tabID.uuidString,
            "ATERM_SPACE_ID": spaceID.uuidString,
            "ATERM_WORKSPACE_ID": workspaceID.uuidString,
            "ATERM_CLI_PATH": cliPath,
            "ATERM_RESOURCES_DIR": resourcesDir,
            "ATERM_SHELL_INTEGRATION_DIR": shellIntegrationDir,
            "PATH": "\(resourcesDir):\(macOSDir):\(existingPath)",
        ]

        // ZDOTDIR injection for zsh shell integration.
        env["ZDOTDIR"] = zdotdir
        env["ATERM_ORIGINAL_ZDOTDIR"] = originalZdotdir

        return env
    }
}
