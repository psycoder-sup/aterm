import Foundation
import UniformTypeIdentifiers
import CoreTransferable

extension UTType {
    static let atermWorkspace = UTType(exportedAs: "com.aterm.workspace-drag-item")
}

struct WorkspaceDragItem: Codable, Transferable {
    let workspaceID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .atermWorkspace)
    }
}
