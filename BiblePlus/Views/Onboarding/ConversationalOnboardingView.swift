import SwiftUI
import SwiftData

// MARK: - Conversational Onboarding
//
// The onboarding flow. Welcome → a short run of clean, editorial questions
// (name, faith, season, burdens) → a live AI moment → notifications → the
// reveal act (journey projection, your plan, showcase reel, personal verse) →
// social proof → paywall.
//
// The question screens are built on `OnboardingQuestionScaffold`: Warm Paper,
// gold eyebrow, Baskerville headline, clean selectable cards, a pinned gold
// CTA, and a slim segmented progress bar. (The old book-page + typewriter
// "parchment" treatment was retired — it read dated next to the rest of the
// flow.)
//
// Deferred to Settings: translation picker, aesthetic background, widget setup.
struct ConversationalOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(StoreKitService.self) private var storeKitService
    @State private var viewModel: OnboardingViewModel?
    @State private var convStep: ConversationalStep = .welcome

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                OnboardingBackground()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(
                    modelContext: modelContext,
                    storeKitService: storeKitService
                )
            }
        }
    }

    @ViewBuilder
    private func content(vm: OnboardingViewModel) -> some View {
        switch convStep {
        case .welcome:
            WelcomeView(viewModel: vm)
                .transition(.opacity)
                .onChange(of: vm.currentStep) { _, newValue in
                    // Welcome's "Begin" calls vm.goNext() (legacy step 0 → 1).
                    // That's our cue to enter the first question.
                    if newValue == 1 && convStep == .welcome {
                        beginConversation(vm: vm)
                    }
                }

        case .name, .gender, .faith, .closeness,
             .seasons, .burdens, .holdingBack, .goals, .timeCommitment,
             .notifications:
            questionScreen(step: convStep, vm: vm)
                .id(convStep)
                .environment(\.bpPalette, BPColorPalette.light)
                .preferredColorScheme(.light)
                .transition(.opacity)

        case .proofStats:
            // Animated growth chart + counting stat — the proof beat.
            OnboardingProofStatsView {
                advanceQuestion(to: .holdingBack)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .mirrorBlockers:
            // "We built around exactly that" beat after the blockers question,
            // then into the practical close starting with the time commitment.
            OnboardingMirrorView(viewModel: vm) {
                advanceQuestion(to: .timeCommitment)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .buildingPlan:
            // The Cal AI signature — an animated "we're crafting your plan"
            // beat that ticks through personalized lines built from their
            // answers, so the reveal that follows feels earned.
            OnboardingBuildingPlanView(viewModel: vm) {
                moveTo(.yourPlan)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .yourPlan:
            // Reveal act 2 — the reading plan auto-chosen from their burden.
            // Flows straight to the personal-verse reveal; the showcase reel
            // and art carousel were trimmed to keep the reveal tight.
            OnboardingYourPlanView(viewModel: vm) {
                moveTo(.personalVerseReveal)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .personalVerseReveal:
            // The cinematic dark moment — palette flips to Midnight regardless
            // of user prefs so the gold-on-black reveal lands consistently.
            PersonalVerseRevealView(viewModel: vm) {
                moveTo(.commitment)
            }
            .preferredColorScheme(.dark)
            .environment(\.bpPalette, BPColorPalette.dark)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.04)),
                removal: .opacity
            ))

        case .commitment:
            // The micro-commitment pledge right before the paywall — a single
            // "I'm ready" tap that primes the user to follow through (and buy).
            OnboardingCommitmentView(viewModel: vm) {
                // After the pledge, ask for a review (the warmest, highest-intent
                // moment in the funnel) before handing off to the paywall.
                moveTo(.appReview, animation: .easeInOut(duration: 0.5))
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.opacity)

        case .appReview:
            // A clean "love Bible+? leave a review" moment. The native App Store
            // rating sheet pops up over this page; the CTA hands off to the
            // paywall. Stays on the light Warm Paper palette like commitment, so
            // the light → dark handoff happens as the paywall arrives.
            OnboardingReviewView {
                moveTo(.paywall, delay: 180_000_000, animation: .easeInOut(duration: 0.55))
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.opacity)

        case .paywall:
            PaywallContainerView(viewModel: vm)
                .preferredColorScheme(.dark)
                .environment(\.bpPalette, BPColorPalette.dark)
                .transition(.opacity)
                .onChange(of: vm.currentStep) { _, newValue in
                    if newValue >= 10 && convStep == .paywall {
                        finishOnboarding(vm: vm)
                    }
                }
        }
    }

    // MARK: - Question Screen

    @ViewBuilder
    private func questionScreen(step: ConversationalStep, vm: OnboardingViewModel) -> some View {
        OnboardingQuestionScaffold(
            stepNumber: stepNumber(step),
            totalSteps: Self.questionOrder.count,
            eyebrow: eyebrow(step),
            headline: headline(step, vm: vm),
            subtitle: subtitle(step),
            showBack: previousStep() != nil,
            onBack: { goBack(vm: vm) },
            centerContent: step == .closeness,
            content: { questionInput(step: step, vm: vm) },
            footer: { questionFooter(step: step, vm: vm) }
        )
    }

    // MARK: - Copy

    /// The ordered interview — the only steps that show the progress bar.
    /// The reveal/sell act after the final question (`.goals`) is excluded.
    private static let questionOrder: [ConversationalStep] = [
        // Escalating intimacy: who you are → where you are with God →
        // what you're carrying → the practical commitment → your hope.
        // Trimmed for a tighter funnel: marketing attribution (howHeard) is
        // gone (the ad platform already reports source) and devotion frequency
        // folds into faith level + closeness rather than its own screen. After
        // the emotional peak the tone de-escalates into the practical close
        // (how much time / when to reach you), and goals lands last so the
        // reveal opens on an upward note.
        .name, .gender,
        .faith, .closeness,
        .seasons, .burdens, .holdingBack,
        .timeCommitment, .notifications, .goals
    ]

    private func stepNumber(_ step: ConversationalStep) -> Int {
        (Self.questionOrder.firstIndex(of: step) ?? 0) + 1
    }

    private func nextQuestionStep(after step: ConversationalStep) -> ConversationalStep? {
        guard let i = Self.questionOrder.firstIndex(of: step),
              i + 1 < Self.questionOrder.count else { return nil }
        return Self.questionOrder[i + 1]
    }

    private func eyebrow(_ step: ConversationalStep) -> String {
        switch step {
        case .name: return "WELCOME"
        case .gender: return "ABOUT YOU"
        case .faith: return "YOUR JOURNEY"
        case .closeness: return "HONESTLY"
        case .seasons: return "YOUR SEASON"
        case .burdens: return "YOUR HEART"
        case .holdingBack: return "THE REAL TALK"
        case .goals: return "YOUR HOPE"
        case .timeCommitment: return "YOUR TIME"
        case .notifications: return "DAILY MOMENTS"
        default: return ""
        }
    }

    private func headline(_ step: ConversationalStep, vm: OnboardingViewModel) -> String {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        switch step {
        case .name: return "What should we call you?"
        case .gender: return name.isEmpty ? "A little about you." : "A little about you, \(name)."
        case .faith: return name.isEmpty ? "Where are you on your walk?" : "Where are you on your walk, \(name)?"
        case .closeness: return "Right now, how close does God feel?"
        case .seasons: return "What season are you in?"
        case .burdens: return "What's weighing on you lately?"
        case .holdingBack: return "What tends to get in the way?"
        case .goals: return "What do you hope to find here?"
        case .timeCommitment: return "How much time can you give each day?"
        case .notifications: return "When should we reach you?"
        default: return ""
        }
    }

    private func subtitle(_ step: ConversationalStep) -> String? {
        switch step {
        case .name: return "So everything here feels like it's meant for you."
        case .gender: return "This helps us speak to you personally and set the right pace."
        case .faith: return "There's no wrong answer — it just helps us meet you where you are."
        case .closeness: return "Some seasons He feels near; others, distant. Wherever you are is okay."
        case .seasons: return "Choose anything that fits — you can pick a few."
        case .burdens: return "This stays between us, and it shapes everything we send you."
        case .holdingBack: return "Name it, and we'll help you work around it. Pick any."
        case .goals: return "Pick what matters most — we'll build around it."
        case .timeCommitment: return "Even a few minutes, done daily, changes everything."
        case .notifications: return "A gentle verse, right when you need it most."
        default: return nil
        }
    }

    // MARK: - Question Input

    @ViewBuilder
    private func questionInput(step: ConversationalStep, vm: OnboardingViewModel) -> some View {
        switch step {
        case .name:
            PremiumNameField(
                text: Binding(get: { vm.firstName }, set: { vm.firstName = $0 }),
                accentGold: accentGold,
                onSubmit: { advanceFromName(vm: vm) }
            )

        case .faith:
            VStack(spacing: 10) {
                ForEach(FaithLevel.allCases, id: \.self) { level in
                    OnboardingSelectableCard(
                        label: level.displayName,
                        isSelected: vm.selectedFaithLevel == level,
                        fullWidth: true
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            vm.selectedFaithLevel = level
                        }
                        HapticService.chipTap()
                    }
                }
            }

        case .gender:
            // Merged "About you" — gender + birth year, each with its own title.
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    fieldTitle("GENDER")
                    singleChipGrid(
                        items: Gender.allCases,
                        selected: vm.selectedGender,
                        label: { $0.displayName },
                        select: { vm.selectedGender = $0 }
                    )
                }
                VStack(alignment: .leading, spacing: 12) {
                    fieldTitle("BIRTH YEAR")
                    BirthYearWheel(age: Binding(get: { vm.age }, set: { vm.age = $0 }))
                }
            }

        case .closeness:
            ClosenessScale(
                value: Binding(get: { vm.closenessRating }, set: { vm.closenessRating = $0 })
            )

        case .seasons:
            chipGrid(
                items: LifeSeason.allCases,
                selected: vm.selectedLifeSeasons,
                label: { $0.displayName },
                toggle: { vm.toggleLifeSeason($0) }
            )

        case .burdens:
            chipGrid(
                items: Burden.allCases,
                selected: vm.selectedBurdens,
                label: { $0.displayName },
                toggle: { vm.toggleBurden($0) }
            )

        case .holdingBack:
            chipGrid(
                items: GrowthBlocker.allCases,
                selected: vm.selectedGrowthBlockers,
                label: { $0.displayName },
                toggle: { vm.toggleGrowthBlocker($0) }
            )

        case .goals:
            chipGrid(
                items: AppGoal.allCases,
                selected: vm.selectedGoals,
                label: { $0.displayName },
                toggle: { vm.toggleGoal($0) }
            )

        case .timeCommitment:
            timeCommitmentSelector(vm: vm)

        case .notifications:
            prayerTimeSelector(vm: vm)

        default:
            EmptyView()
        }
    }

    // MARK: - Question Footer (pinned action)

    @ViewBuilder
    private func questionFooter(step: ConversationalStep, vm: OnboardingViewModel) -> some View {
        switch step {
        case .notifications:
            VStack(spacing: 6) {
                GoldButton(title: "Send me verses", isEnabled: !vm.selectedPrayerTimes.isEmpty, showGlow: true) {
                    advanceFromNotifications(vm: vm, enableNotifications: true)
                }
                Button {
                    HapticService.lightImpact()
                    advanceFromNotifications(vm: vm, enableNotifications: false)
                } label: {
                    Text("Not now")
                        .font(.custom("Georgia", size: 15))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }

        default:
            GoldButton(title: "Continue", isEnabled: isStepComplete(step, vm: vm), showGlow: true) {
                advanceInterview(from: step, vm: vm)
            }
        }
    }

    /// Whether the user has answered enough to advance past `step`.
    private func isStepComplete(_ step: ConversationalStep, vm: OnboardingViewModel) -> Bool {
        switch step {
        case .name: return !vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .gender: return vm.selectedGender != nil && vm.age >= 1 && vm.age <= 120
        case .faith: return vm.selectedFaithLevel != nil
        case .closeness: return vm.closenessRating > 0
        case .seasons: return !vm.selectedLifeSeasons.isEmpty
        case .burdens: return !vm.selectedBurdens.isEmpty
        case .holdingBack: return !vm.selectedGrowthBlockers.isEmpty
        case .goals: return !vm.selectedGoals.isEmpty
        case .timeCommitment: return vm.selectedTimeCommitment != nil
        default: return true
        }
    }

    // MARK: - Chip grid (multi-select)

    // Small gold-muted field label for grouped inputs (e.g. the About You card).
    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(palette.textMuted)
    }

    // Chunk items into rows of two. A lone last item renders full-width (each
    // card already fills its column via maxWidth: .infinity), so every grid
    // stays symmetric — no half-width orphan chip.
    private func pairedRows<Item>(_ items: [Item]) -> [[Item]] {
        stride(from: 0, to: items.count, by: 2).map {
            Array(items[$0 ..< min($0 + 2, items.count)])
        }
    }

    private func chipGrid<Item: Hashable>(
        items: [Item],
        selected: Set<Item>,
        label: @escaping (Item) -> String,
        toggle: @escaping (Item) -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(pairedRows(items).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { item in
                        OnboardingSelectableCard(
                            label: label(item),
                            isSelected: selected.contains(item)
                        ) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                toggle(item)
                            }
                            HapticService.chipTap()
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
    }

    // MARK: - Single-select grid / list

    private func singleChipGrid<Item: Hashable>(
        items: [Item],
        selected: Item?,
        label: @escaping (Item) -> String,
        select: @escaping (Item) -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(pairedRows(items).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { item in
                        OnboardingSelectableCard(label: label(item), isSelected: selected == item) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { select(item) }
                            HapticService.chipTap()
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
    }

    private func singleColumnList<Item: Hashable>(
        items: [Item],
        selected: Item?,
        label: @escaping (Item) -> String,
        select: @escaping (Item) -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.self) { item in
                OnboardingSelectableCard(label: label(item), isSelected: selected == item, fullWidth: true) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { select(item) }
                    HapticService.chipTap()
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
    }

    // MARK: - Prayer-time selector (notifications step)
    //
    // Richer than a chip grid: each daily moment gets an icon, a concrete clock
    // window, and a one-line promise of what arrives. Tall full-width rows fill
    // the screen instead of leaving four small chips marooned in empty space.

    private func prayerTimeBlurb(_ slot: PrayerTimeSlot) -> String {
        switch slot {
        case .morning: return "A verse to wake up to"
        case .midday: return "A pause to reset your day"
        case .evening: return "Wind down with Scripture"
        case .bedtime: return "End the day in peace"
        }
    }

    private func prayerTimeSelector(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 12) {
            ForEach(PrayerTimeSlot.allCases) { slot in
                let isSelected = vm.selectedPrayerTimes.contains(slot)
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                        vm.togglePrayerTime(slot)
                    }
                    HapticService.chipTap()
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(slot.displayName)
                                    .font(.custom("Georgia", size: 17))
                                    .foregroundStyle(isSelected ? .white : palette.textPrimary)
                                Text(slot.timeRange)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .tracking(0.4)
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : accentGold)
                            }
                            Text(prayerTimeBlurb(slot))
                                .font(.custom("Georgia-Italic", size: 13.5))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : palette.textSecondary)
                        }

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? accentGold : palette.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.25) : accentGold.opacity(0.18),
                                    lineWidth: isSelected ? 1 : 0.7)
                    )
                    .shadow(color: isSelected ? accentGold.opacity(0.32) : .black.opacity(0.05),
                            radius: isSelected ? 11 : 5, y: isSelected ? 5 : 3)
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: vm.selectedPrayerTimes)
    }

    // MARK: - Time-commitment selector (timeCommitment step)
    //
    // Single-select sibling of the prayer-time rows — same row anatomy (a gold
    // badge, a title + one-line promise, a selection mark) so the two practical
    // "logistics" screens feel of a piece. Tall rows fill the page instead of
    // leaving four small chips marooned in empty space.

    private func timeBlurb(_ c: TimeCommitment) -> String {
        switch c {
        case .threeMin: return "A quick daily touchpoint"
        case .fiveMin: return "A steady, sustainable rhythm"
        case .tenMin: return "Room to read and reflect"
        case .fifteenPlus: return "A deeper daily practice"
        }
    }

    private func timeCommitmentSelector(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 12) {
            ForEach(TimeCommitment.allCases) { option in
                let isSelected = vm.selectedTimeCommitment == option
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                        vm.selectedTimeCommitment = option
                    }
                    HapticService.chipTap()
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.displayName)
                                .font(.custom("Georgia", size: 17))
                                .foregroundStyle(isSelected ? .white : palette.textPrimary)
                            Text(timeBlurb(option))
                                .font(.custom("Georgia-Italic", size: 13.5))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : palette.textSecondary)
                        }

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? accentGold : palette.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.25) : accentGold.opacity(0.18),
                                    lineWidth: isSelected ? 1 : 0.7)
                    )
                    .shadow(color: isSelected ? accentGold.opacity(0.32) : .black.opacity(0.05),
                            radius: isSelected ? 11 : 5, y: isSelected ? 5 : 3)
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: vm.selectedTimeCommitment)
    }

    // MARK: - Navigation

    private func beginConversation(vm: OnboardingViewModel) {
        // Welcome flows straight into the first question (no AI-hook sim — the
        // showcase reel after Your Plan is the single iPhone-sim moment).
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            convStep = .name
        }
    }

    /// Name's keyboard "continue" submit reuses the same advance path.
    private func advanceFromName(vm: OnboardingViewModel) {
        advanceInterview(from: .name, vm: vm)
    }

    /// The single advance path for every interview question. Persists the
    /// answer, fires the right haptic, then either moves to the next question
    /// or — on the final one — hands off to the reveal/sell act.
    private func advanceInterview(from step: ConversationalStep, vm: OnboardingViewModel) {
        guard isStepComplete(step, vm: vm) else { return }
        persistAnswer(step, vm: vm)
        if step == .name { HapticService.commit() } else { HapticService.lightImpact() }

        switch step {
        case .burdens:
            // Proof beat, then back into the interview at frequency.
            moveTo(.proofStats)
        case .holdingBack:
            // "We built around that" mirror, then back at goals.
            moveTo(.mirrorBlockers)
        case .goals:
            // Final interview question (the aspirational note) → hand off to
            // the reveal/sell act. Bump the legacy view model to step 9 so the
            // paywall's goNext() lands on >= 10 and completes onboarding.
            vm.currentStep = 9
            moveTo(.buildingPlan)
        default:
            if let next = nextQuestionStep(after: step) {
                advanceQuestion(to: next)
            }
        }
    }

    private func persistAnswer(_ step: ConversationalStep, vm: OnboardingViewModel) {
        switch step {
        case .name: vm.persistName()
        case .gender: vm.persistGender(); vm.persistAge()
        case .faith: vm.persistFaithLevel()
        case .closeness: vm.persistCloseness()
        case .seasons: vm.persistLifeSeasons()
        case .burdens: vm.persistBurdens()
        case .holdingBack: vm.persistGrowthBlockers()
        case .goals: vm.persistGoals()
        case .timeCommitment: vm.persistTimeCommitment()
        default: break
        }
    }

    private func advanceFromNotifications(vm: OnboardingViewModel, enableNotifications: Bool) {
        if enableNotifications && !vm.selectedPrayerTimes.isEmpty {
            vm.persistPrayerTimes()
            Task { await vm.requestNotificationPermissionStandalone() }
        }
        HapticService.lightImpact()
        advanceQuestion(to: .goals)
    }

    /// Clean crossfade between question steps. The scaffold's own staggered
    /// entrance does the rest.
    private func advanceQuestion(to next: ConversationalStep) {
        HapticService.lightImpact()
        withAnimation(.easeInOut(duration: 0.4)) {
            convStep = next
        }
    }

    /// Handoff to a full-screen moment (live ask, reveal act, paywall) with a
    /// brief beat so the action's haptic/visual registers before the cut.
    /// `delay`/`animation` are tunable so handoffs into tonally different
    /// destinations (e.g. the light→dark paywall) can use a cleaner dissolve.
    private func moveTo(_ next: ConversationalStep,
                        delay: UInt64 = 420_000_000,
                        animation: Animation = .spring(response: 0.55, dampingFraction: 0.82)) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            withAnimation(animation) {
                convStep = next
            }
        }
    }

    private func goBack(vm: OnboardingViewModel) {
        guard let prev = previousStep() else { return }
        HapticService.lightImpact()
        withAnimation(.easeInOut(duration: 0.4)) {
            convStep = prev
        }
    }

    private func previousStep() -> ConversationalStep? {
        guard let i = Self.questionOrder.firstIndex(of: convStep), i > 0 else { return nil }
        return Self.questionOrder[i - 1]
    }

    private func finishOnboarding(vm: OnboardingViewModel) {
        vm.completeOnboarding()
    }
}

// MARK: - Step Model

private enum ConversationalStep: Hashable {
    case welcome
    // ── The interview (progress bar) ──────────────────────────────
    case name
    case gender
    case faith
    case closeness
    case seasons
    case burdens
    case holdingBack
    case goals
    case timeCommitment
    case notifications
    // ── The reveal / sell act (moments — no progress bar) ─────────
    // Proof beats interleaved during the interview, then the closing act.
    case proofStats
    case mirrorBlockers
    case buildingPlan
    case yourPlan
    case personalVerseReveal
    case commitment
    case appReview
    case paywall
}

// MARK: - Premium Name Field
//
// Standalone component so @FocusState works cleanly. Gold focus glow and
// stroke intensify when the field is active — a premium editorial input.
private struct PremiumNameField: View {
    @Binding var text: String
    let accentGold: Color
    let onSubmit: () -> Void

    // Read the palette from the environment (not passed in) so the field
    // inherits the question flow's forced-light palette. Passing the parent's
    // outer @Environment value made the field render dark when the device was
    // in dark mode, while the rest of the (forced-light) screen stayed light.
    @Environment(\.bpPalette) private var palette
    @FocusState private var isFocused: Bool

    var body: some View {
        // Custom placeholder: the system placeholder follows the DEVICE
        // appearance, so on a dark-mode device it renders a faint light-gray
        // that's nearly invisible on this forced-light field. We draw our own
        // in a readable palette color instead.
        TextField("", text: $text)
            .font(.custom("Georgia", size: 20))
            .foregroundStyle(palette.textPrimary)
            .tint(accentGold)
            .focused($isFocused)
            .overlay(alignment: .leading) {
                if text.isEmpty {
                    Text("Your name")
                        .font(.custom("Georgia", size: 20))
                        .foregroundStyle(palette.textSecondary)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accentGold.opacity(isFocused ? 0.08 : 0.0), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        accentGold.opacity(isFocused ? 0.7 : 0.22),
                        lineWidth: isFocused ? 1.1 : 0.7
                    )
            )
            .shadow(
                color: accentGold.opacity(isFocused ? 0.20 : 0.0),
                radius: isFocused ? 14 : 0,
                y: 4
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isFocused)
            .submitLabel(.continue)
            .onSubmit { onSubmit() }
            .onAppear { isFocused = true }
    }
}

// MARK: - Premium Age Field
//
// A numeric companion to PremiumNameField — the user types their exact age
// rather than picking a bracket. Digits-only, clamped to a sane 1–120, with a
// soft "years" suffix and the same gold focus glow as the name field.
private struct PremiumAgeField: View {
    @Binding var age: Int
    let accentGold: Color
    let onSubmit: () -> Void

    // See PremiumNameField: read the forced-light palette from the environment
    // rather than the parent's outer (system-appearance) value.
    @Environment(\.bpPalette) private var palette
    @FocusState private var isFocused: Bool
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(palette.textPrimary)
                .tint(accentGold)
                .focused($isFocused)
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text("Your age")
                            .font(.custom("Georgia", size: 20))
                            .foregroundStyle(palette.textSecondary)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: text) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(3))
                    if digits != newValue { text = digits }
                    age = min(Int(digits) ?? 0, 120)
                }

            if age > 0 {
                Text(age == 1 ? "year" : "years")
                    .font(.custom("Georgia-Italic", size: 16))
                    .foregroundStyle(palette.textSecondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(isFocused ? 0.08 : 0.0), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    accentGold.opacity(isFocused ? 0.7 : 0.22),
                    lineWidth: isFocused ? 1.1 : 0.7
                )
        )
        .shadow(
            color: accentGold.opacity(isFocused ? 0.20 : 0.0),
            radius: isFocused ? 14 : 0, y: 4
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: age > 0)
        .onAppear {
            if age > 0 { text = String(age) }
            isFocused = true
        }
    }
}

// MARK: - Birth Year Wheel
//
// A clean slot-machine scroll of birth years (replaces the age text box). Stores
// the user's age (current year − selected year) so the rest of the flow reads
// the same `age` value. Defaults to a sensible mid-range year, ready to adjust.
private struct BirthYearWheel: View {
    @Binding var age: Int

    @Environment(\.bpPalette) private var palette
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private let rowHeight: CGFloat = 46
    private let visibleRows = 5

    private let currentYear: Int
    private let years: [Int]
    @State private var selectedYear: Int?

    init(age: Binding<Int>) {
        self._age = age
        let cy = Calendar.current.component(.year, from: Date())
        currentYear = cy
        years = Array(stride(from: cy - 13, through: cy - 100, by: -1)) // ages 13...100
        let startAge = (age.wrappedValue >= 13 && age.wrappedValue <= 100) ? age.wrappedValue : 25
        _selectedYear = State(initialValue: cy - startAge)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(years, id: \.self) { year in
                    Text(verbatim: String(year))
                        .font(.custom("Baskerville-Bold", size: 27))
                        .monospacedDigit()
                        .foregroundStyle(selectedYear == year ? accentGold : palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                        .scrollTransition(axis: .vertical) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.3)
                                .scaleEffect(phase.isIdentity ? 1 : 0.82)
                        }
                        .id(year)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $selectedYear, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: rowHeight * CGFloat(visibleRows))
        .contentMargins(.vertical, rowHeight * CGFloat(visibleRows / 2), for: .scrollContent)
        .overlay {
            // Soft gold selection band, centered on the middle row.
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(accentGold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(accentGold.opacity(0.22), lineWidth: 0.8)
                )
                .frame(height: rowHeight)
                .allowsHitTesting(false)
        }
        .mask(
            LinearGradient(
                colors: [.clear, .black, .black, .black, .clear],
                startPoint: .top, endPoint: .bottom
            )
        )
        .onChange(of: selectedYear) { _, year in if let year { age = currentYear - year } }
        .onAppear { if let year = selectedYear { age = currentYear - year } }
    }
}

// MARK: - Closeness Scale
//
// The emotional "before" — five tappable orbs from "Distant" to "Very close."
// Orbs fill with gold up to the selected value and gently swell; the chosen
// number is echoed back on the journey-projection reveal. Distinct from the
// faith-level question (identity) and the frequency question (behavior): this
// one is purely about how close God *feels* right now.
private struct ClosenessScale: View {
    @Binding var value: Int   // 1...5, 0 = unselected

    @Environment(\.bpPalette) private var palette
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let lightGold = Color(red: 0.90, green: 0.80, blue: 0.57)
    // A brighter, more luminous gold used purely for the glow halo so it reads
    // as light spilling off the bead rather than the muted accent tone.
    private let glowGold = Color(red: 1.0, green: 0.82, blue: 0.40)

    /// Continuous thumb position (0 = Distant, 1 = Very close). Drives the glow
    /// so it intensifies as you slide right; snaps to one of five notches on
    /// release while the bound `value` stays a clean 1...5.
    @State private var fraction: CGFloat = 0.5

    private let thumbSize: CGFloat = 24
    private let trackHeight: CGFloat = 6
    private let laneHeight: CGFloat = 104   // room for the stronger glow halo

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                let usable = max(1, geo.size.width - thumbSize)
                let x = fraction * usable

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(palette.surfaceElevated)
                        .overlay(Capsule().strokeBorder(accentGold.opacity(0.18), lineWidth: 0.8))
                        .frame(height: trackHeight)

                    // Fill — grows and brightens toward the right
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(0.5), accentGold],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: x + thumbSize / 2, height: trackHeight)

                    // Thumb + glow — centered vertically in the tall lane so the
                    // halo has room and isn't clipped.
                    thumb
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: x)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let f = max(0, min(1, (g.location.x - thumbSize / 2) / usable))
                            fraction = f
                            let v = Int((f * 4).rounded()) + 1
                            if v != value {
                                value = v
                                HapticService.chipTap()
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                                fraction = CGFloat(max(1, value) - 1) / 4
                            }
                        }
                )
            }
            .frame(height: laneHeight)

            HStack {
                Text("Distant")
                Spacer()
                Text("Very close")
            }
            .font(.custom("Georgia-Italic", size: 13))
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            if value < 1 { value = 3 }   // start in the middle, ready to adjust
            fraction = CGFloat(value - 1) / 4
        }
    }

    private var thumb: some View {
        // A small, clean gold bead. The glow is rendered as stacked gold
        // shadows that bloom *around* the bead's silhouette — so the orb stays
        // small and distinct while a real halo grows toward "Very close" and
        // fades toward "Distant".
        Circle()
            .fill(
                RadialGradient(
                    colors: [lightGold, accentGold],
                    center: UnitPoint(x: 0.5, y: 0.40),
                    startRadius: 0,
                    endRadius: thumbSize * 0.62
                )
            )
            .overlay(Circle().strokeBorder(accentGold.opacity(0.5), lineWidth: 0.5))
            // Bright, dense, layered halo. Opacity ramps hard with `fraction` so
            // the glow is faint at "Distant" and blooms intensely toward "Very
            // close". Four stacked shadows give a luminous, gradient falloff.
            .shadow(color: glowGold.opacity(0.30 + fraction * 0.95), radius: 5 + fraction * 16)
            .shadow(color: glowGold.opacity(fraction * 0.95), radius: 11 + fraction * 26)
            .shadow(color: glowGold.opacity(fraction * 0.65), radius: 19 + fraction * 40)
            .shadow(color: glowGold.opacity(fraction * 0.4), radius: 30 + fraction * 56)
            .shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
    }
}
