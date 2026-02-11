import Foundation
import SwiftData

@MainActor
@Observable
final class FeedViewModel {
    // MARK: - State

    var cards: [PrayerContent] = []
    var currentIndex: Int = 0
    var showGreeting: Bool = true
    var isLoadingMore: Bool = false
    var savedContentIDs: Set<UUID> = []
    var doubleTapHeartID: UUID? = nil
    var shareContent: PrayerContent? = nil
    var collectionContent: PrayerContent? = nil
    var askAIContent: PrayerContent? = nil

    // MARK: - Private

    private var shownIDs: Set<UUID> = []
    private var shownIDTimestamps: [UUID: Date] = [:]
    private let batchSize: Int = 20
    private let prefetchThreshold: Int = 5

    private let feedEngine: FeedEngine
    private let personalizationService: PersonalizationService
    private let modelContext: ModelContext

    // MARK: - Computed

    var profile: UserProfile {
        personalizationService.getOrCreateProfile()
    }

    var userName: String {
        let name = profile.firstName
        return name.isEmpty ? "Friend" : name
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning, \(userName).\nLet's start with God."
        case 12..<17:
            return "Hey \(userName).\nTake a breath. He's here."
        case 17..<21:
            return "\(userName), let's wind down\nwith God tonight."
        default:
            return "\(userName), rest in\nHis peace."
        }
    }

    var currentTheme: ThemeDefinition {
        ThemeDefinition.allThemes.first { $0.id == profile.selectedThemeID }
            ?? ThemeDefinition.allThemes[0]
    }

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.feedEngine = FeedEngine(modelContext: modelContext)
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        loadSavedState()
        loadInitialFeed()
    }

    // MARK: - Feed Loading

    func loadInitialFeed() {
        pruneExpiredShownIDs()
        let newCards = feedEngine.generateFeed(
            for: profile,
            count: batchSize,
            excluding: shownIDs
        )
        cards = newCards
        markAsShown(newCards)
    }

    func loadMoreIfNeeded() {
        guard currentIndex >= cards.count - prefetchThreshold else { return }
        guard !isLoadingMore else { return }

        isLoadingMore = true
        pruneExpiredShownIDs()

        let newCards = feedEngine.generateFeed(
            for: profile,
            count: batchSize,
            excluding: shownIDs
        )

        cards.append(contentsOf: newCards)
        markAsShown(newCards)
        isLoadingMore = false
    }

    // MARK: - Navigation

    func onSwipe(to index: Int) {
        currentIndex = index

        if index > 0 && showGreeting {
            showGreeting = false
        }

        loadMoreIfNeeded()
    }

    // MARK: - Interactions

    func toggleSave(for content: PrayerContent) {
        content.isSaved.toggle()
        if content.isSaved {
            savedContentIDs.insert(content.id)
        } else {
            savedContentIDs.remove(content.id)
        }
        try? modelContext.save()
        HapticService.lightImpact()
    }

    func doubleTapSave(for content: PrayerContent) {
        if !content.isSaved {
            content.isSaved = true
            savedContentIDs.insert(content.id)
            try? modelContext.save()
        }
        doubleTapHeartID = content.id
        HapticService.impact(.medium)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self?.doubleTapHeartID == content.id {
                self?.doubleTapHeartID = nil
            }
        }
    }

    func isSaved(_ content: PrayerContent) -> Bool {
        content.isSaved
    }

    /// Replace {name} tokens in template text with user's first name
    func personalizedText(for content: PrayerContent) -> String {
        content.templateText.replacingOccurrences(of: "{name}", with: userName)
    }

    func shareCard(_ content: PrayerContent) {
        shareContent = content
        HapticService.impact(.medium)
    }

    func askAI(about content: PrayerContent) {
        askAIContent = content
        HapticService.selection()
    }

    func askAIPrompt(for content: PrayerContent) -> String {
        let text = personalizedText(for: content)
        if let ref = content.verseReference, !ref.isEmpty {
            return "Walk me through this verse and help me understand what God is saying to me: \"\(text)\" — \(ref)"
        }
        return "This really spoke to me. Can you help me go deeper? \"\(text)\""
    }

    func pinToCollection(_ content: PrayerContent) {
        if !content.isSaved {
            content.isSaved = true
            savedContentIDs.insert(content.id)
            try? modelContext.save()
        }
        collectionContent = content
        HapticService.selection()
    }

    // MARK: - Private

    private func markAsShown(_ items: [PrayerContent]) {
        let now = Date()
        for item in items {
            shownIDs.insert(item.id)
            shownIDTimestamps[item.id] = now
        }
    }

    private func pruneExpiredShownIDs() {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        shownIDTimestamps = shownIDTimestamps.filter { $0.value > cutoff }
        shownIDs = Set(shownIDTimestamps.keys)
    }

    private func loadSavedState() {
        let descriptor = FetchDescriptor<PrayerContent>(
            predicate: #Predicate { $0.isSaved == true }
        )
        if let saved = try? modelContext.fetch(descriptor) {
            savedContentIDs = Set(saved.map(\.id))
        }
    }
}
