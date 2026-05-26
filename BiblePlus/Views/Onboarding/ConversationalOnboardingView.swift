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

        case .name, .faith, .seasons, .burdens, .notifications:
            questionScreen(step: convStep, vm: vm)
                .id(convStep)
                .environment(\.bpPalette, BPColorPalette.light)
                .preferredColorScheme(.light)
                .transition(.opacity)

        case .liveAsk:
            // The live "ask anything" moment — the real AI answers a question
            // the user types (or taps), streamed in, tailored to their burdens.
            OnboardingLiveAskView(viewModel: vm) {
                moveTo(.notifications)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .journeyProjection:
            // Reveal act 1 — the illuminated 30-day journey, computed from
            // their answers.
            OnboardingJourneyProjectionView(viewModel: vm) {
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
            OnboardingYourPlanView(viewModel: vm) {
                moveTo(.showcaseReel)
            }
            .environment(\.bpPalette, BPColorPalette.light)
            .preferredColorScheme(.light)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .showcaseReel:
            // S9 — the single iPhone-sim moment: a reel cycling AI · Feed ·
            // Bible · Widgets, each scene given time to finish before advancing.
            ShowcaseReelView {
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
                moveTo(.socialProof)
            }
            .preferredColorScheme(.dark)
            .environment(\.bpPalette, BPColorPalette.dark)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.04)),
                removal: .opacity
            ))

        case .socialProof:
            // Standalone "Wall of Love" between the verse reveal and paywall.
            OnboardingSocialProofView {
                moveTo(.paywall)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity
            ))

        case .paywall:
            PaywallContainerView(viewModel: vm)
                .preferredColorScheme(.dark)
                .environment(\.bpPalette, BPColorPalette.dark)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
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
            totalSteps: 5,
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

    private func stepNumber(_ step: ConversationalStep) -> Int {
        switch step {
        case .name: return 1
        case .faith: return 2
        case .seasons: return 3
        case .burdens: return 4
        case .notifications: return 5
        default: return 1
        }
    }

    private func eyebrow(_ step: ConversationalStep) -> String {
        switch step {
        case .name: return "WELCOME"
        case .faith: return "YOUR JOURNEY"
        case .seasons: return "YOUR SEASON"
        case .burdens: return "YOUR HEART"
        case .notifications: return "DAILY MOMENTS"
        default: return ""
        }
    }

    private func headline(_ step: ConversationalStep, vm: OnboardingViewModel) -> String {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        switch step {
        case .name: return "What should we call you?"
        case .faith: return name.isEmpty ? "Where are you with faith right now?" : "Where are you with faith, \(name)?"
        case .seasons: return "What season are you in?"
        case .burdens: return "What's weighing on you lately?"
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
                palette: palette,
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

        case .notifications:
            chipGrid(
                items: PrayerTimeSlot.allCases,
                selected: vm.selectedPrayerTimes,
                label: { $0.displayName },
                toggle: { vm.togglePrayerTime($0) }
            )

        default:
            EmptyView()
        }
    }

    // MARK: - Question Footer (pinned action)

    @ViewBuilder
    private func questionFooter(step: ConversationalStep, vm: OnboardingViewModel) -> some View {
        switch step {
        case .name:
            GoldButton(
                title: "Continue",
                isEnabled: !vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty,
                showGlow: true
            ) { advanceFromName(vm: vm) }

        case .faith:
            GoldButton(title: "Continue", isEnabled: vm.selectedFaithLevel != nil, showGlow: true) {
                advanceFromFaith(vm: vm)
            }

        case .seasons:
            GoldButton(title: "Continue", isEnabled: !vm.selectedLifeSeasons.isEmpty, showGlow: true) {
                advanceFromSeasons(vm: vm)
            }

        case .burdens:
            GoldButton(title: "Continue", isEnabled: !vm.selectedBurdens.isEmpty, showGlow: true) {
                advanceFromBurdens(vm: vm)
            }

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
            EmptyView()
        }
    }

    // MARK: - Chip grid (multi-select)

    private func chipGrid<Item: Hashable>(
        items: [Item],
        selected: Set<Item>,
        label: @escaping (Item) -> String,
        toggle: @escaping (Item) -> Void
    ) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.self) { item in
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
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
    }

    // MARK: - Navigation

    private func beginConversation(vm: OnboardingViewModel) {
        // Welcome flows straight into the first question (no AI-hook sim — the
        // showcase reel after Your Plan is the single iPhone-sim moment).
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            convStep = .name
        }
    }

    private func advanceFromName(vm: OnboardingViewModel) {
        guard !vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        vm.persistName()
        HapticService.commit()
        advanceQuestion(to: .faith)
    }

    private func advanceFromFaith(vm: OnboardingViewModel) {
        guard vm.selectedFaithLevel != nil else { return }
        vm.persistFaithLevel()
        advanceQuestion(to: .seasons)
    }

    private func advanceFromSeasons(vm: OnboardingViewModel) {
        guard !vm.selectedLifeSeasons.isEmpty else { return }
        vm.persistLifeSeasons()
        advanceQuestion(to: .burdens)
    }

    private func advanceFromBurdens(vm: OnboardingViewModel) {
        guard !vm.selectedBurdens.isEmpty else { return }
        vm.persistBurdens()
        HapticService.commit()
        // After sharing their burdens, the user meets the real AI.
        moveTo(.liveAsk)
    }

    private func advanceFromNotifications(vm: OnboardingViewModel, enableNotifications: Bool) {
        if enableNotifications && !vm.selectedPrayerTimes.isEmpty {
            vm.persistPrayerTimes()
            Task { await vm.requestNotificationPermissionStandalone() }
        }
        // Advance the legacy view model to step 9 so the paywall's goNext()
        // lands on >= 10 and completes onboarding.
        vm.currentStep = 9
        moveTo(.journeyProjection)
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
    private func moveTo(_ next: ConversationalStep) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
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
        switch convStep {
        case .faith: return .name
        case .seasons: return .faith
        case .burdens: return .seasons
        case .notifications: return .burdens // back skips the one-time live ask (intended)
        default: return nil
        }
    }

    private func finishOnboarding(vm: OnboardingViewModel) {
        vm.completeOnboarding()
    }
}

// MARK: - Step Model

private enum ConversationalStep: Hashable {
    case welcome
    case name
    case faith
    case seasons
    case burdens
    case liveAsk
    case notifications
    case journeyProjection
    case yourPlan
    case showcaseReel
    case personalVerseReveal
    case socialProof
    case paywall
}

// MARK: - Premium Name Field
//
// Standalone component so @FocusState works cleanly. Gold focus glow and
// stroke intensify when the field is active — a premium editorial input.
private struct PremiumNameField: View {
    @Binding var text: String
    let palette: BPColorPalette
    let accentGold: Color
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Your name", text: $text)
            .font(.custom("Georgia", size: 20))
            .foregroundStyle(palette.textPrimary)
            .focused($isFocused)
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
