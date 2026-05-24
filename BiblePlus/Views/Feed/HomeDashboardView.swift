import SwiftUI

// MARK: - Home Dashboard (Chat-First)
//
// One main page, composer at the center. The app's most differentiated
// feature is the AI companion, so we put a real text input on the home
// screen as the primary affordance. Reference apps: Haven, Bible Chat,
// Truthly — all converged on this pattern.
//
// Layout, top to bottom:
//   1. Top bar — Bible glyph (left) · wordmark (center) · profile (right)
//   2. Verse of the day — compact italic + reference, tappable
//   3. Streak strip — 7 dots, quiet anchor
//   4. (vertical breathing room)
//   5. Composer — TextField pinned via .safeAreaInset(.bottom)
//   6. Prompt chips — 3 contextual chips below the composer
//
// Every infinite-repeat animation that was on the previous dashboard
// (glow pulse, floating chevron, rotating composer halo) is gone. The
// only motion left is one-shot appearance + a single focus-state border
// transition. End state: home has zero forever-running animations.
struct HomeDashboardView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService

    // Callbacks preserved for API compat with ContentView. Feed entry
    // and Continue Reading are no longer surfaced on home — Bible Reader
    // is reached via the top-bar book glyph, the Feed is shelved.
    let onEnterFeed: () -> Void
    let onShowProgress: () -> Void
    let onDailyVerseTap: () -> Void
    let onContinueReading: () -> Void
    let onOpenSanctuary: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @State private var animateStreak = false
    @State private var showReadingPlans = false
    @State private var appeared = false
    @State private var composerText: String = ""
    @FocusState private var composerFocused: Bool

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let dayWeekdays = [2, 3, 4, 5, 6, 7, 1]

    // MARK: - Body

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 22) {
                topBar
                compactVerseLine
                streakStrip
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            // Composer + chips pinned to the bottom safe area. SwiftUI's
            // default keyboard avoidance lifts this inset with the keyboard,
            // so the composer stays visible while typing without manual
            // offset math.
            VStack(spacing: 10) {
                homeComposer
                promptChips
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showReadingPlans) {
            ReadingPlansView(isPro: vm.profile.isPro)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateStreak = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPlansFromWidget)) { _ in
            showReadingPlans = true
        }
        .onTapGesture {
            // Tap anywhere outside the composer dismisses the keyboard.
            // Important on a chat-first surface — the composer is the
            // primary interactive element, so users need a way out.
            if composerFocused {
                composerFocused = false
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            bibleGlyph
            Spacer()
            wordmark
            Spacer()
            profileAvatar
        }
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var bibleGlyph: some View {
        Button {
            HapticService.lightImpact()
            NotificationCenter.default.post(name: .switchToBibleTab, object: nil)
        } label: {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                )
                .overlay(
                    Circle()
                        .stroke(palette.border.opacity(0.35), lineWidth: 0.5)
                )
        }
        .accessibilityLabel("Open Bible Reader")
    }

    private var wordmark: some View {
        HStack(spacing: 2) {
            Text("Bible")
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 3)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.4), radius: 8)
        }
    }

    private var profileAvatar: some View {
        Button {
            HapticService.lightImpact()
            // Phase 1 routes profile tap to Settings tab. Phase 3 replaces
            // this with the side drawer (History · Saved · Progress · Plans
            // · Sanctuary · Settings).
            NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                if let data = vm.profile.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(vm.profile.firstName.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .accessibilityLabel("Open menu")
    }

    // MARK: - Compact Verse Line

    @ViewBuilder
    private var compactVerseLine: some View {
        if let verse = vm.dailyVerse {
            Button {
                onDailyVerseTap()
                HapticService.lightImpact()
            } label: {
                VStack(spacing: 5) {
                    Text("\u{201C}\(truncatedVerse(verse.text))\u{201D}")
                        .font(.custom("Georgia-Italic", size: 15))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .lineLimit(2)

                    Text(verse.reference)
                        .font(.custom("Georgia", size: 11))
                        .foregroundStyle(palette.accent.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.08), value: appeared)
        }
    }

    /// Trims verse text to ~110 chars at a natural word boundary so the
    /// quiet two-line layout never wraps awkwardly.
    private func truncatedVerse(_ text: String) -> String {
        let maxLength = 110
        guard text.count > maxLength else { return text }
        let prefix = text.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(text[text.startIndex..<lastSpace]) + "..."
        }
        return String(prefix) + "..."
    }

    // MARK: - Streak Strip
    //
    // Card-less strip — just flame + label + 7 dots. The previous card
    // version was visually competing with the composer for attention on
    // a chat-first home. Without a card it reads as quiet ambient context.

    private var streakStrip: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())

        return Button {
            onShowProgress()
            HapticService.selection()
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)

                    Text(vm.streakCount >= 2 ? "\(vm.streakCount)-day streak" : "This week")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }

                HStack(spacing: 0) {
                    ForEach(Array(zip(dayLabels, dayWeekdays)), id: \.1) { _, weekday in
                        let isActive = activeDays.contains(weekday)
                        let isToday = weekday == today

                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(palette.accent)
                                    .frame(width: 14, height: 14)
                                    .scaleEffect(animateStreak ? 1 : 0)
                            } else if isToday {
                                Circle()
                                    .stroke(palette.accent, lineWidth: 1.4)
                                    .frame(width: 14, height: 14)
                            } else {
                                Circle()
                                    .fill(palette.border.opacity(0.45))
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: 220)
            }
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.16), value: appeared)
    }

    // MARK: - Composer (the centerpiece)
    //
    // Real TextField. Submits via the existing `.openAIWithContext`
    // notification, which ContentView already handles: it creates a new
    // Conversation, sets a pendingConversation, and switches to the Ask
    // tab where ChatView picks up the context and starts streaming.

    private var homeComposer: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.6),
                            Color(red: 1.0, green: 0.84, blue: 0.3),
                            palette.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22)

            TextField(
                placeholderText,
                text: $composerText,
                axis: .vertical
            )
            .font(BPFont.elegantBody)
            .focused($composerFocused)
            .lineLimit(1...4)
            .submitLabel(.send)
            .onSubmit { submitComposer() }
            .foregroundStyle(palette.textPrimary)

            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    composerFocused ? palette.accent : palette.accent.opacity(0.45),
                    lineWidth: composerFocused ? 1.4 : 0.8
                )
        )
        .animation(.easeOut(duration: 0.18), value: composerFocused)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(BPAnimation.spring.delay(0.24), value: appeared)
    }

    private var sendButton: some View {
        let isEmpty = composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button {
            submitComposer()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isEmpty ? palette.border.opacity(0.55) : palette.accent)
                )
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .animation(.easeOut(duration: 0.18), value: isEmpty)
    }

    private var placeholderText: String {
        let trimmed = vm.profile.firstName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "What\u{2019}s on your heart?"
        }
        return "What\u{2019}s on your heart, \(trimmed)?"
    }

    private func submitComposer() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        HapticService.lightImpact()
        composerFocused = false

        // Title is the first 40 chars of the user's prompt — gives the
        // conversation list a meaningful row title without forcing a
        // round-trip to the AI for naming.
        NotificationCenter.default.post(
            name: .openAIWithContext,
            object: nil,
            userInfo: [
                "context": trimmed,
                "title": String(trimmed.prefix(40))
            ]
        )

        composerText = ""
    }

    // MARK: - Prompt Chips
    //
    // Three profile-aware chips. Tapping pre-fills the composer (does NOT
    // auto-submit) so users can edit before sending. Pre-filling beats
    // auto-submitting because it teaches users that the composer accepts
    // free-form input, not just chip selections.

    private var promptChips: some View {
        // Horizontal scroll handles long burden-derived chips gracefully
        // (e.g. "Pray for purpose" / "Pray for loneliness") without
        // truncating, and leaves room to add more chips later without
        // re-laying out the home.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(contextualChips, id: \.self) { chip in
                    chipButton(chip)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.32), value: appeared)
    }

    private func chipButton(_ chip: String) -> some View {
        Button {
            composerText = chip
            composerFocused = true
            HapticService.selection()
        } label: {
            Text(chip)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                )
                .overlay(
                    Capsule()
                        .stroke(palette.border.opacity(0.4), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var contextualChips: [String] {
        var chips: [String] = []

        let primaryBurden = vm.profile.currentBurdens.first { $0 != .none }
        if let burden = primaryBurden {
            chips.append("Pray for \(burden.displayName.lowercased())")
        } else {
            chips.append("Pray for peace")
        }

        chips.append("Discuss today\u{2019}s verse")
        chips.append("I need encouragement")

        return chips
    }
}
