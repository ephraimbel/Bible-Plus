import Foundation
import SwiftData

@Model
final class ActivityEvent {
    var id: UUID = UUID()
    var typeRaw: String = ""
    var detail: String = ""
    var createdAt: Date = Date()

    var type: ActivityEventType {
        get { ActivityEventType(rawValue: typeRaw) ?? .chapterRead }
        set { typeRaw = newValue.rawValue }
    }

    init(type: ActivityEventType, detail: String = "") {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.detail = detail
        self.createdAt = Date()
    }
}
