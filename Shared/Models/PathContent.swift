import Foundation

// MARK: - Path Day Structure
//
// One day of a DailyPath. Sequenced 5-step session: opening prayer →
// scripture (with practical meaning) → small action → reflection → recall
// quiz. All content is pre-baked at seed time so a day session renders
// without a network round-trip.

struct PathDay: Codable, Identifiable {
    let day: Int
    let themeLabel: String?
    let openingPrayer: String
    let scripture: PathScripture
    let practicalMeaning: String
    let smallAction: String
    let reflectionPrompt: String
    let quiz: PathQuiz

    var id: Int { day }
}

struct PathScripture: Codable {
    let bookID: String
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?
    let verseText: String

    var displayReference: String {
        guard let book = BibleData.book(id: bookID) else { return "\(bookID) \(chapter)" }
        if let start = verseStart, let end = verseEnd {
            return start == end
                ? "\(book.name) \(chapter):\(start)"
                : "\(book.name) \(chapter):\(start)-\(end)"
        }
        return "\(book.name) \(chapter)"
    }
}

struct PathQuiz: Codable {
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - Session State

enum PathStep: String, Codable, CaseIterable {
    case openingPrayer
    case scripture
    case smallAction
    case reflection
    case quiz
}

struct PartialDayState: Codable {
    let day: Int
    var completedSteps: [PathStep]
    var updatedAt: Date

    func isStepDone(_ step: PathStep) -> Bool {
        completedSteps.contains(step)
    }
}

// MARK: - Chapter
//
// Optional path-level metadata that groups days into themed arcs. Drives the
// section-header layout in PathDetailView so the journey reads as a structured
// arc (e.g. "Naming the anxiety" → "Receiving peace") rather than a flat list
// of 14 indistinguishable rows. Paths without chapters render as a single
// ungrouped list — chapter authoring is opt-in.

struct PathChapter: Codable, Identifiable, Hashable {
    let title: String
    let firstDay: Int
    let lastDay: Int

    var id: String { "\(firstDay)-\(lastDay)" }

    func contains(_ day: Int) -> Bool {
        day >= firstDay && day <= lastDay
    }

    var dayRangeLabel: String {
        firstDay == lastDay ? "Day \(firstDay)" : "Days \(firstDay)–\(lastDay)"
    }
}
