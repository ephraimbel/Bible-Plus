import Foundation
import SwiftData

/// Tracks topics the user has explored across conversations.
/// Used for conversation memory — the AI references past topics
/// to create continuity and deeper engagement.
@Model
final class ConversationTopic {
    var id: UUID
    var topic: String
    var firstMentioned: Date
    var lastMentioned: Date
    var mentionCount: Int
    var depthRaw: String

    var depth: TopicDepth {
        get { TopicDepth(rawValue: depthRaw) ?? .surface }
        set { depthRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        topic: String,
        firstMentioned: Date = Date(),
        lastMentioned: Date = Date(),
        mentionCount: Int = 1,
        depth: TopicDepth = .surface
    ) {
        self.id = id
        self.topic = topic
        self.firstMentioned = firstMentioned
        self.lastMentioned = lastMentioned
        self.mentionCount = mentionCount
        self.depthRaw = depth.rawValue
    }
}

enum TopicDepth: String, CaseIterable {
    case surface    // mentioned once or twice
    case explored   // 3-5 mentions, some back and forth
    case deep       // 6+ mentions, sustained conversation

    static func from(mentionCount: Int) -> TopicDepth {
        switch mentionCount {
        case 0...2: return .surface
        case 3...5: return .explored
        default: return .deep
        }
    }

    var displayName: String {
        switch self {
        case .surface: String(localized: "surface")
        case .explored: String(localized: "explored")
        case .deep: String(localized: "deep")
        }
    }
}
