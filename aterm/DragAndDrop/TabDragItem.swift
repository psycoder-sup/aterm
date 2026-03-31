import Foundation
import UniformTypeIdentifiers
import CoreTransferable

extension UTType {
    static let atermTab = UTType(exportedAs: "com.aterm.tab-drag-item")
}

struct TabDragItem: Codable, Transferable {
    let tabID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .atermTab)
    }
}
