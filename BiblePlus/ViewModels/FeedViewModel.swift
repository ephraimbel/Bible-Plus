import Foundation
import SwiftData

@MainActor
@Observable
final class FeedViewModel {
    // MARK: - State

    var cards: [PrayerContent] = []
    var currentIndex: Int = 0
    var showFeed: Bool = false
    var isLoadingMore: Bool = false
    var savedContentIDs: Set<UUID> = []
    var doubleTapHeartID: UUID? = nil
    var shareContent: PrayerContent? = nil
    var collectionContent: PrayerContent? = nil
    var deepLinkScrollIndex: Int? = nil

    // Streak state
    var streakCount: Int = 0
    var showStreakCelebration: Bool = false
    var streakMilestone: StreakService.MilestoneType? = nil

    // MARK: - Private

    private var shownIDs: Set<UUID> = []
    private var shownIDTimestamps: [UUID: Date] = [:]
    private let batchSize: Int = 20
    private let prefetchThreshold: Int = 5

    private let feedEngine: FeedEngine
    private let personalizationService: PersonalizationService
    private let streakService: StreakService
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

    var greetingLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<21: return "Good evening,"
        default: return "Rest well,"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var userInitial: String {
        String(userName.prefix(1)).uppercased()
    }

    var streakText: String? {
        if streakCount >= 2 {
            return "\(streakCount)-day streak"
        }
        return "My Progress"
    }

    /// Returns which Calendar weekdays (1=Sun … 7=Sat) the user was active this week.
    var activeDaysThisWeek: Set<Int> {
        ActivityService.activeDaysThisWeek(in: modelContext)
    }

    var currentTheme: ThemeDefinition {
        ThemeDefinition.allThemes.first { $0.id == profile.selectedThemeID }
            ?? ThemeDefinition.allThemes[0]
    }

    var currentBackground: SanctuaryBackground {
        SanctuaryBackground.background(for: profile.selectedBackgroundID)
            ?? SanctuaryBackground.allBackgrounds[0]
    }

    // MARK: - Dashboard Data

    var dailyVerse: (text: String, reference: String)? {
        let popularVerses: [(text: String, reference: String)] = [
            ("For God so loved the world, that he gave his only born Son, that whoever believes in him should not perish, but have eternal life.", "John 3:16 (WEB)"),
            ("Trust in Yahweh with all your heart, and don’t lean on your own understanding.", "Proverbs 3:5 (WEB)"),
            ("I can do all things through Christ who strengthens me.", "Philippians 4:13 (WEB)"),
            ("Yahweh is my shepherd; I shall lack nothing.", "Psalm 23:1 (WEB)"),
            ("Haven’t I commanded you? Be strong and courageous. Don’t be afraid. Don’t be dismayed, for Yahweh your God is with you wherever you go.”", "Joshua 1:9 (WEB)"),
            ("We know that all things work together for good for those who love God, for those who are called according to his purpose.", "Romans 8:28 (WEB)"),
            ("casting all your worries on him, because he cares for you.", "1 Peter 5:7 (WEB)"),
            ("Yahweh is my light and my salvation. Whom shall I fear? Yahweh is the strength of my life. Of whom shall I be afraid?", "Psalm 27:1 (WEB)"),
            ("but those who wait for Yahweh will renew their strength. They will mount up with wings like eagles. They will run, and not be weary. They will walk, and not faint.", "Isaiah 40:31 (WEB)"),
            ("“Come to me, all you who labor and are heavily burdened, and I will give you rest.", "Matthew 11:28 (WEB)"),
            ("For I know the thoughts that I think toward you,” says Yahweh, “thoughts of peace, and not of evil, to give you hope and a future.", "Jeremiah 29:11 (WEB)"),
            ("“Be still, and know that I am God. I will be exalted among the nations. I will be exalted on the earth.”", "Psalm 46:10 (WEB)"),
            ("Yahweh is near to those who have a broken heart, and saves those who have a crushed spirit.", "Psalm 34:18 (WEB)"),
            ("Create in me a clean heart, O God. Renew a right spirit within me.", "Psalm 51:10 (WEB)"),
            ("He has made everything beautiful in its time. He has also set eternity in their hearts, yet so that man can’t find out the work that God has done from the beginning even to the end.", "Ecclesiastes 3:11 (WEB)"),
            ("‘Yahweh bless you, and keep you.", "Numbers 6:24 (WEB)"),
            ("Your word is a lamp to my feet, and a light for my path.", "Psalm 119:105 (WEB)"),
            ("Peace I leave with you. My peace I give to you; not as the world gives, I give to you. Don’t let your heart be troubled, neither let it be fearful.", "John 14:27 (WEB)"),
            ("Then he said to them, “Go your way. Eat the fat, drink the sweet, and send portions to him for whom nothing is prepared, for today is holy to our Lord. Don’t be grieved, for the joy of Yahweh is your strength.”", "Nehemiah 8:10 (WEB)"),
            ("Draw near to God, and he will draw near to you. Cleanse your hands, you sinners. Purify your hearts, you double-minded.", "James 4:8 (WEB)"),
            ("In all your ways acknowledge him, and he will make your paths straight.", "Proverbs 3:6 (WEB)"),
        ]
        // Date-seeded index so it changes daily
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % popularVerses.count
        return popularVerses[index]
    }

    var activeReadingPlan: (name: String, day: Int, total: Int)? {
        let descriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let progress = try? modelContext.fetch(descriptor).first else { return nil }

        let planDescriptor = FetchDescriptor<ReadingPlan>()
        guard let plans = try? modelContext.fetch(planDescriptor) else { return nil }
        guard let plan = plans.first(where: { $0.id == progress.planID }) else { return nil }

        let nextDay = progress.nextDay(totalDays: plan.totalDays)
        return (name: plan.name, day: nextDay, total: plan.totalDays)
    }

    var continueReading: (bookName: String, chapter: Int, verse: Int, totalChapters: Int)? {
        let p = profile
        // Don't show if still at default position (Genesis 1:1)
        if p.lastReadBookID == "GEN" && p.lastReadChapter == 1 && p.lastReadVerseNumber <= 1 {
            return nil
        }
        guard let book = BibleData.allBooks.first(where: { $0.id == p.lastReadBookID }) else { return nil }
        return (bookName: book.name, chapter: p.lastReadChapter, verse: p.lastReadVerseNumber, totalChapters: book.chapterCount)
    }

    /// Most recently saved/pinned PrayerContent title (or short text). Used by
    /// the Home dashboard's "Saved" quick-action tile to show what to come
    /// back to. Returns nil when the user has nothing saved yet.
    var latestSavedTitle: String? {
        var descriptor = FetchDescriptor<PrayerContent>(
            predicate: #Predicate { $0.isSaved == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let content = try? modelContext.fetch(descriptor).first else { return nil }
        // Prefer the verse reference if it's a verse card; otherwise the
        // first few words of the body so the tile reads like a real bookmark.
        if let ref = content.verseReference, !ref.isEmpty {
            return ref
        }
        let body = content.templateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = body.split(separator: " ").prefix(4).joined(separator: " ")
        return words.isEmpty ? nil : "\(words)\u{2026}"
    }

    /// Total saved count — drives the empty-state copy on the Saved tile.
    var savedCount: Int {
        let descriptor = FetchDescriptor<PrayerContent>(
            predicate: #Predicate { $0.isSaved == true }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Reading Plans for Dashboard

    var dashboardReadingPlans: [ReadingPlan] {
        let descriptor = FetchDescriptor<ReadingPlan>(sortBy: [SortDescriptor(\.name)])
        let plans = (try? modelContext.fetch(descriptor)) ?? []
        // Show up to 4 plans: free ones first, then Pro
        let free = plans.filter { !$0.isProOnly }
        let pro = plans.filter { $0.isProOnly }
        return Array((free + pro).prefix(4))
    }

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.feedEngine = FeedEngine(modelContext: modelContext)
        self.personalizationService = PersonalizationService(modelContext: modelContext)
        self.streakService = StreakService(modelContext: modelContext)
        loadSavedState()
        loadInitialFeed()
        checkStreak()
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
        loadMoreIfNeeded()
    }

    func navigateToContent(id: UUID) {
        let wasShowingFeed = showFeed

        // Check if content is already in cards
        if let index = cards.firstIndex(where: { $0.id == id }) {
            showFeed = true
            if wasShowingFeed {
                deepLinkScrollIndex = index
            } else {
                // Delay so FeedPagingView has time to appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.deepLinkScrollIndex = index
                }
            }
            return
        }

        // Fetch from SwiftData and insert at position 0
        let descriptor = FetchDescriptor<PrayerContent>(
            predicate: #Predicate { $0.id == id }
        )
        if let content = try? modelContext.fetch(descriptor).first {
            cards.insert(content, at: 0)
            // Mark the deep-linked card as shown so a later `loadMoreIfNeeded`
            // (which generates with `excluding: shownIDs`) can't re-emit the
            // same content and append a duplicate — two cards sharing an `.id`
            // breaks the feed's ForEach and the paging scroll position.
            markAsShown([content])
            showFeed = true
            if wasShowingFeed {
                deepLinkScrollIndex = 0
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.deepLinkScrollIndex = 0
                }
            }
        }
    }

    // MARK: - Interactions

    func toggleSave(for content: PrayerContent) {
        content.isSaved.toggle()
        if content.isSaved {
            savedContentIDs.insert(content.id)
            Analytics.track(.feedCardLiked, properties: ["category": content.category])
        } else {
            savedContentIDs.remove(content.id)
        }
        modelContext.safeSave()
        HapticService.lightImpact()
    }

    func doubleTapSave(for content: PrayerContent) {
        if !content.isSaved {
            content.isSaved = true
            savedContentIDs.insert(content.id)
            modelContext.safeSave()
            Analytics.track(.feedCardLiked, properties: ["category": content.category])
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
        Analytics.track(.feedCardShared, properties: ["category": content.category])
        HapticService.impact(.medium)
    }

    func askAI(about content: PrayerContent) {
        HapticService.selection()
        // Route through the unified Ask flow: ContentView creates the
        // conversation, switches to the Ask tab and pushes ChatView (tab bar
        // hidden, back → conversation list) — consistent with every other
        // "Ask" entry point.
        NotificationCenter.default.post(
            name: .openAIWithContext,
            object: nil,
            userInfo: [
                "context": askAIPrompt(for: content),
                "title": String(personalizedText(for: content).prefix(40)),
            ]
        )
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
            modelContext.safeSave()
        }
        collectionContent = content
        HapticService.selection()
    }

    // MARK: - Streak

    func dismissStreakCelebration() {
        showStreakCelebration = false
    }

    private func checkStreak() {
        let result = streakService.checkAndUpdateStreak()
        streakCount = result.currentStreak
        streakMilestone = result.milestoneType
        if result.isNewDay {
            showStreakCelebration = true
            // Ask for review at streak milestones (3, 7, etc.)
            if result.currentStreak == 3 || result.isMilestone {
                ReviewService.shared.requestIfAppropriate()
            }
        }
    }

    // MARK: - Feed Refresh

    func refreshFeed() {
        cards = []
        shownIDs = []
        shownIDTimestamps = [:]
        currentIndex = 0
        showFeed = false
        isLoadingMore = false
        loadInitialFeed()
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
