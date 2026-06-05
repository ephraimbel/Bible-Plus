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
        ("Be still, and know that I am God.", "Psalm 46:10")
    }

    private func pickDailyVerse() -> (text: String, reference: String) {
        let verses: [(String, String)] = [
            ("Be still, and know that I am God.", "Psalm 46:10"),
            ("The Lord is my shepherd; I shall not want.", "Psalm 23:1"),
            ("Cast thy burden upon the Lord, and he shall sustain thee.", "Psalm 55:22"),
            ("Trust in the Lord with all thine heart; and lean not unto thine own understanding.", "Proverbs 3:5"),
            ("I can do all things through Christ which strengtheneth me.", "Philippians 4:13"),
            ("Come unto me, all ye that labour and are heavy laden, and I will give you rest.", "Matthew 11:28"),
            ("For God so loved the world, that he gave his only begotten Son.", "John 3:16"),
            ("Weeping may endure for a night, but joy cometh in the morning.", "Psalm 30:5"),
            ("And we know that all things work together for good to them that love God.", "Romans 8:28"),
            ("The steadfast love of the Lord never ceases; his mercies never come to an end.", "Lamentations 3:22"),
            ("Be strong and courageous. Do not be afraid; do not be discouraged.", "Joshua 1:9"),
            ("My grace is sufficient for thee: for my strength is made perfect in weakness.", "2 Corinthians 12:9"),
            ("The Lord is near to all who call on him, to all who call on him in truth.", "Psalm 145:18"),
            ("In all your ways acknowledge him, and he shall direct thy paths.", "Proverbs 3:6"),
            ("Have I not commanded you? Be strong and of a good courage.", "Joshua 1:9"),
            ("Fear thou not; for I am with thee: be not dismayed; for I am thy God.", "Isaiah 41:10"),
            ("The Lord is my light and my salvation; whom shall I fear?", "Psalm 27:1"),
            ("This is the day which the Lord hath made; we will rejoice and be glad in it.", "Psalm 118:24"),
            ("Delight thyself also in the Lord; and he shall give thee the desires of thine heart.", "Psalm 37:4"),
            ("Let not your heart be troubled: ye believe in God, believe also in me.", "John 14:1"),
            ("Greater is he that is in you, than he that is in the world.", "1 John 4:4"),
            ("If God be for us, who can be against us?", "Romans 8:31"),
            ("The Lord shall fight for you, and ye shall hold your peace.", "Exodus 14:14"),
            ("Wait on the Lord: be of good courage, and he shall strengthen thine heart.", "Psalm 27:14"),
            ("They that wait upon the Lord shall renew their strength.", "Isaiah 40:31"),
            ("Casting all your care upon him; for he careth for you.", "1 Peter 5:7"),
            ("Be careful for nothing; but in every thing by prayer and supplication... let your requests be made known unto God.", "Philippians 4:6"),
            ("And the peace of God, which passeth all understanding, shall keep your hearts and minds.", "Philippians 4:7"),
            ("Whatsoever things are true, whatsoever things are honest, whatsoever things are just... think on these things.", "Philippians 4:8"),
            ("Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me.", "Psalm 23:4"),
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
