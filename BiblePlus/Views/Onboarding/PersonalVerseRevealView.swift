import SwiftUI
import SwiftData

// MARK: - Personal Verse Reveal
//
// The "aha moment" that lands between burdens and notifications. By this
// point the user has told us their name, faith stage, seasons, and burdens.
// We show them a verse scored specifically for that profile — character by
// character, treated like a gift. The reveal converts the user's mental
// state from "being onboarded" to "having already received something," so
// the subsequent paywall stops selling features and starts selling more of
// what just happened.
//
// Visual arc:
//   1. Dark field opens. Gold radial bloom from center (1.2s).
//   2. Personalized opener types in ("{Name}, here's a word for this season.").
//   3. Gold hairline draws across.
//   4. Verse reveals character-by-character at 35ms/char.
//   5. Reference fades in, ornament settles, CTAs slide up.
//
// The whole sequence runs about 5–6s. Users who stay through it self-select
// into a higher-intent funnel; users who tap "Keep this with me" advance
// with the verse favorited (seeds day-1 retention).

struct PersonalVerseRevealView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    @State private var stage: Stage = .opening
    @State private var currentVerse: PersonalVerse = .placeholder
    @State private var revealedChars: Int = 0
    @State private var bloomOpacity: Double = 0
    @State private var openerOpacity: Double = 0
    @State private var hairlineProgress: CGFloat = 0
    @State private var referenceOpacity: Double = 0
    @State private var ornamentOpacity: Double = 0
    @State private var primaryButtonOpacity: Double = 0
    @State private var secondaryButtonOpacity: Double = 0
    @State private var primaryButtonOffset: CGFloat = 30
    @State private var versePool: [PersonalVerse] = []
    @State private var versePoolIndex: Int = 0
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var hasStarted = false

    private enum Stage { case opening, typing, complete }

    private let goldLight = Color(red: 1.0, green: 0.88, blue: 0.5)
    private let gold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        ZStack {
            // Dark field — always under everything
            Color.black.opacity(0.94).ignoresSafeArea()

            // Layer: soft biblical image through heavy blur for depth
            Image("biblical_jacob_ladder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 48)
                .scaleEffect(1.2)
                .opacity(0.25)
                .clipped()
                .ignoresSafeArea()

            // Layer: gold radial bloom from center (this is the "breath")
            RadialGradient(
                colors: [gold.opacity(0.35), gold.opacity(0.12), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .opacity(bloomOpacity)
            .ignoresSafeArea()

            // Layer: drifting gold motes (decorative, respects reduce-motion)
            if !reduceMotion {
                DriftingMotesLayer(color: goldLight.opacity(0.6))
                    .opacity(bloomOpacity * 0.8)
                    .allowsHitTesting(false)
            }

            // Content
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                content
                    .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            begin()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    // MARK: - Content Stack

    private var content: some View {
        VStack(spacing: 28) {
            // Opener — intimate tone, italic, low-key
            Text(openerText)
                .font(.custom("Georgia-Italic", size: 17))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(openerOpacity)
                .fixedSize(horizontal: false, vertical: true)

            // Hairline that draws across before the verse arrives
            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, gold.opacity(0.7), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * hairlineProgress, height: 0.6)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 0.6)

            // Verse — the main event
            Text(verseDisplay)
                .font(.custom("Georgia", size: 24))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            // Ornament + reference
            VStack(spacing: 10) {
                // Ornament: dot – line – diamond – line – dot
                HStack(spacing: 6) {
                    Circle().fill(gold.opacity(0.5)).frame(width: 3, height: 3)
                    Rectangle().fill(gold.opacity(0.35)).frame(width: 20, height: 0.5)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 4, weight: .light))
                        .foregroundStyle(gold.opacity(0.6))
                    Rectangle().fill(gold.opacity(0.35)).frame(width: 20, height: 0.5)
                    Circle().fill(gold.opacity(0.5)).frame(width: 3, height: 3)
                }
                .opacity(ornamentOpacity)

                Text(currentVerse.reference)
                    .font(.custom("Georgia-Italic", size: 14))
                    .tracking(0.5)
                    .foregroundStyle(gold.opacity(0.85))
                    .opacity(referenceOpacity)
            }

            Spacer().frame(height: 8)

            // Primary CTA — "Keep this with me"
            Button {
                keepVerseAndAdvance()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Keep this with me")
                        .font(.custom("Georgia-Bold", size: 16))
                        .tracking(0.3)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [gold, gold.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: gold.opacity(0.35), radius: 16, y: 6)
                )
                .overlay(
                    Capsule()
                        .stroke(goldLight.opacity(0.4), lineWidth: 0.5)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(primaryButtonOpacity)
            .offset(y: primaryButtonOffset)

            // Secondary — "Show me another"
            Button {
                resampleVerse()
            } label: {
                Text("Show me another")
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .underline(true, color: .white.opacity(0.2))
            }
            .opacity(secondaryButtonOpacity)
        }
    }

    // MARK: - Display Helpers

    private var openerText: String {
        let name = viewModel.firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty
            ? "Here's a word for this season."
            : "\(name), here's a word for this season."
    }

    private var verseDisplay: String {
        guard revealedChars > 0 else { return " " }
        let text = currentVerse.text
        let idx = text.index(text.startIndex, offsetBy: min(revealedChars, text.count))
        return String(text[text.startIndex..<idx])
    }

    // MARK: - Animation Choreography

    private func begin() {
        // Populate the verse pool scored against the user's profile.
        versePool = PersonalVerseSelector.pool(
            viewModel: viewModel,
            modelContext: modelContext
        )
        versePoolIndex = 0
        currentVerse = versePool.first ?? .fallback(for: viewModel.selectedBurdens)

        // Keep the ambient loop playing THROUGH the verse reveal and into
        // the paywall — the continuous score makes the handoff feel like
        // one polished cinematic, while the abrupt cut to silence here
        // was breaking the emotional through-line users expected.

        Analytics.track(.personalVerseRevealShown, properties: [
            "reference": currentVerse.reference,
        ])

        animationTask = Task { @MainActor in
            await runChoreography()
        }
    }

    @MainActor
    private func runChoreography() async {
        // 1. Gold bloom rises from the center
        withAnimation(.easeOut(duration: 1.2)) { bloomOpacity = 1 }
        guard await wait(0.45) else { return }

        // Soft haptic as the bloom peaks
        HapticService.chipTap()
        guard await wait(0.4) else { return }

        // 2. Opener fades in
        withAnimation(.easeOut(duration: 0.6)) { openerOpacity = 1 }
        guard await wait(0.7) else { return }

        // 3. Hairline draws across
        withAnimation(.easeInOut(duration: 0.9)) { hairlineProgress = 0.65 }
        guard await wait(0.5) else { return }

        // 4. Verse reveals character by character
        stage = .typing
        let text = currentVerse.text
        let charDelay: UInt64 = 34_000_000 // 34ms per char
        for i in 1...text.count {
            try? await Task.sleep(nanoseconds: charDelay)
            if Task.isCancelled { return }
            revealedChars = i
        }

        // Short beat after last character
        guard await wait(0.35) else { return }

        // Success haptic — the moment it lands
        HapticService.commit()
        Analytics.track(.personalVerseRevealCompleted, properties: [
            "reference": currentVerse.reference,
        ])

        // 5. Reference + ornament fade in
        withAnimation(.easeOut(duration: 0.55)) { ornamentOpacity = 1 }
        guard await wait(0.15) else { return }
        withAnimation(.easeOut(duration: 0.55)) { referenceOpacity = 1 }
        guard await wait(0.5) else { return }

        // 6. Primary button slides up
        stage = .complete
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            primaryButtonOpacity = 1
            primaryButtonOffset = 0
        }
        guard await wait(0.35) else { return }

        // 7. Secondary button fades in
        withAnimation(.easeOut(duration: 0.4)) { secondaryButtonOpacity = 1 }
    }

    @MainActor
    private func wait(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    // MARK: - Actions

    private func keepVerseAndAdvance() {
        HapticService.consecrate()
        Analytics.track(.personalVerseRevealKept, properties: [
            "reference": currentVerse.reference,
        ])
        // Mark the verse as favorited on its PrayerContent record so it lands
        // in the user's saved collection on day 1.
        PersonalVerseSelector.markKept(id: currentVerse.contentId, modelContext: modelContext)

        // Fade the whole screen out before handing off.
        withAnimation(.easeIn(duration: 0.35)) {
            bloomOpacity = 0
            openerOpacity = 0
            hairlineProgress = 0
            referenceOpacity = 0
            ornamentOpacity = 0
            primaryButtonOpacity = 0
            secondaryButtonOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            onContinue()
        }
    }

    private func resampleVerse() {
        guard versePool.count > 1 else {
            HapticService.invalid()
            return
        }
        HapticService.chipTap()
        Analytics.track(.personalVerseRevealResampled)

        // Fade out current verse, advance pool, fade in new verse.
        withAnimation(.easeIn(duration: 0.25)) {
            revealedChars = 0
            referenceOpacity = 0
            ornamentOpacity = 0
            primaryButtonOpacity = 0
            primaryButtonOffset = 30
            secondaryButtonOpacity = 0
            hairlineProgress = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            versePoolIndex = (versePoolIndex + 1) % versePool.count
            currentVerse = versePool[versePoolIndex]
            withAnimation(.easeInOut(duration: 0.7)) { hairlineProgress = 0.65 }
            try? await Task.sleep(nanoseconds: 500_000_000)
            let text = currentVerse.text
            let charDelay: UInt64 = 34_000_000
            for i in 1...text.count {
                try? await Task.sleep(nanoseconds: charDelay)
                if Task.isCancelled { return }
                revealedChars = i
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            HapticService.commit()
            withAnimation(.easeOut(duration: 0.5)) {
                ornamentOpacity = 1
                referenceOpacity = 1
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                primaryButtonOpacity = 1
                primaryButtonOffset = 0
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.easeOut(duration: 0.4)) { secondaryButtonOpacity = 1 }
        }
    }
}

// MARK: - Personal Verse Value Object

struct PersonalVerse: Equatable {
    let contentId: UUID?
    let text: String
    let reference: String

    static let placeholder = PersonalVerse(
        contentId: nil,
        text: "Be still, and know that I am God.",
        reference: "Psalm 46:10"
    )

    static func fallback(for burdens: Set<Burden>) -> PersonalVerse {
        // Curated hard-coded fallbacks per burden. Used only if the SwiftData
        // store is empty (shouldn't happen in production — content is seeded
        // on first launch — but keeps the onboarding flow from ever showing
        // an empty screen).
        let table: [Burden: PersonalVerse] = [
            .anxiety: PersonalVerse(contentId: nil, text: "Cast all your anxiety on him, because he cares for you.", reference: "1 Peter 5:7"),
            .grief: PersonalVerse(contentId: nil, text: "The Lord is close to the brokenhearted and saves those who are crushed in spirit.", reference: "Psalm 34:18"),
            .doubt: PersonalVerse(contentId: nil, text: "Lord, I believe; help thou mine unbelief.", reference: "Mark 9:24"),
            .loneliness: PersonalVerse(contentId: nil, text: "I will never leave thee, nor forsake thee.", reference: "Hebrews 13:5"),
            .anger: PersonalVerse(contentId: nil, text: "Be angry, and do not sin; do not let the sun go down on your wrath.", reference: "Ephesians 4:26"),
            .temptation: PersonalVerse(contentId: nil, text: "No temptation has overtaken you except what is common to mankind. God is faithful.", reference: "1 Corinthians 10:13"),
            .health: PersonalVerse(contentId: nil, text: "He heals the brokenhearted and binds up their wounds.", reference: "Psalm 147:3"),
            .financial: PersonalVerse(contentId: nil, text: "My God shall supply all your need according to his riches in glory.", reference: "Philippians 4:19"),
            .relationship: PersonalVerse(contentId: nil, text: "Love is patient, love is kind. It does not envy, it does not boast.", reference: "1 Corinthians 13:4"),
            .purpose: PersonalVerse(contentId: nil, text: "For I know the plans I have for you — plans to prosper you, not to harm you.", reference: "Jeremiah 29:11"),
        ]
        if let first = burdens.first, let match = table[first] { return match }
        return .placeholder
    }
}

// MARK: - Verse Selector
//
// Builds a pool of candidate verses scored against the user's onboarding
// profile. Reuses FeedEngine so the scoring is consistent with what the
// Feed tab will show them later — the aha is that the same engine that
// generated this verse will be generating their daily feed forever.

@MainActor
enum PersonalVerseSelector {
    static func pool(viewModel: OnboardingViewModel, modelContext: ModelContext) -> [PersonalVerse] {
        // Get the profile that onboarding just persisted. If it's somehow nil
        // (shouldn't happen since burdens were just saved), synthesize one
        // from the view model so scoring still works.
        let descriptor = FetchDescriptor<UserProfile>()
        let profile = (try? modelContext.fetch(descriptor).first) ?? UserProfile()

        // Keep the view model's most recent picks in sync with the profile
        // used for scoring — avoids a race where the persisted profile is
        // fetched before SwiftData has flushed the burden update.
        profile.currentBurdens = Array(viewModel.selectedBurdens)
        profile.lifeSeasons = Array(viewModel.selectedLifeSeasons)
        if let level = viewModel.selectedFaithLevel { profile.faithLevel = level }

        let engine = FeedEngine(modelContext: modelContext)
        let feed = engine.generateFeed(for: profile, count: 40)

        // Prefer actual verses with both reference + text populated. Then
        // dedupe by reference so we don't show Psalm 23 three times in a
        // "Show me another" loop.
        var seen: Set<String> = []
        var pool: [PersonalVerse] = []
        for item in feed where item.type == .verse {
            guard let ref = item.verseReference, let text = item.verseText,
                  !ref.isEmpty, !text.isEmpty else { continue }
            if seen.contains(ref) { continue }
            seen.insert(ref)
            pool.append(PersonalVerse(contentId: item.id, text: text, reference: ref))
            if pool.count >= 6 { break }
        }

        // Fall back to a single curated verse if the store was empty.
        if pool.isEmpty {
            pool = [PersonalVerse.fallback(for: viewModel.selectedBurdens)]
        }
        return pool
    }

    static func markKept(id: UUID?, modelContext: ModelContext) {
        guard let id else { return }
        let predicate = #Predicate<PrayerContent> { $0.id == id }
        let descriptor = FetchDescriptor<PrayerContent>(predicate: predicate)
        if let content = try? modelContext.fetch(descriptor).first {
            content.isSaved = true
            try? modelContext.save()
        }
    }
}

// MARK: - Drifting Motes (decorative gold particles)

private struct DriftingMotesLayer: View {
    let color: Color
    @State private var start: Date = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSince(start)
                for i in 0..<14 {
                    let seed = Double(i) * 7.3
                    let x = (size.width * 0.08) + fmod(seed * 37 + t * 18, size.width * 0.84)
                    let baseY = (size.height * 0.15) + CGFloat(fmod(seed * 61, size.height * 0.7))
                    let y = baseY + CGFloat(sin((t + seed) * 0.5) * 20) - CGFloat(fmod(t * 12 + seed * 11, size.height * 1.2))
                    let radius = CGFloat(1.2 + sin((t + seed) * 0.9) * 0.7)
                    let alpha = 0.35 + 0.3 * sin((t + seed) * 0.7)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(max(0, alpha))))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
