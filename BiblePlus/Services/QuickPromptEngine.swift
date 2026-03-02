import Foundation
import SwiftData

// MARK: - Quick Prompt Model

struct QuickPrompt {
    let icon: String
    let text: String
    let category: PromptCategory
    let burdens: Set<Burden>
    let seasons: Set<LifeSeason>
    let faithLevels: Set<FaithLevel>
    let timeSlots: Set<PrayerTimeSlot>
    let topics: Set<String>

    init(
        icon: String,
        text: String,
        category: PromptCategory,
        burdens: Set<Burden> = [],
        seasons: Set<LifeSeason> = [],
        faithLevels: Set<FaithLevel> = [],
        timeSlots: Set<PrayerTimeSlot> = [],
        topics: Set<String> = []
    ) {
        self.icon = icon
        self.text = text
        self.category = category
        self.burdens = burdens
        self.seasons = seasons
        self.faithLevels = faithLevels
        self.timeSlots = timeSlots
        self.topics = topics
    }
}

// MARK: - Quick Prompt Engine

enum QuickPromptEngine {

    // MARK: - Public API

    /// Selects prompts for the user based on their profile, chat history, and optional category filter.
    static func selectPrompts(
        for profile: UserProfile,
        category: PromptCategory? = nil,
        chatTopics: [String: Int] = [:],
        count: Int = 4
    ) -> [(icon: String, text: String)] {
        if let category {
            // Category mode: top N from selected category
            let pool = allPrompts.filter { $0.category == category }
            let scored = pool.map { (prompt: $0, score: score($0, profile: profile, chatTopics: chatTopics)) }
            let sorted = scored.sorted { $0.score > $1.score }
            return sorted.prefix(count).map { resolve($0.prompt, profile: profile) }
        }

        // Default mode: top 1 from each category
        return PromptCategory.allCases.compactMap { cat in
            let pool = allPrompts.filter { $0.category == cat }
            let scored = pool.map { (prompt: $0, score: score($0, profile: profile, chatTopics: chatTopics)) }
            return scored.max(by: { $0.score < $1.score }).map { resolve($0.prompt, profile: profile) }
        }
    }

    /// Scans recent user messages to extract topic keywords.
    static func extractRecentTopics(from modelContext: ModelContext, limit: Int = 50) -> [String: Int] {
        var descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 2 // Fetch a small multiple to account for non-user messages
        let messages = (try? modelContext.fetch(descriptor)) ?? []
        let userMessages = messages.filter { $0.role == .user }.prefix(limit)

        var topicCounts: [String: Int] = [:]
        for message in userMessages {
            let lower = message.content.lowercased()
            for (keyword, tags) in topicKeywords {
                if lower.contains(keyword) {
                    for tag in tags {
                        topicCounts[tag, default: 0] += 1
                    }
                }
            }
        }
        return topicCounts
    }

    // MARK: - Scoring

    private static func score(_ prompt: QuickPrompt, profile: UserProfile, chatTopics: [String: Int]) -> Double {
        var score: Double = 1.0
        let userBurdens = Set(profile.currentBurdens)
        let userSeasons = Set(profile.lifeSeasons)

        // Burden: 3x boost for match, 0.3x penalty for mismatch (only if prompt is tagged)
        if !prompt.burdens.isEmpty {
            if !userBurdens.intersection(prompt.burdens).isEmpty {
                score *= 3.0
            } else {
                score *= 0.3
            }
        }

        // Season: 2x boost for match, 0.4x penalty for mismatch
        if !prompt.seasons.isEmpty {
            if !userSeasons.intersection(prompt.seasons).isEmpty {
                score *= 2.0
            } else {
                score *= 0.4
            }
        }

        // Time of day: 1.5x boost, 0.5x penalty
        if !prompt.timeSlots.isEmpty {
            let currentSlot = FeedEngine.currentTimeSlot()
            if prompt.timeSlots.contains(currentSlot) {
                score *= 1.5
            } else {
                score *= 0.5
            }
        }

        // Faith level: 1.3x boost, 0.4x penalty
        if !prompt.faithLevels.isEmpty {
            if prompt.faithLevels.contains(profile.faithLevel) {
                score *= 1.3
            } else {
                score *= 0.4
            }
        }

        // Chat topic: up to 2.25x boost based on matched topics
        if !prompt.topics.isEmpty && !chatTopics.isEmpty {
            var topicBoost: Double = 0
            for topic in prompt.topics {
                if let count = chatTopics[topic] {
                    topicBoost += min(Double(count), 3.0) * 0.25
                }
            }
            if topicBoost > 0 {
                score *= min(1.0 + topicBoost, 2.25)
            }
        }

        // Random jitter: 0.7–1.3x (wider than feed for more variety)
        score *= Double.random(in: 0.7...1.3)

        return score
    }

    // MARK: - Token Resolution

    private static func resolve(_ prompt: QuickPrompt, profile: UserProfile) -> (icon: String, text: String) {
        var text = prompt.text
        let name = profile.firstName.isEmpty ? "Friend" : profile.firstName
        text = text.replacingOccurrences(of: "{name}", with: name)

        let burden = profile.currentBurdens.first ?? .none
        if burden != .none {
            text = text.replacingOccurrences(of: "{burden}", with: burden.displayName.lowercased())
        } else {
            // Skip prompts that require a burden token when user has none
            text = text.replacingOccurrences(of: "{burden}", with: "what's weighing on you")
        }

        let season = profile.lifeSeasons.first
        if let season {
            text = text.replacingOccurrences(of: "{season}", with: season.displayName.lowercased())
        } else {
            text = text.replacingOccurrences(of: "{season}", with: "this season of life")
        }

        return (icon: prompt.icon, text: text)
    }

    // MARK: - Topic Keywords (~60 keywords → topic tags)

    static let topicKeywords: [String: [String]] = [
        // Relationships
        "marriage": ["marriage", "relationship"],
        "husband": ["marriage", "relationship"],
        "wife": ["marriage", "relationship"],
        "spouse": ["marriage", "relationship"],
        "divorce": ["marriage", "relationship", "heartbreak"],
        "dating": ["relationship", "dating"],
        "boyfriend": ["relationship", "dating"],
        "girlfriend": ["relationship", "dating"],
        "friend": ["friendship", "relationship"],
        "friendship": ["friendship", "relationship"],
        "family": ["family", "relationship"],
        "parent": ["parenting", "family"],
        "child": ["parenting", "family"],
        "children": ["parenting", "family"],

        // Emotions & struggles
        "anxious": ["anxiety", "mental-health"],
        "anxiety": ["anxiety", "mental-health"],
        "worry": ["anxiety", "worry"],
        "depressed": ["depression", "mental-health"],
        "depression": ["depression", "mental-health"],
        "lonely": ["loneliness"],
        "loneliness": ["loneliness"],
        "angry": ["anger"],
        "anger": ["anger"],
        "grief": ["grief", "loss"],
        "loss": ["grief", "loss"],
        "death": ["grief", "loss"],
        "fear": ["fear", "anxiety"],
        "afraid": ["fear", "anxiety"],
        "stress": ["stress", "anxiety"],
        "overwhelm": ["stress", "anxiety"],
        "tempt": ["temptation"],
        "temptation": ["temptation"],
        "doubt": ["doubt", "faith"],
        "forgive": ["forgiveness"],
        "forgiveness": ["forgiveness"],

        // Life & purpose
        "purpose": ["purpose", "calling"],
        "calling": ["purpose", "calling"],
        "career": ["work", "purpose"],
        "job": ["work", "purpose"],
        "work": ["work"],
        "money": ["finances"],
        "financial": ["finances"],
        "debt": ["finances"],
        "health": ["health"],
        "sick": ["health", "healing"],
        "healing": ["health", "healing"],
        "suffering": ["suffering", "pain"],
        "pain": ["suffering", "pain"],

        // Faith topics
        "pray": ["prayer"],
        "prayer": ["prayer"],
        "faith": ["faith"],
        "trust": ["trust", "faith"],
        "grace": ["grace", "theology"],
        "salvation": ["salvation", "theology"],
        "sin": ["sin", "repentance"],
        "repent": ["sin", "repentance"],
        "worship": ["worship"],
        "gratitude": ["gratitude", "thankfulness"],
        "thankful": ["gratitude", "thankfulness"],
        "hope": ["hope"],
        "peace": ["peace"],
        "joy": ["joy"],
        "love": ["love"],
        "patience": ["patience"],
    ]

    // MARK: - Prompt Pool (~120 prompts)

    static let allPrompts: [QuickPrompt] = scripturePrompts + prayerPrompts + guidancePrompts + theologyPrompts

    // MARK: Scripture (~30)

    private static let scripturePrompts: [QuickPrompt] = [
        // Universal
        QuickPrompt(icon: "book.fill", text: "What should I read today?", category: .scripture),
        QuickPrompt(icon: "text.magnifyingglass", text: "Break down a tough passage for me", category: .scripture),
        QuickPrompt(icon: "sparkles", text: "Surprise me with something powerful", category: .scripture),
        QuickPrompt(icon: "star.fill", text: "What's a lesser-known gem in the Bible?", category: .scripture),
        QuickPrompt(icon: "text.book.closed", text: "Summarize a book of the Bible for me", category: .scripture),
        QuickPrompt(icon: "list.number", text: "Give me a Bible reading plan for this week", category: .scripture),

        // Burden-tagged
        QuickPrompt(icon: "bookmark.fill", text: "Find me a verse for {burden}", category: .scripture,
                    burdens: [.anxiety, .grief, .doubt, .loneliness, .anger, .temptation, .health, .financial, .relationship, .purpose]),
        QuickPrompt(icon: "heart.text.square", text: "Scriptures for peace when I feel anxious", category: .scripture,
                    burdens: [.anxiety], topics: ["anxiety", "peace"]),
        QuickPrompt(icon: "drop.fill", text: "Verses for comfort in grief and loss", category: .scripture,
                    burdens: [.grief], topics: ["grief", "loss"]),
        QuickPrompt(icon: "shield.fill", text: "Bible verses about overcoming doubt", category: .scripture,
                    burdens: [.doubt], topics: ["doubt", "faith"]),
        QuickPrompt(icon: "person.fill.checkmark", text: "Verses that remind me I'm not alone", category: .scripture,
                    burdens: [.loneliness], topics: ["loneliness"]),
        QuickPrompt(icon: "flame.fill", text: "What does the Bible say about anger?", category: .scripture,
                    burdens: [.anger], topics: ["anger"]),
        QuickPrompt(icon: "exclamationmark.shield.fill", text: "Verses for resisting temptation", category: .scripture,
                    burdens: [.temptation], topics: ["temptation"]),
        QuickPrompt(icon: "cross.case.fill", text: "Healing scriptures for my body and mind", category: .scripture,
                    burdens: [.health], topics: ["health", "healing"]),
        QuickPrompt(icon: "dollarsign.circle.fill", text: "What does God say about finances?", category: .scripture,
                    burdens: [.financial], topics: ["finances"]),
        QuickPrompt(icon: "heart.slash", text: "Verses for heartbreak and relationship pain", category: .scripture,
                    burdens: [.relationship], topics: ["relationship", "heartbreak"]),
        QuickPrompt(icon: "compass.drawing", text: "Scriptures about finding my purpose", category: .scripture,
                    burdens: [.purpose], topics: ["purpose", "calling"]),

        // Season-tagged
        QuickPrompt(icon: "graduationcap.fill", text: "What should a student read in the Bible?", category: .scripture,
                    seasons: [.student]),
        QuickPrompt(icon: "briefcase.fill", text: "Verses about work and integrity", category: .scripture,
                    seasons: [.workingProfessional], topics: ["work"]),
        QuickPrompt(icon: "figure.and.child.holdinghands", text: "Scriptures for parents raising kids", category: .scripture,
                    seasons: [.parent], topics: ["parenting", "family"]),
        QuickPrompt(icon: "heart.circle.fill", text: "Verses about marriage and love", category: .scripture,
                    seasons: [.married], topics: ["marriage", "love"]),
        QuickPrompt(icon: "sunrise.fill", text: "Verses about new beginnings", category: .scripture,
                    seasons: [.startingOver], topics: ["hope"]),

        // Time-tagged
        QuickPrompt(icon: "sunrise", text: "A morning verse to start my day", category: .scripture,
                    timeSlots: [.morning]),
        QuickPrompt(icon: "moon.stars", text: "A bedtime verse to end my day peacefully", category: .scripture,
                    timeSlots: [.bedtime], topics: ["peace"]),
        QuickPrompt(icon: "sun.max.fill", text: "A midday Scripture pick-me-up", category: .scripture,
                    timeSlots: [.midday]),

        // Faith-level tagged
        QuickPrompt(icon: "sparkles", text: "Where should a beginner start reading the Bible?", category: .scripture,
                    faithLevels: [.justCurious]),
        QuickPrompt(icon: "arrow.up.right", text: "What are the key chapters every Christian should know?", category: .scripture,
                    faithLevels: [.growing]),
        QuickPrompt(icon: "text.magnifyingglass", text: "Help me do a deep word study on a verse", category: .scripture,
                    faithLevels: [.deepInTheWord]),

        // Topic-tagged
        QuickPrompt(icon: "hands.clap.fill", text: "Verses about forgiveness and letting go", category: .scripture,
                    topics: ["forgiveness"]),
        QuickPrompt(icon: "leaf.fill", text: "What does the Bible say about patience?", category: .scripture,
                    topics: ["patience"]),
        QuickPrompt(icon: "sun.max.fill", text: "Verses about joy in hard times", category: .scripture,
                    topics: ["joy", "suffering"]),
    ]

    // MARK: Prayer (~30)

    private static let prayerPrompts: [QuickPrompt] = [
        // Universal
        QuickPrompt(icon: "hands.sparkles", text: "Pray with me right now", category: .prayer),
        QuickPrompt(icon: "hand.raised.fill", text: "Help me write a prayer of gratitude", category: .prayer, topics: ["gratitude"]),
        QuickPrompt(icon: "person.wave.2.fill", text: "Write a prayer I can share with someone", category: .prayer),
        QuickPrompt(icon: "text.quote", text: "Turn a Psalm into a personal prayer", category: .prayer),
        QuickPrompt(icon: "checkmark.seal.fill", text: "A prayer of surrender and trust", category: .prayer, topics: ["trust", "faith"]),
        QuickPrompt(icon: "arrow.clockwise.heart.fill", text: "Help me pray for someone I'm struggling with", category: .prayer, topics: ["forgiveness"]),

        // Burden-tagged
        QuickPrompt(icon: "cloud.rain.fill", text: "A prayer for peace in my anxiety", category: .prayer,
                    burdens: [.anxiety], topics: ["anxiety", "peace"]),
        QuickPrompt(icon: "heart.slash.fill", text: "A prayer for comfort in my grief", category: .prayer,
                    burdens: [.grief], topics: ["grief"]),
        QuickPrompt(icon: "questionmark.circle.fill", text: "A prayer for faith when I'm doubting", category: .prayer,
                    burdens: [.doubt], topics: ["doubt", "faith"]),
        QuickPrompt(icon: "person.crop.circle.badge.minus", text: "A prayer for when I feel alone", category: .prayer,
                    burdens: [.loneliness], topics: ["loneliness"]),
        QuickPrompt(icon: "flame", text: "A prayer to release my anger to God", category: .prayer,
                    burdens: [.anger], topics: ["anger"]),
        QuickPrompt(icon: "exclamationmark.triangle.fill", text: "A prayer for strength against temptation", category: .prayer,
                    burdens: [.temptation], topics: ["temptation"]),
        QuickPrompt(icon: "cross.case", text: "A prayer for healing and restoration", category: .prayer,
                    burdens: [.health], topics: ["health", "healing"]),
        QuickPrompt(icon: "dollarsign.circle", text: "A prayer for God's provision in finances", category: .prayer,
                    burdens: [.financial], topics: ["finances"]),
        QuickPrompt(icon: "person.2.slash", text: "A prayer for my broken relationship", category: .prayer,
                    burdens: [.relationship], topics: ["relationship"]),
        QuickPrompt(icon: "compass.drawing", text: "A prayer for direction and purpose", category: .prayer,
                    burdens: [.purpose], topics: ["purpose", "calling"]),

        // Season-tagged
        QuickPrompt(icon: "graduationcap", text: "A student's prayer for wisdom and focus", category: .prayer,
                    seasons: [.student]),
        QuickPrompt(icon: "briefcase", text: "A prayer for my work and calling", category: .prayer,
                    seasons: [.workingProfessional], topics: ["work"]),
        QuickPrompt(icon: "figure.and.child.holdinghands", text: "A parent's prayer for my children", category: .prayer,
                    seasons: [.parent], topics: ["parenting", "family"]),
        QuickPrompt(icon: "heart", text: "A prayer for my singleness", category: .prayer,
                    seasons: [.single]),
        QuickPrompt(icon: "heart.circle", text: "A prayer for my marriage", category: .prayer,
                    seasons: [.married], topics: ["marriage"]),
        QuickPrompt(icon: "water.waves", text: "A prayer for endurance in this hard season", category: .prayer,
                    seasons: [.hardSeason], topics: ["suffering"]),
        QuickPrompt(icon: "sunrise", text: "A prayer for new beginnings and fresh starts", category: .prayer,
                    seasons: [.startingOver], topics: ["hope"]),

        // Time-tagged
        QuickPrompt(icon: "sunrise.fill", text: "Start my day with a morning prayer", category: .prayer,
                    timeSlots: [.morning]),
        QuickPrompt(icon: "moon.stars.fill", text: "Help me write a bedtime prayer", category: .prayer,
                    timeSlots: [.bedtime]),
        QuickPrompt(icon: "sun.max", text: "A midday prayer to refocus my heart", category: .prayer,
                    timeSlots: [.midday]),
        QuickPrompt(icon: "moon.fill", text: "An evening prayer of reflection", category: .prayer,
                    timeSlots: [.evening]),

        // Faith-level tagged
        QuickPrompt(icon: "sparkles", text: "I'm new to prayer \u{2014} help me get started", category: .prayer,
                    faithLevels: [.justCurious]),
        QuickPrompt(icon: "arrow.up.heart.fill", text: "How can I deepen my prayer life?", category: .prayer,
                    faithLevels: [.growing]),
        QuickPrompt(icon: "book.closed.fill", text: "Teach me to pray using Scripture", category: .prayer,
                    faithLevels: [.deepInTheWord]),
    ]

    // MARK: Guidance (~30)

    private static let guidancePrompts: [QuickPrompt] = [
        // Universal
        QuickPrompt(icon: "arrow.triangle.branch", text: "Help me think through a decision biblically", category: .guidance),
        QuickPrompt(icon: "figure.walk", text: "How do I grow closer to God?", category: .guidance, topics: ["faith"]),
        QuickPrompt(icon: "person.crop.circle.badge.checkmark", text: "How do I know God's will for my life?", category: .guidance, topics: ["purpose"]),
        QuickPrompt(icon: "bubble.left.and.bubble.right.fill", text: "How do I hear God's voice?", category: .guidance, topics: ["faith", "prayer"]),
        QuickPrompt(icon: "heart.fill", text: "How can I love others better?", category: .guidance, topics: ["love"]),
        QuickPrompt(icon: "arrow.clockwise", text: "How do I bounce back when I fall?", category: .guidance, topics: ["sin", "repentance"]),

        // Burden-tagged
        QuickPrompt(icon: "heart.fill", text: "I'm dealing with {burden} \u{2014} what does God say?", category: .guidance,
                    burdens: [.anxiety, .grief, .doubt, .loneliness, .anger, .temptation, .health, .financial, .relationship, .purpose]),
        QuickPrompt(icon: "cloud.rain", text: "How do I trust God when anxiety overwhelms me?", category: .guidance,
                    burdens: [.anxiety], topics: ["anxiety", "trust"]),
        QuickPrompt(icon: "heart.slash", text: "How do I grieve with hope?", category: .guidance,
                    burdens: [.grief], topics: ["grief", "hope"]),
        QuickPrompt(icon: "questionmark.circle", text: "Is it okay to have doubts about faith?", category: .guidance,
                    burdens: [.doubt], topics: ["doubt"]),
        QuickPrompt(icon: "person.fill", text: "How do I find community when I'm lonely?", category: .guidance,
                    burdens: [.loneliness], topics: ["loneliness"]),
        QuickPrompt(icon: "flame", text: "How do I handle anger in a godly way?", category: .guidance,
                    burdens: [.anger], topics: ["anger"]),
        QuickPrompt(icon: "shield.checkered", text: "How do I break free from temptation?", category: .guidance,
                    burdens: [.temptation], topics: ["temptation"]),
        QuickPrompt(icon: "cross.case", text: "How do I find peace when facing health problems?", category: .guidance,
                    burdens: [.health], topics: ["health", "peace"]),
        QuickPrompt(icon: "dollarsign.circle", text: "What does the Bible say about financial wisdom?", category: .guidance,
                    burdens: [.financial], topics: ["finances"]),
        QuickPrompt(icon: "person.2", text: "How do I repair a broken relationship?", category: .guidance,
                    burdens: [.relationship], topics: ["relationship", "forgiveness"]),
        QuickPrompt(icon: "compass.drawing", text: "How do I discover my God-given purpose?", category: .guidance,
                    burdens: [.purpose], topics: ["purpose", "calling"]),

        // Season-tagged
        QuickPrompt(icon: "graduationcap", text: "How do I keep my faith strong as a student?", category: .guidance,
                    seasons: [.student]),
        QuickPrompt(icon: "briefcase", text: "How do I honor God in my workplace?", category: .guidance,
                    seasons: [.workingProfessional], topics: ["work"]),
        QuickPrompt(icon: "figure.and.child.holdinghands", text: "How do I teach my children about God?", category: .guidance,
                    seasons: [.parent], topics: ["parenting"]),
        QuickPrompt(icon: "heart", text: "How do I find contentment in singleness?", category: .guidance,
                    seasons: [.single]),
        QuickPrompt(icon: "heart.circle", text: "How do I strengthen my marriage spiritually?", category: .guidance,
                    seasons: [.married], topics: ["marriage"]),
        QuickPrompt(icon: "leaf.circle", text: "How do I pass on my faith to the next generation?", category: .guidance,
                    seasons: [.retired]),
        QuickPrompt(icon: "water.waves", text: "How do I find God in the middle of suffering?", category: .guidance,
                    seasons: [.hardSeason], topics: ["suffering"]),
        QuickPrompt(icon: "sunrise", text: "How do I start over with God?", category: .guidance,
                    seasons: [.startingOver], topics: ["hope"]),

        // Topic-tagged
        QuickPrompt(icon: "hands.clap", text: "How do I truly forgive someone who hurt me?", category: .guidance,
                    topics: ["forgiveness"]),
        QuickPrompt(icon: "shield.fill", text: "What does the Bible say about fear?", category: .guidance,
                    topics: ["fear"]),
        QuickPrompt(icon: "person.3.fill", text: "How do I build godly friendships?", category: .guidance,
                    topics: ["friendship", "relationship"]),
        QuickPrompt(icon: "trophy.fill", text: "What does it mean to live a victorious life?", category: .guidance,
                    topics: ["faith", "hope"]),
    ]

    // MARK: Theology (~30)

    private static let theologyPrompts: [QuickPrompt] = [
        // Universal
        QuickPrompt(icon: "lightbulb.fill", text: "Explain grace to me simply", category: .theology, topics: ["grace"]),
        QuickPrompt(icon: "questionmark.circle", text: "Help me understand the Trinity", category: .theology),
        QuickPrompt(icon: "text.book.closed", text: "Old vs New Covenant \u{2014} what changed?", category: .theology),
        QuickPrompt(icon: "brain.head.profile", text: "Why does God allow suffering?", category: .theology, topics: ["suffering"]),
        QuickPrompt(icon: "cross.fill", text: "What does the cross really mean?", category: .theology, topics: ["salvation"]),
        QuickPrompt(icon: "globe.americas.fill", text: "How do creation and science fit together?", category: .theology),

        // Faith-level tagged
        QuickPrompt(icon: "sparkles", text: "What is the gospel in simple terms?", category: .theology,
                    faithLevels: [.justCurious], topics: ["salvation"]),
        QuickPrompt(icon: "person.fill.questionmark", text: "Who is Jesus and why does He matter?", category: .theology,
                    faithLevels: [.justCurious]),
        QuickPrompt(icon: "book.fill", text: "What's the Bible about in one conversation?", category: .theology,
                    faithLevels: [.justCurious]),
        QuickPrompt(icon: "arrow.up.right", text: "What are the core beliefs of Christianity?", category: .theology,
                    faithLevels: [.justCurious, .growing]),
        QuickPrompt(icon: "figure.walk", text: "How do I share my faith with others?", category: .theology,
                    faithLevels: [.growing]),
        QuickPrompt(icon: "bubble.left.and.text.bubble.right.fill", text: "Explain predestination vs free will", category: .theology,
                    faithLevels: [.deepInTheWord]),
        QuickPrompt(icon: "scroll.fill", text: "What are the different views on end times?", category: .theology,
                    faithLevels: [.deepInTheWord]),
        QuickPrompt(icon: "text.magnifyingglass", text: "Walk me through a biblical Greek or Hebrew word", category: .theology,
                    faithLevels: [.deepInTheWord]),

        // Burden-tagged
        QuickPrompt(icon: "brain.head.profile", text: "Why does God let me struggle with {burden}?", category: .theology,
                    burdens: [.anxiety, .grief, .doubt, .loneliness, .anger, .health, .financial, .relationship]),
        QuickPrompt(icon: "shield.checkered", text: "What does the Bible teach about spiritual warfare?", category: .theology,
                    burdens: [.temptation], topics: ["temptation"]),

        // Topic-tagged
        QuickPrompt(icon: "drop.fill", text: "What does baptism symbolize?", category: .theology),
        QuickPrompt(icon: "cup.and.saucer.fill", text: "Why is communion important?", category: .theology),
        QuickPrompt(icon: "clock.fill", text: "What happens when we die?", category: .theology, topics: ["grief", "hope"]),
        QuickPrompt(icon: "hand.raised.fill", text: "What is the Holy Spirit's role?", category: .theology),
        QuickPrompt(icon: "scale.3d", text: "How can God be just and merciful at the same time?", category: .theology, topics: ["grace"]),
        QuickPrompt(icon: "arrow.triangle.2.circlepath", text: "What does it mean to be born again?", category: .theology, topics: ["salvation"]),
        QuickPrompt(icon: "book.closed.fill", text: "How was the Bible put together?", category: .theology),
        QuickPrompt(icon: "figure.walk.diamond.fill", text: "What does the Bible say about angels and demons?", category: .theology),
        QuickPrompt(icon: "hands.sparkles.fill", text: "What are spiritual gifts and do I have them?", category: .theology, topics: ["worship"]),
        QuickPrompt(icon: "building.columns.fill", text: "Why are there so many denominations?", category: .theology),
        QuickPrompt(icon: "globe.europe.africa.fill", text: "What does the Bible say about justice?", category: .theology),
        QuickPrompt(icon: "heart.text.square.fill", text: "What does it really mean to love your neighbor?", category: .theology, topics: ["love"]),
        QuickPrompt(icon: "leaf.arrow.circlepath", text: "What does the Bible say about rest and sabbath?", category: .theology, topics: ["peace"]),
        QuickPrompt(icon: "star.fill", text: "What are the parables and why did Jesus use them?", category: .theology),
    ]
}
