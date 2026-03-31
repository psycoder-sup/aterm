import Foundation
import UniformTypeIdentifiers
import CoreTransferable

extension UTType {
    static let atermSpace = UTType(exportedAs: "com.aterm.space-drag-item")
}

struct SpaceDragItem: Codable, Transferable {
    let spaceID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .atermSpace)
    }
}
