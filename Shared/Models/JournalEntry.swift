import Foundation
import SwiftData
import SwiftUI

// MARK: - Journal Entry
//
// A single written reflection. Free-form like Notes (title + body), with an
// optional mood that gives the list a quiet splash of color. All properties
// carry defaults so SwiftData/CloudKit lightweight migration stays additive.
@Model
final class JournalEntry {
    var id: UUID = UUID()
    var title: String = ""
    var text: String = ""
    var moodRaw: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Links an entry back to the devotional/plan reflection that created it,
    /// e.g. `"path:peace-14:day:3"` or `"plan:psalms-of-peace:day:5"`. Empty
    /// for entries the user wrote directly in the Journal. Used to keep the
    /// auto-synced entry idempotent (one entry per reflection, never duplicated).
    var sourceKey: String = ""

    init(
        id: UUID = UUID(),
        title: String = "",
        text: String = "",
        moodRaw: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceKey: String = ""
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.moodRaw = moodRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceKey = sourceKey
    }

    var mood: JournalMood? {
        get { JournalMood(rawValue: moodRaw) }
        set { moodRaw = newValue?.rawValue ?? "" }
    }

    /// True when there's nothing worth keeping — used to discard empty drafts.
    var isBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The heading shown in the list — the title if set, otherwise the first
    /// line of the body, otherwise a gentle placeholder.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "New entry" : trimmed
    }

    /// The preview snippet — the body with the first line removed if it was
    /// promoted to the title, collapsed to a single flowing line.
    var preview: String {
        let usedFirstLineAsTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var body = text
        if usedFirstLineAsTitle, let range = body.rangeOfCharacter(from: .newlines) {
            body = String(body[range.upperBound...])
        } else if usedFirstLineAsTitle {
            body = ""
        }
        return body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Mood

enum JournalMood: String, CaseIterable, Identifiable {
    case grateful, peaceful, hopeful, joyful, reflective, heavy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grateful: return "Grateful"
        case .peaceful: return "Peaceful"
        case .hopeful: return "Hopeful"
        case .joyful: return "Joyful"
        case .reflective: return "Reflective"
        case .heavy: return "Heavy"
        }
    }

    var symbol: String {
        switch self {
        case .grateful: return "hands.and.sparkles.fill"
        case .peaceful: return "leaf.fill"
        case .hopeful: return "sun.max.fill"
        case .joyful: return "sparkles"
        case .reflective: return "moon.stars.fill"
        case .heavy: return "cloud.fill"
        }
    }

    var tint: Color {
        switch self {
        case .grateful: return Color(hex: "C9A96E")  // gold
        case .peaceful: return Color(hex: "7D9E7A")  // sage
        case .hopeful: return Color(hex: "DDA94E")   // amber
        case .joyful: return Color(hex: "D98E5A")    // warm orange
        case .reflective: return Color(hex: "8A7CA8") // muted violet
        case .heavy: return Color(hex: "7B8794")     // slate
        }
    }
}
