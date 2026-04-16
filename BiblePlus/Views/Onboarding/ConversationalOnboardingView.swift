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
    @State private var turns: [ConversationTurn] = []
    /// Set of bubble ids whose typewriter has finished. Tracking per-bubble
    /// (instead of a single bool) closes the race where the previous step's
    /// late `onComplete` would flip a shared "complete" flag AFTER we'd
    /// already advanced to the next step.
    @State private var completedBubbles: Set<UUID> = []

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

        case .name, .faith, .seasons, .burdens, .notifications:
            chatScreen(vm: vm)
                .transition(.opacity)

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

        case .paywall:
            PaywallContainerView(viewModel: vm)
                .transition(.opacity)
                .onChange(of: vm.currentStep) { _, newValue in
                    // Paywall sits at legacy currentStep 9. The existing
                    // paywall flow advances to step 10 when complete (or
                    // when skipped). That's our cue to finish onboarding.
                    if newValue >= 10 && convStep == .paywall {
                        finishOnboarding(vm: vm)
                    }
                }
        }
    }

    // MARK: - Chat Screen

    @ViewBuilder
    private func chatScreen(vm: OnboardingViewModel) -> some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar(vm: vm)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(turns) { turn in
                                turnView(turn)
                                    .id(turn.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 14)),
                                        removal: .opacity
                                    ))
                            }

                            // Currently typing message
                            if let active = activeTurn {
                                aiBubble(
                                    text: active.aiMessage,
                                    animateTyping: true,
                                    highlightPlus: convStep == .name
                                ) {
                                    // Mark THIS specific bubble as complete.
                                    // Per-bubble tracking eliminates the
                                    // race where a stale completion from a
                                    // previous step would unlock the chips.
                                    let bubbleId = active.id
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                        completedBubbles.insert(bubbleId)
                                    }
                                }
                                .id(active.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 12)),
                                    removal: .opacity
                                ))
                            }

                            // Input chips/buttons live INSIDE the scroll
                            // and directly under the active AI bubble — so
                            // they read as the natural next thing in the
                            // conversation, not as a fixed bottom toolbar.
                            if isCurrentBubbleComplete {
                                inputArea(vm: vm)
                                    .padding(.top, 4)
                                    .id("input-area")
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 18)),
                                        removal: .opacity
                                    ))
                            }

                            Color.clear.frame(height: 24).id("bottom")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: turns.count) { _, _ in
                        // A new turn just committed → scroll its bubble into
                        // view so the user sees their answer land cleanly
                        // before the next AI message starts typing.
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: convStep) { _, newStep in
                        // Step changed → scroll the NEW active AI bubble to
                        // the top of the visible area so the user watches it
                        // type. Chips will slide in directly under it once
                        // the typewriter finishes. The 100ms delay lets the
                        // bubble's insertion transition begin before we
                        // chase it with the scroll, so the two animations
                        // overlap into one continuous motion.
                        guard let activeId = activeTurnId(for: newStep) else { return }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            withAnimation(.spring(response: 0.65, dampingFraction: 0.86)) {
                                proxy.scrollTo(activeId, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: completedBubbles) { _, _ in
                        // The active bubble just finished typing → chips
                        // are sliding in directly underneath. Slide the
                        // page up so both the question AND the chips fit
                        // in the visible area together. Same spring as the
                        // chips' own insertion transition so they animate
                        // as one unit.
                        guard isCurrentBubbleComplete else { return }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 80_000_000)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        // No `.id(convStep)` here — keeping the ScrollView mounted across
        // steps preserves scroll position, prevents flashes, and lets new
        // bubbles animate IN instead of being part of a hard remount.
        // The TypewriterText still gets a fresh mount per step because the
        // active aiBubble is keyed by `.id(active.id)`.
    }

    // MARK: - Top Bar

    private func topBar(vm: OnboardingViewModel) -> some View {
        HStack {
            Button {
                HapticService.lightImpact()
                goBack(vm: vm)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .opacity(canGoBack ? 1 : 0)
            .allowsHitTesting(canGoBack)

            Spacer()

            ProgressDots(
                totalSteps: ConversationalStep.totalChatSteps,
                currentStep: convStep.chatIndex
            )

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var canGoBack: Bool {
        convStep != .welcome && convStep != .name
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

            // Warm cream overlay for legibility (heavier than welcome)
            palette.background.opacity(0.72)

            // Subtle warm tint from top
            LinearGradient(
                stops: [
                    .init(color: palette.accent.opacity(0.12), location: 0.0),
                    .init(color: Color.clear, location: 0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Bubbles

    private func turnView(_ turn: ConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            aiBubble(
                text: turn.aiMessage,
                animateTyping: false,
                highlightPlus: turn.id == nameTurnId,
                onComplete: nil
            )

            if let response = turn.userResponse, !response.isEmpty {
                userBubble(text: response)
            }
        }
    }

    private func aiBubble(
        text: String,
        animateTyping: Bool,
        highlightPlus: Bool = false,
        onComplete: (() -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Sparkle avatar — bright golden gradient matching the Bible+ logo
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.08))
                    .frame(width: 38, height: 38)

                Circle()
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.92, blue: 0.55).opacity(0.4),
                                        accentGold.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )

                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.6),
                                Color(red: 1.0, green: 0.84, blue: 0.3),
                                accentGold
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.7), radius: 10)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.4), radius: 20)
            }
            .padding(.top, 4)

            if animateTyping {
                TypewriterText(
                    text: text,
                    font: .custom("Georgia", size: 20),
                    foreground: palette.textPrimary,
                    lineSpacing: 7,
                    highlightCharacter: highlightPlus ? "+" : nil,
                    highlightSymbol: highlightPlus ? "sparkle" : nil,
                    onComplete: onComplete
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                inlineStaticText(text: text, highlightPlus: highlightPlus)
            }
        }
    }

    /// Static (non-typing) version of the AI message — used for committed
    /// turns that re-render after the user has answered. When `highlightPlus`
    /// is true, the "+" is replaced with an inline `sparkle` SF Symbol with
    /// the same gold-glow treatment as the welcome screen logo so the visual
    /// signature persists in the history stack.
    @ViewBuilder
    private func inlineStaticText(text: String, highlightPlus: Bool) -> some View {
        if highlightPlus {
            ZStack(alignment: .topLeading) {
                buildSparkleText(text, mode: .base)
                buildSparkleText(text, mode: .overlay)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.7), radius: 20)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.4), radius: 40)
            }
        } else {
            Text(text)
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(7)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private enum SparkleLayer { case base, overlay }

    private func buildSparkleText(_ text: String, mode: SparkleLayer) -> some View {
        let gold = Color(red: 1.0, green: 0.84, blue: 0.3)
        let baseColor: Color = (mode == .overlay) ? .clear : palette.textPrimary
        let sparkleColor: Color = (mode == .overlay) ? gold : .clear

        var result = Text("")
        var run = ""

        func flushRun() {
            if !run.isEmpty {
                result = result + Text(run).foregroundColor(baseColor)
                run = ""
            }
        }

        for ch in text {
            if ch == "+" {
                flushRun()
                result = result + Text(Image(systemName: "sparkle")).foregroundColor(sparkleColor)
            } else {
                run.append(ch)
            }
        }
        flushRun()

        return result
            .font(.custom("Georgia", size: 20))
            .lineSpacing(7)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func userBubble(text: String) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.25), radius: 6, y: 2)
                )
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)),
            removal: .opacity
        ))
    }

    // MARK: - Active Turn

    /// The currently typing AI message — this is the prompt for the current
    /// step that hasn't yet had a user response. Returns nil while the
    /// conversational turn is in transition.
    private var activeTurn: ConversationTurn? {
        switch convStep {
        case .welcome, .paywall:
            return nil
        case .name where !turns.contains(where: { $0.id == nameTurnId }):
            return ConversationTurn(id: nameTurnId, aiMessage: aiMessage(for: .name), userResponse: nil)
        case .faith where !turns.contains(where: { $0.id == faithTurnId }):
            return ConversationTurn(id: faithTurnId, aiMessage: aiMessage(for: .faith), userResponse: nil)
        case .seasons where !turns.contains(where: { $0.id == seasonsTurnId }):
            return ConversationTurn(id: seasonsTurnId, aiMessage: aiMessage(for: .seasons), userResponse: nil)
        case .burdens where !turns.contains(where: { $0.id == burdensTurnId }):
            return ConversationTurn(id: burdensTurnId, aiMessage: aiMessage(for: .burdens), userResponse: nil)
        case .notifications where !turns.contains(where: { $0.id == notifTurnId }):
            return ConversationTurn(id: notifTurnId, aiMessage: aiMessage(for: .notifications), userResponse: nil)
        default:
            return nil
        }
    }

    // Stable IDs per step so SwiftUI doesn't remount the typewriter on every
    // body recompute (which would replay the typing animation forever).
    private var nameTurnId: UUID { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
    private var faithTurnId: UUID { UUID(uuidString: "22222222-2222-2222-2222-222222222222")! }
    private var seasonsTurnId: UUID { UUID(uuidString: "33333333-3333-3333-3333-333333333333")! }
    private var burdensTurnId: UUID { UUID(uuidString: "44444444-4444-4444-4444-444444444444")! }
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
        case .notifications: return notifTurnId
        case .welcome, .background, .paywall: return nil
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
        case .welcome, .background, .paywall:
            return ""
        case .name:
            return "Hey there, welcome to Bible+, your companion for prayer, Scripture, and the seasons in between. What should I call you?"
        case .faith:
            return "Nice to meet you, \(name ?? "friend"). So I can tailor things — where are you on your faith journey right now?"
        case .seasons:
            return "Got it. What season of life are you in? Pick whatever fits — I'll know what to send you when."
        case .burdens:
            return "And what's weighing on your heart these days? Be honest — this stays between us, and it shapes everything I send you."
        case .notifications:
            return "I'd love to be there when you need a verse. Want me to send a few gentle moments throughout your day?"
        }
    }

    // MARK: - Input Area

    @ViewBuilder
    private func inputArea(vm: OnboardingViewModel) -> some View {
        switch convStep {
        case .welcome, .background, .paywall:
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

    // Name input — frosted text field + Continue
    private func nameInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 14) {
            TextField("Your name", text: Binding(
                get: { vm.firstName },
                set: { vm.firstName = $0 }
            ))
            .font(.custom("Georgia", size: 17))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.7))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
            )
            .submitLabel(.continue)
            .onSubmit {
                advanceFromName(vm: vm)
            }

            primaryButton(label: "Continue", enabled: !vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty) {
                advanceFromName(vm: vm)
            }
        }
    }

    // Faith input — single-select rows
    private func faithInput(vm: OnboardingViewModel) -> some View {
        VStack(spacing: 8) {
            ForEach(FaithLevel.allCases, id: \.self) { level in
                let isSelected = vm.selectedFaithLevel == level
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        vm.selectedFaithLevel = level
                    }
                    HapticService.selection()
                } label: {
                    HStack(spacing: 12) {
                        Text(level.displayName)
                            .font(.custom("Georgia-Bold", size: 16))
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
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected
                                ? AnyShapeStyle(palette.accent)
                                : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .opacity(isSelected ? 1 : 0.6)
                            .shadow(
                                color: isSelected ? palette.accent.opacity(0.25) : .black.opacity(0.04),
                                radius: isSelected ? 10 : 6,
                                y: isSelected ? 4 : 3
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? palette.accent.opacity(0.8) : palette.accent.opacity(0.15),
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    )
                    .scaleEffect(isSelected ? 1.015 : 1.0)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: vm.selectedFaithLevel)

            primaryButton(label: "Continue", enabled: vm.selectedFaithLevel != nil) {
                advanceFromFaith(vm: vm)
            }
            .padding(.top, 4)
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
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        toggle(item)
                    }
                    HapticService.selection()
                } label: {
                    Text(label(item))
                        .font(.custom("Georgia-Bold", size: 14))
                        .foregroundStyle(isSelected ? .white : palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected
                                    ? AnyShapeStyle(palette.accent)
                                    : AnyShapeStyle(.ultraThinMaterial)
                                )
                                .opacity(isSelected ? 1 : 0.6)
                                .shadow(
                                    color: isSelected ? palette.accent.opacity(0.25) : .black.opacity(0.04),
                                    radius: isSelected ? 8 : 5,
                                    y: isSelected ? 4 : 3
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? palette.accent.opacity(0.8) : palette.accent.opacity(0.15),
                                    lineWidth: isSelected ? 1 : 0.5
                                )
                        )
                        .scaleEffect(isSelected ? 1.02 : 1.0)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)
    }

    // MARK: - Buttons

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private func primaryButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.lightImpact()
            action()
        } label: {
            Text(label)
                .font(.custom("Georgia-Bold", size: 16))
                .tracking(0.3)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.6))
                )
                .background(
                    Capsule()
                        .fill(accentGold.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentGold.opacity(0.5),
                                    palette.border.opacity(0.2),
                                    accentGold.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: accentGold.opacity(enabled ? 0.2 : 0), radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .scaleEffect(enabled ? 1.0 : 0.985)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: enabled)
    }

    private func secondaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.lightImpact()
            action()
        } label: {
            Text(label)
                .font(.custom("Georgia-Bold", size: 16))
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

    private func beginConversation(vm: OnboardingViewModel) {
        // The legacy view model just moved from step 0 → 1. Switch our
        // conversational step to .name and reset bookkeeping. Future
        // navigation no longer touches vm.currentStep until we hand off to
        // the paywall.
        withAnimation(BPAnimation.spring) {
            convStep = .name
        }
    }

    private func advanceFromName(vm: OnboardingViewModel) {
        let name = vm.firstName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        commitTurn(id: nameTurnId, aiMessage: aiMessage(for: .name), userResponse: name)
        vm.persistName()
        moveTo(.faith)
    }

    private func advanceFromFaith(vm: OnboardingViewModel) {
        guard let level = vm.selectedFaithLevel else { return }
        commitTurn(id: faithTurnId, aiMessage: aiMessage(for: .faith), userResponse: level.displayName)
        vm.persistFaithLevel()
        moveTo(.seasons)
    }

    private func advanceFromSeasons(vm: OnboardingViewModel) {
        guard !vm.selectedLifeSeasons.isEmpty else { return }
        let response = vm.selectedLifeSeasons
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: ", ")
        commitTurn(id: seasonsTurnId, aiMessage: aiMessage(for: .seasons), userResponse: response)
        vm.persistLifeSeasons()
        moveTo(.burdens)
    }

    private func advanceFromBurdens(vm: OnboardingViewModel) {
        guard !vm.selectedBurdens.isEmpty else { return }
        let response = vm.selectedBurdens
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: ", ")
        commitTurn(id: burdensTurnId, aiMessage: aiMessage(for: .burdens), userResponse: response)
        vm.persistBurdens()
        moveTo(.notifications)
    }

    private func advanceFromNotifications(vm: OnboardingViewModel, enableNotifications: Bool) {
        let response: String
        if enableNotifications && !vm.selectedPrayerTimes.isEmpty {
            let times = vm.selectedPrayerTimes
                .sorted { $0.rawValue < $1.rawValue }
                .map(\.displayName)
                .joined(separator: ", ")
            response = "Yes — \(times)"
            vm.persistPrayerTimes()
            Task { await vm.requestNotificationPermissionStandalone() }
        } else {
            response = "Maybe later"
        }
        commitTurn(id: notifTurnId, aiMessage: aiMessage(for: .notifications), userResponse: response)

        // Park the legacy view model at the aesthetic step (8) so the
        // background picker has the right context. The conversational view
        // bypasses translation (5) and notif perm view (7) — those are
        // deferred to Settings.
        vm.currentStep = 8

        moveTo(.background)
    }

    private func advanceFromBackground() {
        // The AestheticView's Continue button has already persisted the
        // background and bumped legacy currentStep to 9. We just need to
        // slide our conversational step to .paywall.
        moveTo(.paywall)
    }

    private func commitTurn(id: UUID, aiMessage: String, userResponse: String) {
        // If we already added this turn (duplicate tap), don't reappend.
        guard !turns.contains(where: { $0.id == id }) else { return }
        let completed = ConversationTurn(id: id, aiMessage: aiMessage, userResponse: userResponse)
        // Soft, slightly bouncy spring — the appended turn slides up from
        // below as part of the same animation that removes the active bubble.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            turns.append(completed)
        }
    }

    private func moveTo(_ next: ConversationalStep) {
        // Tiny breath so the user's response bubble has a beat to settle
        // before the new AI message starts typing. Feels intentional, not
        // mechanical.
        //
        // Note: we don't have to reset any "isComplete" flag because
        // completion is now tracked per-bubble via `completedBubbles`.
        // The new step's bubble id won't be in that set until its own
        // typewriter finishes — `isCurrentBubbleComplete` returns false
        // automatically.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                convStep = next
            }
        }
    }

    private func goBack(vm: OnboardingViewModel) {
        guard let prev = previousStep() else { return }

        // Pop the most recent committed turn for the destination step so the
        // user can re-answer it.
        switch prev {
        case .name: removeTurn(id: nameTurnId)
        case .faith: removeTurn(id: faithTurnId)
        case .seasons: removeTurn(id: seasonsTurnId)
        case .burdens: removeTurn(id: burdensTurnId)
        case .notifications: removeTurn(id: notifTurnId)
        default: break
        }

        // Forget any prior completion for the destination bubble so its
        // typewriter replays from the start and the chips stay hidden until
        // it finishes.
        if let prevId = activeTurnId(for: prev) {
            completedBubbles.remove(prevId)
        }

        withAnimation(BPAnimation.spring) {
            convStep = prev
        }
    }

    private func removeTurn(id: UUID) {
        if let index = turns.firstIndex(where: { $0.id == id }) {
            turns.remove(at: index)
        }
    }

    private func previousStep() -> ConversationalStep? {
        switch convStep {
        case .name, .welcome, .paywall: return nil
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
    case notifications
    case background
    case paywall

    /// Index in the chat-progress dots (0-based). Welcome and paywall don't
    /// participate in the progress dots — they're either the entry or the
    /// final commitment. Background sits at the end of the chat sequence,
    /// right before paywall.
    var chatIndex: Int {
        switch self {
        case .welcome: return 0
        case .name: return 0
        case .faith: return 1
        case .seasons: return 2
        case .burdens: return 3
        case .notifications: return 4
        case .background: return 5
        case .paywall: return 6
        }
    }

    static let totalChatSteps: Int = 6
}

private struct ConversationTurn: Identifiable, Equatable {
    let id: UUID
    let aiMessage: String
    var userResponse: String?
}
