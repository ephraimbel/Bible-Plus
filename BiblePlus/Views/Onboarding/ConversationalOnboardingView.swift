import SwiftUI
import SwiftData

// MARK: - Conversational Onboarding
//
// The onboarding flow. Welcome → a short, focused interview (name, faith,
// season, burdens, what's holding you back → an empathy "mirror" + a motivation
// stat → how much time / when to reach you) → the reveal act (building your
// plan → your first plan → the personal-verse reveal) → commitment pledge →
// review ask → paywall.
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

        case .name, .faith,
             .seasons, .burdens, .holdingBack, .timeCommitment,
             .notifications:
            questionScreen(step: convStep, vm: vm)
                .id(convStep)
                .environment(\.bpPalette, BPColorPalette.light)
                .preferredColorScheme(.light)
                .transition(.opacity)

        case .proofStats:
            // Motivation beat — animated growth chart + counting stat. Sits
            // after the Mirror empathy beat and leads into the practical
            // time-commitment ask ("daily works" → "how much time can you give").
            OnboardingProofStatsView {
                advanceQuestion(to: .timeCommitment)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .mirrorBlockers:
            // "We built around exactly that" empathy beat after the blockers
            // question, then into the motivation stat before the practical close.
            OnboardingMirrorView(viewModel: vm) {
                moveTo(.proofStats)
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
            // Flows straight to the personal-verse reveal.
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
            content: { questionInput(step: step, vm: vm) },
            footer: { questionFooter(step: step, vm: vm) }
        )
    }

    // MARK: - Copy

    /// The ordered interview — the only steps that show the progress bar.
    /// The reveal/sell act after the final question (`.notifications`) is excluded.
    private static let questionOrder: [ConversationalStep] = [
        // Escalating intimacy: who you are → where you are with God →
        // what you're carrying → the practical close. Trimmed hard for a tighter
        // funnel and faster time-to-value: gender/birth-year, the closeness
        // slider, and the goals screen were cut — they collected data nothing
        // downstream consumed. The emotional peak (seasons → burdens →
        // holdingBack) is followed by the Mirror + proof beats, then the
        // practical close (how much time / when to reach you).
        .name,
        .faith,
        .seasons, .burdens, .holdingBack,
        .timeCommitment, .notifications
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
        case .faith: return "YOUR JOURNEY"
        case .seasons: return "YOUR SEASON"
        case .burdens: return "YOUR HEART"
        case .holdingBack: return "THE REAL TALK"
        case .timeCommitment: return "YOUR TIME"
        case .notifications: return "DAILY MOMENTS"
        default: return ""
        }
    }

    private func headline(_ step: ConversationalStep, vm: OnboardingViewModel) -> String {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        switch step {
        case .name: return "What should we call you?"
        case .faith: return name.isEmpty ? "Where are you on your walk?" : "Where are you on your walk, \(name)?"
        case .seasons: return "What season are you in?"
        case .burdens: return "What's weighing on you lately?"
        case .holdingBack: return "What tends to get in the way?"
        case .timeCommitment: return "How much time can you give each day?"
        case .notifications: return "When should we reach you?"
        default: return ""
        }
    }

    private func subtitle(_ step: ConversationalStep) -> String? {
        switch step {
        case .name: return "So everything here feels like it's meant for you."
        case .faith: return "There's no wrong answer — it just helps us meet you where you are."
        case .seasons: return "Choose anything that fits — you can pick a few."
        case .burdens: return "This stays between us, and it shapes everything we send you."
        case .holdingBack: return "Name it, and we'll help you work around it. Pick any."
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
        case .faith: return vm.selectedFaithLevel != nil
        case .seasons: return !vm.selectedLifeSeasons.isEmpty
        case .burdens: return !vm.selectedBurdens.isEmpty
        case .holdingBack: return !vm.selectedGrowthBlockers.isEmpty
        case .timeCommitment: return vm.selectedTimeCommitment != nil
        default: return true
        }
    }

    // MARK: - Chip grid (multi-select)

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
        case .holdingBack:
            // Empathy mirror → motivation stat → the practical close.
            moveTo(.mirrorBlockers)
        default:
            if let next = nextQuestionStep(after: step) {
                advanceQuestion(to: next)
            }
        }
    }

    private func persistAnswer(_ step: ConversationalStep, vm: OnboardingViewModel) {
        switch step {
        case .name: vm.persistName()
        case .faith: vm.persistFaithLevel()
        case .seasons: vm.persistLifeSeasons()
        case .burdens: vm.persistBurdens()
        case .holdingBack: vm.persistGrowthBlockers()
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
        // Notifications is now the final interview question → hand off to the
        // reveal/sell act. Bump the legacy view model to step 9 so the paywall's
        // goNext() lands on >= 10 and completes onboarding.
        vm.currentStep = 9
        moveTo(.buildingPlan)
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
    case faith
    case seasons
    case burdens
    case holdingBack
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
