import Foundation
import SwiftData

@Model
final class ContentCollection {
    var id: UUID
    var name: String
    var contentIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        contentIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.contentIDs = contentIDs
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
