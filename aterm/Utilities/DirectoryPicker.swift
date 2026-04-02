import AppKit

enum DirectoryPicker {
    /// Shows an NSOpenPanel configured for directory selection.
    /// Returns the selected directory URL, or `nil` if the user cancelled.
    @MainActor
    static func chooseDirectory(title: String = "Choose Default Directory") -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
