import SwiftUI
import SwiftData

// MARK: - Conversational Onboarding
//
// Replaces the legacy 11-step onboarding with a chat-style flow that feels
// like meeting a friend, not filling a form. Each step is a single AI message
// (typed out character-by-character) plus an input chip / text field below.
// Previous turns stack as completed bubbles so the user sees the relationship
// growing in real time.
//
// Flow (7 logical steps, ~36% fewer than legacy):
//   0. Welcome (existing WelcomeView, untouched)
//   1. Name
//   2. Faith level
//   3. Life seasons
//   4. Heart burdens
//   5. Notifications + prayer times (merged)
//   6. Paywall (existing PaywallContainerView)
//   7. Done (calls completeOnboarding)
//
// Deferred to Settings (used to be onboarding steps): translation picker,
// aesthetic background picker, widget setup. These had high drop-off and
// low first-day value — they live in Settings now and can be nudged later
// from the home dashboard.

struct ConversationalOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(StoreKitService.self) private var storeKitService
    @State private var viewModel: OnboardingViewModel?
    @State private var convStep: ConversationalStep = .welcome
    /// Set of step ids whose typewriter has finished. Tracking per-step
    /// closes the race where a stale completion from the previous step
    /// would unlock the new page's input area before its own typewriter
    /// had started.
    @State private var completedBubbles: Set<UUID> = []

    // Page-transition orchestration. Two-layer: the incoming page sits
    // at rest at `convStep`, the outgoing page snapshots the previous
    // step and slides/fades off. Subtle horizontal drift + crossfade,
    // not a 3D flip — reads as "turning to the next page" without the
    // UI-gimmick feel a full rotation carries.
    @State private var outgoingStep: ConversationalStep? = nil
    @State private var outgoingOffset: CGFloat = 0
    @State private var outgoingOpacity: Double = 1
    @State private var incomingOffset: CGFloat = 0
    @State private var incomingOpacity: Double = 1

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
                .onAppear {
                    // Welcome's "Begin" calls vm.goNext() which moves the
                    // legacy currentStep from 0 → 1. Watch for that and
                    // transition into the chat flow.
                }
                .onChange(of: vm.currentStep) { _, newValue in
                    if newValue == 1 && convStep == .welcome {
                        beginConversation(vm: vm)
                    }
                }

        case .name, .faith, .seasons, .burdens, .verseIntro, .notifications:
            bookPageContainer(vm: vm)
                .transition(.opacity)

        case .personalVerseReveal:
            // The "reveal act" begins here — palette and scheme flip to dark
            // regardless of user prefs so the cinematic gold-on-midnight
            // aesthetic lands consistently. Main app still respects the
            // user's colorMode after onboarding completes. The transition
            // is a subtle zoom-in on appear so entering feels like stepping
            // into a quieter room, not a page turn.
            PersonalVerseRevealView(viewModel: vm) {
                moveTo(.notifications)
            }
            .preferredColorScheme(.dark)
            .environment(\.bpPalette, BPColorPalette.dark)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.04)),
                removal: .opacity
            ))

        case .background:
            ZStack {
                background
                AestheticView(viewModel: vm) {
                    vm.persistBackground()
                    vm.currentStep = 9
                    advanceFromBackground()
                }
            }
            .transition(.opacity)

        case .journeyReady:
            JourneyReadyView(viewModel: vm) {
                moveTo(.socialProof)
            }
            .preferredColorScheme(.dark)
            .environment(\.bpPalette, BPColorPalette.dark)
            // On exit, JourneyReady zooms OUT (scale 1.06) while fading. This
            // hands off visual momentum to the paywall's entry animation for
            // a continuous "arriving somewhere bigger" feel — the closest we
            // can get to a shared-element transition without reparenting
            // across the switch boundary.
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.04)),
                removal: .opacity.combined(with: .scale(scale: 1.06))
            ))

        case .socialProof:
            // Standalone "Wall of Love" screen between the journey-ready
            // celebration and the paywall. Locked to light palette to
            // visually flow into the paywall that follows.
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
                // Paywall arrives FROM slightly-below-unity so the zoom-out
                // of JourneyReady and zoom-in of paywall overlap in a single
                // continuous camera-push motion. Subtle — the user registers
                // "forward momentum" without naming it.
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

    // MARK: - Book Page Container

    /// Two-layer page stage. The bottom layer is always the current
    /// `convStep`'s page — it's what the user sees at rest and what the
    /// flip reveals. The top layer is only present during a flip: the
    /// step the user is leaving, mounted with rotation/opacity state that
    /// carries it off the spine.
    @ViewBuilder
    private func bookPageContainer(vm: OnboardingViewModel) -> some View {
        ZStack {
            // Incoming / settled page — fills the whole screen.
            BookPageView(pageNumber: convStep.chatIndex + 1) {
                pageContent(step: convStep, vm: vm)
            }
            .id(convStep)
            .opacity(incomingOpacity)
            .offset(x: incomingOffset)

            // Outgoing page — previous step snapshot sliding out. Very
            // gentle horizontal drift paired with a fade; no shadow, no
            // 3D transform. `skipTyping` renders the question instantly
            // at full text so the fresh mount doesn't cause a visible
            // re-type of the line the user just finished reading.
            if let outStep = outgoingStep {
                BookPageView(pageNumber: outStep.chatIndex + 1) {
                    pageContent(step: outStep, vm: vm, skipTyping: true)
                }
                .id("out-\(outStep)")
                .opacity(outgoingOpacity)
                .offset(x: outgoingOffset)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            topBar(vm: vm)
        }
    }

    // MARK: - Per-Page Content

    /// The content inside a single book page — AI question (typewriter)
    /// and the input area that appears once typing finishes.
    @ViewBuilder
    private func pageContent(step: ConversationalStep, vm: OnboardingViewModel, skipTyping: Bool = false) -> some View {
        let stepId = activeTurnId(for: step) ?? UUID()
        let isComplete = completedBubbles.contains(stepId)

        VStack(alignment: .leading, spacing: 0) {
            // Question — stands alone on the page, no chat avatar. Larger
            // size + extra line spacing reads as page typography, not UI.
            // skipTyping=true on the outgoing layer prevents the visible
            // re-type that otherwise happens when the outgoing BookPageView
            // mounts fresh during a transition.
            TypewriterText(
                text: aiMessage(for: step),
                font: .custom("Georgia", size: 25),
                foreground: palette.textPrimary,
                lineSpacing: 9,
                highlightCharacter: step == .name ? "+" : nil,
                highlightSymbol: step == .name ? "sparkle" : nil,
                startCompleted: skipTyping,
                initialDelay: skipTyping ? 0 : 0.65,
                onComplete: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        completedBubbles.insert(stepId)
                    }
                    if step == .verseIntro {
                        HapticService.consecrate()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            moveTo(.personalVerseReveal)
                        }
                    }
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            // Balanced spacers — input block sits centered in the space
            // below the question, action pinned visually toward the page's
            // lower third rather than clustered at the top.
            Spacer(minLength: 32)

            if isComplete {
                inputArea(step: step, vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 14)),
                        removal: .opacity
                    ))
            }

            Spacer(minLength: 48)
        }
    }

    // MARK: - Top Bar

    private func topBar(vm: OnboardingViewModel) -> some View {
        HStack {
            Button {
                HapticService.lightImpact()
                goBack(vm: vm)
            } label: {
                // Minimal chevron — reads as a page-margin glyph rather
                // than a UI chip. Stroked, no filled circle, gold tint.
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentGold.opacity(0.68))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .opacity(canGoBack ? 1 : 0)
            .allowsHitTesting(canGoBack)

            Spacer()

            ProgressDots(
                totalSteps: ConversationalStep.totalChatSteps,
                currentStep: convStep.chatIndex
            )

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var canGoBack: Bool {
        convStep != .welcome && convStep != .name && convStep != .verseIntro
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            // Blurred biblical art — carries the welcome aesthetic through
            Image("biblical_jacob_ladder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 28)
                .scaleEffect(1.15) // crop blur edges
                .clipped()

            // Cool overlay for legibility
            palette.background.opacity(0.82)

            // Very subtle accent tint from top
            LinearGradient(
                stops: [
                    .init(color: palette.accent.opacity(0.06), location: 0.0),
                    .init(color: Color.clear, location: 0.25),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Page Ornaments

    /// Premium sparkle avatar — layered gem with soft halo, thin outer gold
    /// ring, radial-gradient gold disc with inner rim highlight, and a
    /// refined sparkle glyph. The layers create depth — it reads as a gold
    /// token pressed into the page rather than a flat glyph.
    private var premiumSparkleAvatar: some View {
        ZStack {
            // Outer soft halo — very subtle gold wash
            Circle()
                .fill(accentGold.opacity(0.08))
                .frame(width: 44, height: 44)
                .blur(radius: 3)

            // Hairline outer ring — gives the avatar its crisp edge
            Circle()
                .stroke(accentGold.opacity(0.22), lineWidth: 0.5)
                .frame(width: 40, height: 40)

            // Core gold disc with radial gradient for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentGold.opacity(0.35),
                            accentGold.opacity(0.15),
                            accentGold.opacity(0.08)
                        ],
                        center: .init(x: 0.32, y: 0.30),
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    // Inner rim highlight — gives a subtle 3D quality
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    accentGold.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.6
                        )
                )

            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.75),
                            Color(red: 1.0, green: 0.84, blue: 0.3),
                            accentGold
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 2)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6), radius: 6)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Step Ids

    // Stable IDs per step so SwiftUI doesn't remount the typewriter on every
    // body recompute (which would replay the typing animation forever).
    private var nameTurnId: UUID { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
    private var faithTurnId: UUID { UUID(uuidString: "22222222-2222-2222-2222-222222222222")! }
    private var seasonsTurnId: UUID { UUID(uuidString: "33333333-3333-3333-3333-333333333333")! }
    private var burdensTurnId: UUID { UUID(uuidString: "44444444-4444-4444-4444-444444444444")! }
    private var verseIntroTurnId: UUID { UUID(uuidString: "66666666-6666-6666-6666-666666666666")! }
    private var notifTurnId: UUID { UUID(uuidString: "55555555-5555-5555-5555-555555555555")! }

    /// Maps a step to the stable id of its active AI bubble — used by the
    /// scroll-to logic so we can target the right bubble before its content
    /// has started typing.
    private func activeTurnId(for step: ConversationalStep) -> UUID? {
        switch step {
        case .name: return nameTurnId
        case .faith: return faithTurnId
        case .seasons: return seasonsTurnId
        case .burdens: return burdensTurnId
        case .verseIntro: return verseIntroTurnId
        case .notifications: return notifTurnId
        case .welcome, .background, .journeyReady, .paywall, .personalVerseReveal, .socialProof: return nil
        }
    }

    /// True only if the CURRENT step's active bubble has finished typing.
    /// This is the gate for showing the input chips. Computed from the set
    /// of completed bubble ids so it can never be in the wrong state due to
    /// a stale completion from the previous step.
    private var isCurrentBubbleComplete: Bool {
        guard let id = activeTurnId(for: convStep) else { return false }
        return completedBubbles.contains(id)
    }

    // MARK: - AI Messages

    private func aiMessage(for step: ConversationalStep) -> String {
        let name = (viewModel?.firstName.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 }

        switch step {
        case .welcome, .background, .journeyReady, .paywall, .personalVerseReveal, .socialProof:
            return ""
        case .name:
            return "Hey there, welcome to Bible+, your companion for prayer, Scripture, and the seasons in between. What should I call you?"
        case .faith:
            return "Nice to meet you, \(name ?? "friend"). So I can tailor things — where are you on your faith journey right now?"
        case .seasons:
            return "Got it. What season of life are you in? Pick whatever fits — I'll know what to send you when."
        case .burdens:
            return "And what's weighing on your heart these days? Be honest — this stays between us, and it shapes everything I send you."
        case .verseIntro:
            return "Thank you for trusting me with that. Based on what you've shared, there's a verse I want you to read first…"
        case .notifications:
            return "I'd love to be there when you need a verse. Want me to send a few gentle moments throughout your day?"
        }
    }

    // MARK: - Input Area

    @ViewBuilder
    private func inputArea(step: ConversationalStep, vm: OnboardingViewModel) -> some View {
        switch step {
        case .welcome, .background, .journeyReady, .paywall, .personalVerseReveal, .verseIntro, .socialProof:
            // .verseIntro auto-advances into the cinematic reveal once the
            // typewriter finishes — no user input is collected, so no chip
            // area is shown. .socialProof is a standalone screen with its
            // own internal Continue CTA.
            EmptyView()
        case .name:
            nameInput(vm: vm)
        case .faith:
            faithInput(vm: vm)
        case .seasons:
            seasonsInput(vm: vm)
        case .burdens:
            burdensInput(vm: vm)
        case .notifications:
            notificationsInput(vm: vm)
        }
    }

    // Name input — premium warm card with gold focus glow
    private func nameInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 14) {
            PremiumNameField(
                text: Binding(
                    get: { vm.firstName },
                    set: { vm.firstName = $0 }
                ),
                palette: palette,
                accentGold: accentGold,
                onSubmit: { advanceFromName(vm: vm) }
            )

            primaryButton(label: "Continue", enabled: !vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty) {
                advanceFromName(vm: vm)
            }
        }
    }

    // Faith input — single-select rows with the same premium card
    // language as the chip grid. Larger typography because each row is
    // a full-width row rather than a 2-column chip.
    private func faithInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 9) {
            ForEach(FaithLevel.allCases, id: \.self) { level in
                let isSelected = vm.selectedFaithLevel == level
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        vm.selectedFaithLevel = level
                    }
                    HapticService.chipTap()
                } label: {
                    HStack(spacing: 12) {
                        Text(level.displayName)
                            .font(.custom("Georgia-Bold", size: 18))
                            .foregroundStyle(isSelected ? .white : palette.textPrimary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.6).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(chipBackground(isSelected: isSelected))
                    .overlay(chipBorder(isSelected: isSelected))
                    .shadow(
                        color: isSelected ? palette.accent.opacity(0.28) : .black.opacity(0.05),
                        radius: isSelected ? 12 : 7,
                        y: isSelected ? 5 : 3
                    )
                    .scaleEffect(isSelected ? 1.015 : 1.0)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: vm.selectedFaithLevel)

            primaryButton(label: "Continue", enabled: vm.selectedFaithLevel != nil) {
                advanceFromFaith(vm: vm)
            }
            .padding(.top, 6)
        }
    }

    // Seasons input — chip grid (multi-select up to 3)
    private func seasonsInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 12) {
            chipGrid(
                items: LifeSeason.allCases,
                selected: vm.selectedLifeSeasons,
                label: { $0.displayName },
                toggle: { vm.toggleLifeSeason($0) }
            )

            primaryButton(label: "Continue", enabled: !vm.selectedLifeSeasons.isEmpty) {
                advanceFromSeasons(vm: vm)
            }
        }
    }

    // Burdens input — chip grid (multi-select up to 3)
    private func burdensInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 12) {
            chipGrid(
                items: Burden.allCases,
                selected: vm.selectedBurdens,
                label: { $0.displayName },
                toggle: { vm.toggleBurden($0) }
            )

            primaryButton(label: "Continue", enabled: !vm.selectedBurdens.isEmpty) {
                advanceFromBurdens(vm: vm)
            }
        }
    }

    // Notifications input — Yes/No, then prayer time chips if Yes
    @ViewBuilder
    private func notificationsInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 14) {
            // Prayer time chips appear after the user picks a time of day,
            // but the simpler MVP path is: tap Yes → grant permission +
            // collect all 4 prayer time options inline, OR tap Not now → skip.
            chipGrid(
                items: PrayerTimeSlot.allCases,
                selected: vm.selectedPrayerTimes,
                label: { $0.displayName },
                toggle: { vm.togglePrayerTime($0) }
            )

            HStack(spacing: 10) {
                secondaryButton(label: "Not now") {
                    advanceFromNotifications(vm: vm, enableNotifications: false)
                }
                primaryButton(label: "Send me verses", enabled: !vm.selectedPrayerTimes.isEmpty) {
                    advanceFromNotifications(vm: vm, enableNotifications: true)
                }
            }
        }
    }

    // MARK: - Generic chip grid

    private func chipGrid<Item: Hashable>(
        items: [Item],
        selected: Set<Item>,
        label: @escaping (Item) -> String,
        toggle: @escaping (Item) -> Void
    ) -> some View {
        let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        return LazyVGrid(columns: columns, spacing: 9) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        toggle(item)
                    }
                    HapticService.chipTap()
                } label: {
                    HStack(spacing: 6) {
                        Text(label(item))
                            .font(.custom("Georgia-Bold", size: 16))
                            .foregroundStyle(isSelected ? .white : palette.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            // Longer labels ("Purpose & Direction",
                            // "Relationship Pain") were truncating to "…"
                            // on narrower iPhones (e.g., 15 Pro). Allow
                            // the text to tighten and scale down to 80%
                            // before giving up and clipping.
                            .minimumScaleFactor(0.80)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.4).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(chipBackground(isSelected: isSelected))
                    .overlay(chipBorder(isSelected: isSelected))
                    .shadow(
                        color: isSelected ? palette.accent.opacity(0.28) : .black.opacity(0.05),
                        radius: isSelected ? 10 : 6,
                        y: isSelected ? 4 : 3
                    )
                    .scaleEffect(isSelected ? 1.025 : 1.0)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)
    }

    /// Selected chips use a rich gold gradient + inner sheen — reads as a
    /// premium gold gem, not a flat fill. Unselected chips use a warm
    /// palette card gradient (matches the premium dark-mode card language
    /// from the paywall) with a faint gold sheen on top.
    private func chipBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [
                            palette.accent,
                            palette.accent.opacity(0.82)
                          ]
                        : [
                            palette.surfaceElevated.opacity(0.92),
                            palette.surface.opacity(0.72)
                          ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.white.opacity(0.18), .clear]
                                : [accentGold.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
    }

    private func chipBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .stroke(
                LinearGradient(
                    colors: isSelected
                        ? [
                            Color.white.opacity(0.35),
                            palette.accent.opacity(0.4)
                          ]
                        : [
                            accentGold.opacity(0.28),
                            palette.border.opacity(0.22)
                          ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 1.0 : 0.7
            )
    }

    // MARK: - Buttons

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private func primaryButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.stepAdvance()
            action()
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.custom("Georgia-Bold", size: 18))
                    .tracking(0.3)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                // Warm palette gradient base — matches dark-mode CTA
                // language from the paywall. No more neutral-gray
                // ultraThinMaterial on the primary action.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.surfaceElevated.opacity(0.95),
                                palette.surface.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(
                Capsule().fill(accentGold.opacity(0.15))
            )
            .overlay(
                // Top gold sheen for depth
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentGold.opacity(0.14), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentGold.opacity(0.65),
                                palette.border.opacity(0.25),
                                accentGold.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: accentGold.opacity(enabled ? 0.32 : 0), radius: 14, y: 5)
            .shadow(color: .black.opacity(enabled ? 0.08 : 0), radius: 5, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
        .scaleEffect(enabled ? 1.0 : 0.985)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: enabled)
    }

    private func secondaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.stepAdvance()
            action()
        } label: {
            Text(label)
                .font(.custom("Georgia-Bold", size: 17))
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.border.opacity(0.18), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step Transitions

    private enum FlipDirection {
        case forward   // current page peels off to the left (spine = leading)
        case backward  // current page peels back to the right (spine = trailing)
    }

    private func beginConversation(vm: OnboardingViewModel) {
        // The legacy view model just moved from step 0 → 1. Switch our
        // conversational step to .name. Future navigation no longer
        // touches vm.currentStep until we hand off to the paywall.
        withAnimation(BPAnimation.spring) {
            convStep = .name
        }
    }

    private func advanceFromName(vm: OnboardingViewModel) {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        vm.persistName()
        HapticService.commit()
        flipToNext(.faith)
    }

    private func advanceFromFaith(vm: OnboardingViewModel) {
        guard vm.selectedFaithLevel != nil else { return }
        vm.persistFaithLevel()
        flipToNext(.seasons)
    }

    private func advanceFromSeasons(vm: OnboardingViewModel) {
        guard !vm.selectedLifeSeasons.isEmpty else { return }
        vm.persistLifeSeasons()
        flipToNext(.burdens)
    }

    private func advanceFromBurdens(vm: OnboardingViewModel) {
        guard !vm.selectedBurdens.isEmpty else { return }
        vm.persistBurdens()
        HapticService.commit()
        // The verseIntro page is a bridge — its typewriter finishing is
        // the cue to auto-advance into the cinematic reveal (handled in
        // pageContent's onComplete).
        flipToNext(.verseIntro)
    }

    private func advanceFromNotifications(vm: OnboardingViewModel, enableNotifications: Bool) {
        if enableNotifications && !vm.selectedPrayerTimes.isEmpty {
            vm.persistPrayerTimes()
            Task { await vm.requestNotificationPermissionStandalone() }
        }

        // Park the legacy view model at the aesthetic step (8) so the
        // background picker has the right context. The conversational view
        // bypasses translation (5) and notif perm view (7) — those are
        // deferred to Settings.
        vm.currentStep = 8

        // Background is not a page — use the regular cross-fade.
        moveTo(.background)
    }

    private func advanceFromBackground() {
        moveTo(.journeyReady)
    }

    /// Subtle slide + crossfade between pages. The incoming page starts
    /// slightly offset in the entry direction and fades up; the outgoing
    /// page drifts the opposite way and fades out. Intentionally small
    /// (~28pt) so it reads as a page settling, not a full-width carousel.
    private func flipToNext(_ next: ConversationalStep, direction: FlipDirection = .forward) {
        guard outgoingStep == nil else { return }
        HapticService.lightImpact()

        let distance: CGFloat = 28
        let outgoingTarget: CGFloat = (direction == .forward) ? -distance : distance
        let incomingStart: CGFloat = (direction == .forward) ? distance : -distance

        // Phase 1 — set the "starting" state synchronously:
        //   • outgoing layer shows the previous step at rest, on top
        //   • incoming layer's new step is rendered underneath but
        //     hidden (opacity 0) and offset in from the entry side
        outgoingStep = convStep
        outgoingOffset = 0
        outgoingOpacity = 1
        incomingOffset = incomingStart
        incomingOpacity = 0
        convStep = next

        // Phase 2 — defer the animations to the next run loop so SwiftUI
        // actually renders the "incoming hidden" frame before we animate
        // it back in. Without this, all three of (previous=1, reset=0,
        // animated=1) collapse into a single transaction and SwiftUI
        // optimizes the 1→1 as a no-op, briefly showing the new page at
        // full opacity before the slide begins.
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.4, 0, 0.7, 0.2, duration: 0.42)) {
                outgoingOffset = outgoingTarget
                outgoingOpacity = 0
            }
            withAnimation(.timingCurve(0.2, 0.9, 0.2, 1.0, duration: 0.5).delay(0.08)) {
                incomingOffset = 0
                incomingOpacity = 1
            }
        }

        // Clean up the outgoing layer once both motions have settled.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            outgoingStep = nil
        }
    }

    /// Non-flip transition for handoffs between chat and non-chat screens
    /// (verse reveal, background, journey ready, paywall). Uses the
    /// container's `.transition(.opacity)` for a gentle cross-fade.
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

        // Forget the prior completion for the destination step so its
        // typewriter replays from the start when the user lands back on it.
        if let prevId = activeTurnId(for: prev) {
            completedBubbles.remove(prevId)
        }

        flipToNext(prev, direction: .backward)
    }

    private func previousStep() -> ConversationalStep? {
        switch convStep {
        case .name, .welcome, .journeyReady, .paywall, .personalVerseReveal, .verseIntro, .socialProof: return nil
        case .faith: return .name
        case .seasons: return .faith
        case .burdens: return .seasons
        case .notifications: return .burdens
        case .background: return .notifications
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
    case verseIntro
    case personalVerseReveal
    case notifications
    case background
    case journeyReady
    case socialProof
    case paywall

    /// Index in the chat-progress dots (0-based). Welcome and paywall don't
    /// participate in the progress dots — they're either the entry or the
    /// final commitment. Background sits at the end of the chat sequence,
    /// right before paywall. The verse reveal is a standalone moment
    /// (no dots) so it feels like a gift rather than another survey step.
    /// `verseIntro` sits between burdens and the reveal as an AI-typed
    /// bridge line ("here's a verse for you...") so the dark cinematic
    /// cut doesn't feel like a pop-up. It shares the burdens index so
    /// the dots don't flicker during the tiny interstitial.
    var chatIndex: Int {
        switch self {
        case .welcome: return 0
        case .name: return 0
        case .faith: return 1
        case .seasons: return 2
        case .burdens: return 3
        case .verseIntro: return 3
        case .personalVerseReveal: return 3
        case .notifications: return 4
        case .background: return 5
        case .journeyReady: return 6
        case .socialProof: return 7
        case .paywall: return 7
        }
    }

    // Total dots shown in the chat progress indicator. Visible chat steps:
    // name, faith, seasons, burdens, firstLight, notifications. Non-chat
    // screens (welcome, journeyReady, paywall) and screens moved to Settings
    // (background) don't count toward this total.
    static let totalChatSteps: Int = 6
}


// MARK: - Premium Name Field
//
// Standalone component so @FocusState works cleanly. Gold focus glow
// and stroke intensify when the field is active — feels like a premium
// editorial input, not a system TextField.
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.surfaceElevated.opacity(0.95),
                                palette.surface.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentGold.opacity(isFocused ? 0.10 : 0.05),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentGold.opacity(isFocused ? 0.72 : 0.28),
                                palette.border.opacity(isFocused ? 0.4 : 0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isFocused ? 1.1 : 0.7
                    )
            )
            .shadow(
                color: accentGold.opacity(isFocused ? 0.22 : 0.08),
                radius: isFocused ? 14 : 6,
                y: 4
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isFocused)
            .submitLabel(.continue)
            .onSubmit { onSubmit() }
    }
}
