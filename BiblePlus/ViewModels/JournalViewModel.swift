import Foundation
import SwiftData

@MainActor
@Observable
final class JournalViewModel {
    var journalFilter: JournalFilter = .all
    var journalCategoryFilter: PrayerCategory? = nil
    var showAnsweredCelebration: Bool = false
    var celebrationPrayerTitle: String = ""

    private var journalVersion: Int = 0
    private let modelContext: ModelContext
    private let personalizationService: PersonalizationService

    enum JournalFilter: String, CaseIterable {
        case all
        case unanswered
        case answered

        var displayName: String {
            switch self {
            case .all: "All"
            case .unanswered: "Unanswered"
            case .answered: "Answered"
            }
        }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.personalizationService = PersonalizationService(modelContext: modelContext)
    }

    // MARK: - Computed Properties

    var journalEntries: [PrayerEntry] {
        let _ = journalVersion
        let descriptor = FetchDescriptor<PrayerEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor) else { return [] }

        var filtered = all

        switch journalFilter {
        case .all: break
        case .unanswered: filtered = filtered.filter { !$0.isAnswered }
        case .answered: filtered = filtered.filter { $0.isAnswered }
        }

        if let cat = journalCategoryFilter {
            filtered = filtered.filter { $0.category == cat }
        }

        return filtered
    }

    var totalPrayerCount: Int {
        let descriptor = FetchDescriptor<PrayerEntry>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var answeredPrayerCount: Int {
        let descriptor = FetchDescriptor<PrayerEntry>(
            predicate: #Predicate { $0.isAnswered == true }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var dailyReflection: String {
        DailyReflectionProvider.prompt(for: personalizationService.getOrCreateProfile())
    }

    // MARK: - CRUD

    func createPrayerEntry(title: String, body: String, category: PrayerCategory, verseReference: String?) {
        let entry = PrayerEntry(title: title, body: body, category: category, verseReference: verseReference)
        modelContext.insert(entry)
        try? modelContext.save()
        journalVersion += 1
        ActivityService.log(.prayerWritten, detail: String(title.prefix(50)), in: modelContext)
    }

    func updatePrayerEntry(_ entry: PrayerEntry, title: String, body: String, category: PrayerCategory, verseReference: String?) {
        entry.title = title
        entry.body = body
        entry.category = category
        entry.verseReference = verseReference
        entry.updatedAt = Date()
        try? modelContext.save()
        journalVersion += 1
    }

    func deletePrayerEntry(_ entry: PrayerEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        journalVersion += 1
    }

    func markPrayerAsAnswered(_ entry: PrayerEntry, notes: String) {
        entry.isAnswered = true
        entry.answerNotes = notes
        entry.answeredAt = Date()
        entry.updatedAt = Date()
        try? modelContext.save()
        journalVersion += 1
        ActivityService.log(.prayerAnswered, detail: String(entry.title.prefix(50)), in: modelContext)

        celebrationPrayerTitle = entry.title
        showAnsweredCelebration = true
    }

    func unmarkPrayerAsAnswered(_ entry: PrayerEntry) {
        entry.isAnswered = false
        entry.answerNotes = ""
        entry.answeredAt = nil
        entry.updatedAt = Date()
        try? modelContext.save()
        journalVersion += 1
    }

}
