import AppKit
import Foundation

/// Coordinates the "pick directory → create workspace" flow for all explicit
/// workspace creation entry points (menu, sidebar button, first launch).
///
/// Internal helpers are exposed as static members for unit testing.
@MainActor
enum WorkspaceCreationFlow {

    /// Derives a workspace name from a directory URL's last path component.
    /// Returns nil if the basename is empty or equal to "/" — caller falls
    /// back to `WorkspaceCollection`'s auto-generated "Workspace N".
    static func deriveWorkspaceName(from url: URL) -> String? {
        let basename = url.standardizedFileURL.lastPathComponent
        if basename.isEmpty || basename == "/" {
            return nil
        }
        return basename
    }
}
