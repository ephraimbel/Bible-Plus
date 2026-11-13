import SwiftUI
import SwiftData

/// The conversation empty state — what users see every time they open a fresh
/// conversation in Ask. Designed as a "today" magazine cover, not a chatbot
/// landing page. Sections, top to bottom:
///
///   1. Greeting (small, restrained)
///   2. HERO — today's verse with full-bleed biblical art
///   3. Reading plan continuation (only if the user has an active plan)
///   4. Continue exploring — recent conversation topics from memory
///   5. Begin anew — Story Mode + Guided Prayer rows + curated prompts
///
/// Premium principles enforced here:
///   - Editorial typography (serif body, small caps section labels) over icons
///   - Generous whitespace
///   - One hero per screen
///   - No emoji, minimal SF Symbols (only where they aid recognition)
struct QuickPromptsView: View {
    let prompts: [(icon: String, text: String)]
    let userName: String
    let categories: [PromptCategory]
    @Binding var selectedCategory: PromptCategory?
    var currentMode: ConversationMode? = nil
    let onTap: (String) -> Void
    var onSelectMode: ((ConversationMode) -> Void)? = nil
    var onSelectCharacter: ((BiblicalCharacter) -> Void)? = nil
    var onSelectEmotion: ((ChatEmotion) -> Void)? = nil
    var onGuidedPrayer: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil

    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false
    @State private var todayData: TodayData? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                greeting
                heroVerseCard

                if let plan = todayData?.activePlan {
                    planCard(plan)
                }

                if let topics = todayData?.recentTopics, !topics.isEmpty {
                    continueExploringSection(topics)
                }

                beginAnewSection

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            await loadTodayData()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timeBasedGreeting)
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(userName)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(BPAnimation.spring.delay(0.05), value: appeared)
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "GOOD MORNING"
        case 12..<17: return "GOOD AFTERNOON"
        case 17..<22: return "GOOD EVENING"
        default: return "PEACE TO YOU"
        }
    }

    // MARK: - Hero Verse Card

    private var heroVerseCard: some View {
        let verse = todayData?.dailyVerse ?? defaultVerse
        let imageKey = todayData?.dailyImageKey ?? "creation_light"

        return Button {
            HapticService.lightImpact()
            onTap("Help me sit with this verse: \"\(verse.text)\" — \(verse.reference)")
        } label: {
            VStack(spacing: 0) {
                // Full-bleed art at the top
                Group {
                    if let uiImage = BiblicalImageService.rawImage(for: imageKey) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            // Soft top vignette for cinematic depth
                            .overlay(alignment: .top) {
                                LinearGradient(
                                    colors: [.black.opacity(0.14), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 60)
                                .allowsHitTesting(false)
                            }
                            // Bottom fade — image dissolves seamlessly into
                            // the verse text block below. Ends at the EXACT
                            // tone of the text section background so there
                            // is no visible seam at the join.
                            .overlay(alignment: .bottom) {
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        palette.surfaceElevated.opacity(0.6),
                                        palette.surfaceElevated,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 80)
                                .allowsHitTesting(false)
                            }
                    } else {
                        BiblicalImageService.fallbackGradient(for: imageKey)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                    }
                }

                // Editorial verse block beneath
                VStack(alignment: .leading, spacing: 18) {
                    Text("VERSE FOR TODAY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(palette.accent.opacity(0.7))

                    Text(verse.text)
                        .font(.system(size: 21, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textPrimary)
                        .lineSpacing(7)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(palette.accent.opacity(0.4))
                            .frame(width: 18, height: 1)
                        Text(verse.reference)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(palette.accent)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surfaceElevated)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(BPAnimation.spring.delay(0.12), value: appeared)
    }

    // MARK: - Reading Plan Continuation Card

    private func planCard(_ plan: PlanInfo) -> some View {
        Button {
            HapticService.lightImpact()
            NotificationCenter.default.post(name: .init("openPlans"), object: nil)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("READING PLAN")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(palette.accent.opacity(0.7))
                    Spacer()
                    Text("Day \(plan.nextDay) of \(plan.totalDays)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                }

                Text(plan.planName)
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)

                // Hairline progress bar — no chunky chrome
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.accent.opacity(0.10))
                            .frame(height: 3)
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: max(6, geo.size.width * plan.progress), height: 3)
                    }
                }
                .frame(height: 3)

                HStack(spacing: 6) {
                    Text("Continue today's reading")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent.opacity(0.7))
                }
                .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.18), value: appeared)
    }

    // MARK: - Continue Exploring Section

    private func continueExploringSection(_ topics: [TopicInfo]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("CONTINUE EXPLORING")

            VStack(spacing: 10) {
                ForEach(Array(topics.enumerated()), id: \.element.topic) { index, topic in
                    topicRow(topic)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(
                            BPAnimation.spring.delay(0.22 + Double(index) * 0.05),
                            value: appeared
                        )
                }
            }
        }
    }

    private func topicRow(_ topic: TopicInfo) -> some View {
        Button {
            HapticService.lightImpact()
            onTap(topic.prompt)
        } label: {
            HStack(spacing: 14) {
                // Editorial number marker — no icon
                Text(topic.depthLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent.opacity(0.6))
                    .frame(width: 60, alignment: .leading)

                Rectangle()
                    .fill(palette.border.opacity(0.2))
                    .frame(width: 0.5, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)

                    Text(topic.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textMuted.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Begin Anew Section

    private var beginAnewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("OR BEGIN ANEW")

            VStack(spacing: 10) {
                suggestionRow(
                    icon: "book.pages.fill",
                    title: "Story Mode",
                    subtitle: "Stand inside a biblical scene"
                ) {
                    onSelectMode?(.story)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(BPAnimation.spring.delay(0.30), value: appeared)

                suggestionRow(
                    icon: "wand.and.stars",
                    title: "Guided Prayer",
                    subtitle: "Build a prayer step by step"
                ) {
                    onGuidedPrayer?()
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(BPAnimation.spring.delay(0.34), value: appeared)

                ForEach(Array(prompts.prefix(3).enumerated()), id: \.element.text) { index, prompt in
                    suggestionRow(
                        icon: prompt.icon,
                        title: prompt.text
                    ) {
                        onTap(prompt.text)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(
                        BPAnimation.spring.delay(0.38 + Double(index) * 0.04),
                        value: appeared
                    )
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.textMuted.opacity(0.7))
            Rectangle()
                .fill(palette.border.opacity(0.15))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Suggestion Row (preserved for the begin-anew section)

    private func suggestionRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: subtitle != nil ? 3 : 0) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5, design: .serif))
                            .italic()
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.border.opacity(0.5), lineWidth: 0.7)
            )
        }
    }

    // MARK: - Today Data Loading

    @MainActor
    private func loadTodayData() async {
        let verse = pickDailyVerse()
        let imageKey = BiblicalImageService.resolveKey(
            for: "",
            context: verse.text + " " + verse.reference
        )

        // Active reading plan (first one if multiple)
        let progressDescriptor = FetchDescriptor<UserPlanProgress>(
            predicate: #Predicate { $0.isActive == true }
        )
        let activeProgress = (try? modelContext.fetch(progressDescriptor)) ?? []

        var planInfo: PlanInfo? = nil
        if let progress = activeProgress.first {
            let planID = progress.planID
            let planDescriptor = FetchDescriptor<ReadingPlan>(
                predicate: #Predicate { $0.id == planID }
            )
            if let plan = (try? modelContext.fetch(planDescriptor))?.first {
                planInfo = PlanInfo(
                    planID: plan.id,
                    planName: plan.name,
                    nextDay: progress.nextDay(totalDays: plan.totalDays),
                    totalDays: plan.totalDays,
                    progress: progress.completionFraction(totalDays: plan.totalDays)
                )
            }
        }

        // Recent conversation topics (3 most recent)
        var topicDescriptor = FetchDescriptor<ConversationTopic>(
            sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
        )
        topicDescriptor.fetchLimit = 3
        let topics = (try? modelContext.fetch(topicDescriptor)) ?? []

        let topicInfos = topics.map { topic -> TopicInfo in
            let title = topic.topic
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            let depthLabel: String
            switch topic.depth {
            case .deep: depthLabel = "DEEP"
            case .explored: depthLabel = "EXPLORED"
            case .surface: depthLabel = "RECENT"
            }
            return TopicInfo(
                topic: topic.topic,
                title: title,
                subtitle: "Touched \(topic.mentionCount) \(topic.mentionCount == 1 ? "time" : "times")",
                depthLabel: depthLabel,
                prompt: "Let's go deeper on \(title.lowercased())."
            )
        }

        todayData = TodayData(
            dailyVerse: verse,
            dailyImageKey: imageKey,
            activePlan: planInfo,
            recentTopics: topicInfos
        )
    }

    // MARK: - Daily Verse Pool

    private var defaultVerse: (text: String, reference: String) {
        ("“Be still, and know that I am God. I will be exalted among the nations. I will be exalted on the earth.”", "Psalm 46:10 (WEB)")
    }

    private func pickDailyVerse() -> (text: String, reference: String) {
        let verses: [(String, String)] = [
            ("“Be still, and know that I am God. I will be exalted among the nations. I will be exalted on the earth.”", "Psalm 46:10 (WEB)"),
            ("Yahweh is my shepherd; I shall lack nothing.", "Psalm 23:1 (WEB)"),
            ("Cast your burden on Yahweh and he will sustain you. He will never allow the righteous to be moved.", "Psalm 55:22 (WEB)"),
            ("Trust in Yahweh with all your heart, and don’t lean on your own understanding.", "Proverbs 3:5 (WEB)"),
            ("I can do all things through Christ who strengthens me.", "Philippians 4:13 (WEB)"),
            ("“Come to me, all you who labor and are heavily burdened, and I will give you rest.", "Matthew 11:28 (WEB)"),
            ("For God so loved the world, that he gave his only born Son, that whoever believes in him should not perish, but have eternal life.", "John 3:16 (WEB)"),
            ("For his anger is but for a moment. His favor is for a lifetime. Weeping may stay for the night, but joy comes in the morning.", "Psalm 30:5 (WEB)"),
            ("We know that all things work together for good for those who love God, for those who are called according to his purpose.", "Romans 8:28 (WEB)"),
            ("It is because of Yahweh’s loving kindnesses that we are not consumed, because his mercies don’t fail.", "Lamentations 3:22 (WEB)"),
            ("Haven’t I commanded you? Be strong and courageous. Don’t be afraid. Don’t be dismayed, for Yahweh your God is with you wherever you go.”", "Joshua 1:9 (WEB)"),
            ("He has said to me, “My grace is sufficient for you, for my power is made perfect in weakness.” Most gladly therefore I will rather glory in my weaknesses, that the power of Christ may rest on me.", "2 Corinthians 12:9 (WEB)"),
            ("Yahweh is near to all those who call on him, to all who call on him in truth.", "Psalm 145:18 (WEB)"),
            ("In all your ways acknowledge him, and he will make your paths straight.", "Proverbs 3:6 (WEB)"),
            ("Haven’t I commanded you? Be strong and courageous. Don’t be afraid. Don’t be dismayed, for Yahweh your God is with you wherever you go.”", "Joshua 1:9 (WEB)"),
            ("Don’t you be afraid, for I am with you. Don’t be dismayed, for I am your God. I will strengthen you. Yes, I will help you. Yes, I will uphold you with the right hand of my righteousness.", "Isaiah 41:10 (WEB)"),
            ("Yahweh is my light and my salvation. Whom shall I fear? Yahweh is the strength of my life. Of whom shall I be afraid?", "Psalm 27:1 (WEB)"),
            ("This is the day that Yahweh has made. We will rejoice and be glad in it!", "Psalm 118:24 (WEB)"),
            ("Also delight yourself in Yahweh, and he will give you the desires of your heart.", "Psalm 37:4 (WEB)"),
            ("“Don’t let your heart be troubled. Believe in God. Believe also in me.", "John 14:1 (WEB)"),
            ("You are of God, little children, and have overcome them, because greater is he who is in you than he who is in the world.", "1 John 4:4 (WEB)"),
            ("What then shall we say about these things? If God is for us, who can be against us?", "Romans 8:31 (WEB)"),
            ("Yahweh will fight for you, and you shall be still.”", "Exodus 14:14 (WEB)"),
            ("Wait for Yahweh. Be strong, and let your heart take courage. Yes, wait for Yahweh.", "Psalm 27:14 (WEB)"),
            ("but those who wait for Yahweh will renew their strength. They will mount up with wings like eagles. They will run, and not be weary. They will walk, and not faint.", "Isaiah 40:31 (WEB)"),
            ("casting all your worries on him, because he cares for you.", "1 Peter 5:7 (WEB)"),
            ("In nothing be anxious, but in everything, by prayer and petition with thanksgiving, let your requests be made known to God.", "Philippians 4:6 (WEB)"),
            ("And the peace of God, which surpasses all understanding, will guard your hearts and your thoughts in Christ Jesus.", "Philippians 4:7 (WEB)"),
            ("Finally, brothers, whatever things are true, whatever things are honorable, whatever things are just, whatever things are pure, whatever things are lovely, whatever things are of good report: if there is any virtue and if there is anything worthy of praise, think about these things.", "Philippians 4:8 (WEB)"),
            ("Even though I walk through the valley of the shadow of death, I will fear no evil, for you are with me. Your rod and your staff, they comfort me.", "Psalm 23:4 (WEB)"),
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return verses[day % verses.count]
    }

    // MARK: - Data Types

    private struct TodayData {
        let dailyVerse: (text: String, reference: String)
        let dailyImageKey: String
        let activePlan: PlanInfo?
        let recentTopics: [TopicInfo]
    }

    private struct PlanInfo {
        let planID: String
        let planName: String
        let nextDay: Int
        let totalDays: Int
        let progress: Double
    }

    private struct TopicInfo {
        let topic: String
        let title: String
        let subtitle: String
        let depthLabel: String
        let prompt: String
    }
}
