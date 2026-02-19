#if DEBUG
import Foundation
import SwiftData

/// Populates the database with realistic mock data simulating 38 days of active usage.
/// DEBUG only — used for generating App Store screenshots.
@MainActor
enum MockDataService {

    static func populate(in context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        // MARK: - Update Profile

        let profileDescriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(profileDescriptor).first else { return }

        profile.firstName = "Sarah"
        profile.isPro = true
        profile.streakCount = 12
        profile.longestStreak = 18
        profile.lastActiveDate = today
        profile.lastReadBookID = "ROM"
        profile.lastReadChapter = 8
        profile.lastReadVerseNumber = 28
        profile.aiConversationCount = 24

        // MARK: - Activity Events (38 days)

        // Clear existing activity events
        let existingEvents = FetchDescriptor<ActivityEvent>()
        if let events = try? context.fetch(existingEvents) {
            for event in events { context.delete(event) }
        }

        let eventTypes: [(ActivityEventType, String)] = [
            (.appOpened, ""),
            (.chapterRead, "Romans 8"),
            (.verseSaved, "Philippians 4:13"),
            (.aiChatSent, "Prayer for peace"),
            (.prayerWritten, "Morning gratitude"),
            (.planDayCompleted, "Psalms of Peace"),
            (.verseHighlighted, "John 3:16"),
            (.audioChapterCompleted, "Psalm 23"),
        ]

        for daysAgo in 0..<38 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            // App opened every day
            let openEvent = ActivityEvent(type: .appOpened, detail: "")
            openEvent.createdAt = randomTime(on: date, hour: 7)
            context.insert(openEvent)

            // 2-5 additional events per day
            let extraCount = Int.random(in: 2...5)
            for i in 0..<extraCount {
                let (type, detail) = eventTypes[Int.random(in: 0..<eventTypes.count)]
                if type == .appOpened { continue }
                let event = ActivityEvent(type: type, detail: detail)
                event.createdAt = randomTime(on: date, hour: 8 + i * 3)
                context.insert(event)
            }
        }

        // Skip a few days to break streak realistically (days 13-14 ago)
        let skip1 = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { event in
                event.detail == "" || event.detail != ""
            }
        )
        if let all = try? context.fetch(skip1) {
            for event in all {
                let daysAgo = calendar.dateComponents([.day], from: event.createdAt, to: today).day ?? 0
                if daysAgo == 13 || daysAgo == 14 || daysAgo == 25 {
                    context.delete(event)
                }
            }
        }

        // MARK: - Prayer Journal Entries (12 entries over 38 days)

        let existingPrayers = FetchDescriptor<PrayerEntry>()
        if let prayers = try? context.fetch(existingPrayers) {
            for p in prayers { context.delete(p) }
        }

        let prayerEntries: [(String, String, PrayerCategory, Int, Bool)] = [
            ("Morning Gratitude", "Thank You, Lord, for another day of breath and purpose. I\u{2019}m grateful for my family, for the quiet moments before the world wakes up, and for Your faithfulness that never fails.", .gratitude, 2, false),
            ("Peace Over Anxiety", "Father, I\u{2019}m carrying so much worry about work and finances. Help me lay it at Your feet. Replace my anxious thoughts with Your perfect peace. I trust You are my provider.", .petition, 5, false),
            ("Forgiveness Prayer", "Lord, I confess I\u{2019}ve been holding resentment in my heart. Soften me. Help me forgive as You have forgiven me. I don\u{2019}t want bitterness to take root.", .confession, 8, false),
            ("Praise for Answered Prayer", "You answered my prayer about the job situation! The interview went so well and I can see Your hand in every detail. You are faithful and good.", .praise, 10, true),
            ("Healing for Mom", "Please lay Your healing hand on Mom. The doctors say the recovery will be long, but I know You are the Great Physician. Surround her with comfort and strength.", .intercession, 12, false),
            ("Processing Loss", "I miss Grandpa so much. Some days the grief hits me like a wave. But I find comfort knowing he\u{2019}s with You. Help me honor his memory by living with the same faith he had.", .lament, 15, false),
            ("Thankful Heart", "Three things I\u{2019}m grateful for today: the sunset walk with my dog, a kind word from a stranger, and the verse that met me exactly where I needed it \u{2014} Psalm 46:10.", .gratitude, 18, false),
            ("Direction & Purpose", "God, I feel so lost about what\u{2019}s next. Close the doors that aren\u{2019}t from You and open the ones that are. Give me courage to walk through them.", .petition, 21, false),
            ("Prayer for My Marriage", "Strengthen us, Lord. We\u{2019}ve been distant lately and I know the enemy wants to divide us. Help us choose love, patience, and grace with each other every single day.", .intercession, 24, false),
            ("Confession & Freedom", "I gave in to temptation again. I feel ashamed, but I know Your grace is bigger than my failure. Help me build better habits and accountability. I want to be free.", .confession, 28, false),
            ("Breakthrough Praise", "The medical results came back clear! God, You heard every prayer. You held us through the uncertainty. I will praise You in every season.", .praise, 30, true),
            ("New Season Prayer", "As I step into this new chapter, go before me. Prepare the way. Surround me with people who sharpen my faith. I\u{2019}m scared, but I choose trust.", .petition, 35, false),
        ]

        for (title, body, category, daysAgo, answered) in prayerEntries {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let entry = PrayerEntry(title: title, body: body, category: category)
            entry.createdAt = randomTime(on: date, hour: Int.random(in: 6...21))
            entry.updatedAt = entry.createdAt
            if answered {
                entry.isAnswered = true
                entry.answeredAt = calendar.date(byAdding: .day, value: 3, to: date)
                entry.answerNotes = "God is so faithful!"
            }
            context.insert(entry)
        }

        // MARK: - Conversations & Messages (4 conversations)

        let existingConvos = FetchDescriptor<Conversation>()
        if let convos = try? context.fetch(existingConvos) {
            for c in convos { context.delete(c) }
        }
        let existingMsgs = FetchDescriptor<ChatMessage>()
        if let msgs = try? context.fetch(existingMsgs) {
            for m in msgs { context.delete(m) }
        }

        let conversations: [(String, Int, [(String, String)])] = [
            ("What does Romans 8:28 mean?", 3, [
                ("user", "Can you explain Romans 8:28 in simple terms?"),
                ("assistant", "Romans 8:28 says \u{201C}And we know that in all things God works for the good of those who love him, who have been called according to his purpose.\u{201D}\n\nThis verse is a powerful promise that God is always at work in your life \u{2014} even in the hard seasons. It doesn\u{2019}t mean everything that happens is good, but that God can bring good out of every situation for those who love Him."),
                ("user", "That\u{2019}s beautiful. How do I apply this when things feel hopeless?"),
                ("assistant", "When life feels hopeless, this verse invites you to shift your perspective from \u{201C}Why is this happening?\u{201D} to \u{201C}What might God be doing through this?\u{201D}\n\nPractically, you can:\n\u{2022} Journal about past situations where God brought good from pain\n\u{2022} Pray and surrender your current struggle to Him\n\u{2022} Trust that His timeline is different from yours\n\nRemember, you don\u{2019}t need to see the full picture to trust the Artist."),
            ]),
            ("Pray with me about anxiety", 8, [
                ("user", "I\u{2019}m feeling really anxious about a big decision. Can you pray with me?"),
                ("assistant", "I\u{2019}d be honored to pray with you.\n\n\u{1F64F} Heavenly Father,\n\nWe come before You with a heart that feels heavy with uncertainty. You see the decision ahead and You already know the path. We ask for Your peace that surpasses all understanding to guard this heart and mind.\n\nGive wisdom and clarity. Quiet the noise of fear and replace it with confidence in Your plan. We trust that You go before us and make the crooked paths straight.\n\nIn Jesus\u{2019} name, Amen.\n\n\u{1F4D6} Philippians 4:6-7 \u{2014} \u{201C}Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.\u{201D}"),
            ]),
            ("How to forgive someone", 15, [
                ("user", "How does the Bible say we should forgive people who hurt us?"),
                ("assistant", "Forgiveness is one of the most challenging but transformative teachings in Scripture. Here are key passages:\n\n1. **Ephesians 4:32** \u{2014} \u{201C}Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.\u{201D}\n\n2. **Matthew 6:14-15** \u{2014} Jesus ties our forgiveness from God to our willingness to forgive others.\n\n3. **Colossians 3:13** \u{2014} \u{201C}Bear with each other and forgive one another if any of you has a grievance against someone.\u{201D}\n\nForgiveness isn\u{2019}t saying what happened was okay. It\u{2019}s releasing the hold that pain has on your heart so God can heal you."),
            ]),
            ("Daily encouragement", 1, [
                ("user", "I need some encouragement today. Things have been really tough."),
                ("assistant", "I\u{2019}m glad you reached out. Here\u{2019}s what I want you to know today:\n\n\u{2728} **You are seen.** God knows exactly where you are and what you\u{2019}re facing (Psalm 139:1-4).\n\n\u{1F4AA} **You are stronger than you think.** \u{201C}I can do all things through Christ who strengthens me\u{201D} (Philippians 4:13).\n\n\u{2764}\u{FE0F} **You are loved unconditionally.** Nothing can separate you from God\u{2019}s love (Romans 8:38-39).\n\nTough seasons don\u{2019}t last forever, but the growth they produce does. You\u{2019}re being refined, not rejected. Keep going \u{2014} dawn is coming."),
            ]),
        ]

        for (title, daysAgo, messages) in conversations {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let convo = Conversation(title: title)
            convo.createdAt = randomTime(on: date, hour: 10)
            convo.updatedAt = convo.createdAt
            context.insert(convo)

            for (i, (role, content)) in messages.enumerated() {
                let msg = ChatMessage(
                    conversationId: convo.id,
                    role: role == "user" ? .user : .assistant,
                    content: content
                )
                msg.createdAt = calendar.date(byAdding: .minute, value: i * 2, to: convo.createdAt) ?? convo.createdAt
                context.insert(msg)
            }
        }

        // MARK: - Favorite some feed content

        let contentDescriptor = FetchDescriptor<PrayerContent>()
        if let allContent = try? context.fetch(contentDescriptor) {
            // Favorite 8 random items
            let shuffled = allContent.shuffled()
            for item in shuffled.prefix(8) {
                item.isSaved = true
            }
        }

        // MARK: - Reading Plan Progress

        let existingProgress = FetchDescriptor<UserPlanProgress>()
        if let progress = try? context.fetch(existingProgress) {
            for p in progress { context.delete(p) }
        }

        // Active plan: "Psalms of Peace" — day 5 of 7
        let planDescriptor = FetchDescriptor<ReadingPlan>()
        if let plans = try? context.fetch(planDescriptor) {
            if let psalmsPlan = plans.first(where: { $0.name.contains("Psalms") }) {
                let progress = UserPlanProgress(planID: psalmsPlan.id)
                progress.startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
                progress.completedDays = [1, 2, 3, 4, 5]
                progress.lastReadDate = calendar.date(byAdding: .day, value: -1, to: today)
                progress.isActive = true
                context.insert(progress)
            }
        }

        // MARK: - Collection

        let existingCollections = FetchDescriptor<ContentCollection>()
        if let collections = try? context.fetch(existingCollections) {
            for c in collections { context.delete(c) }
        }

        let savedContent = FetchDescriptor<PrayerContent>(
            predicate: #Predicate { $0.isSaved == true }
        )
        let savedIDs = (try? context.fetch(savedContent))?.prefix(5).map(\.id) ?? []

        let collection = ContentCollection(name: "Morning Prayers")
        collection.contentIDs = Array(savedIDs)
        collection.createdAt = calendar.date(byAdding: .day, value: -20, to: today) ?? today
        context.insert(collection)

        let collection2 = ContentCollection(name: "Verses for Hard Days")
        collection2.contentIDs = Array((try? context.fetch(savedContent))?.suffix(3).map(\.id) ?? [])
        collection2.createdAt = calendar.date(byAdding: .day, value: -10, to: today) ?? today
        context.insert(collection2)

        // MARK: - Save

        try? context.save()
    }

    // MARK: - Helpers

    private static func randomTime(on date: Date, hour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = min(hour, 23)
        components.minute = Int.random(in: 0...59)
        return calendar.date(from: components) ?? date
    }
}
#endif
