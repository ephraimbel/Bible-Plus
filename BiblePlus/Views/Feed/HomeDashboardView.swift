import SwiftUI

struct HomeDashboardView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService
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
    @State private var floatingOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var glowPulse = false

    private var rubberBandScale: CGFloat {
        let progress = min(abs(dragOffset) / 120, 1.0)
        return 1.0 - (progress * 0.03)
    }

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let dayWeekdays = [2, 3, 4, 5, 6, 7, 1]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                headerSection
                heroVerseCard
                streakCard
                quickActionsRow
                askCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 90)
            .offset(y: dragOffset)
            .scaleEffect(rubberBandScale, anchor: .bottom)

            // Pinned above tab bar
            swipeUpPrompt
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(fullPageBackground)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    let translation = value.translation.height
                    guard translation < 0 else {
                        dragOffset = 0
                        return
                    }
                    let raw = -translation
                    let maxDrag: CGFloat = 120
                    dragOffset = -maxDrag * (1 - exp(-raw / maxDrag))

                    if raw > 100 && !hasTriggeredHaptic {
                        HapticService.notification(.success)
                        hasTriggeredHaptic = true
                    }
                }
                .onEnded { value in
                    let translation = -value.translation.height
                    if translation > 100 {
                        onEnterFeed()
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragOffset = 0
                    }
                    hasTriggeredHaptic = false
                }
        )
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
    }

    // MARK: - Full Page Background

    private var fullPageBackground: some View {
        let tint: Color = colorScheme == .dark
            ? palette.accent
            : Color(red: 0.65, green: 0.48, blue: 0.25)
        let strength: CGFloat = colorScheme == .dark ? 0.20 : 0.28
        let bg = palette.background

        return LinearGradient(
            stops: [
                .init(color: bg, location: 0.0),
                .init(color: bg, location: 0.50),
                .init(color: bg.blend(with: tint, amount: strength * 0.3), location: 0.65),
                .init(color: bg.blend(with: tint, amount: strength * 0.6), location: 0.80),
                .init(color: bg.blend(with: tint, amount: strength * 0.85), location: 0.90),
                .init(color: bg.blend(with: tint, amount: strength), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Swipe Up Prompt

    private var swipeUpPrompt: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.5))
                .offset(y: floatingOffset)

            Text("Swipe up to explore")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.5), value: appeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatingOffset = -3
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("Bible")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(palette.textPrimary)

                Text("+")
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(glowPulse ? 0.9 : 0.5), radius: 20)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(glowPulse ? 0.5 : 0.2), radius: 40)
            }

            HStack(spacing: 0) {
                Text("\(vm.greetingLabel) \(vm.userName)")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textSecondary)

                Text("  \u{00B7}  ")
                    .foregroundStyle(palette.textMuted)

                Text(vm.formattedDate)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Hero Verse Card

    @ViewBuilder
    private var heroVerseCard: some View {
        if let verse = vm.dailyVerse {
            let bgColors = vm.currentBackground.gradientColors.map { Color(hex: $0) }
            let gradient = LinearGradient(
                colors: bgColors.isEmpty ? [palette.accent] : bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                gradient
                    .overlay {
                        if let videoName = vm.currentBackground.videoFileName {
                            LoopingVideoPlayer(videoName: videoName, isPlaying: true)
                        } else if let imageName = vm.currentBackground.imageName,
                                  let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .clipped()

                Color.black.opacity(0.35)

                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Text("\u{201C}\(verse.text)\u{201D}")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .lineLimit(5)

                    OrnamentalDivider(color: .white, opacity: 0.2)

                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "C9A96E"))

                        Text(verse.reference)
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Button {
                        NotificationCenter.default.post(
                            name: .openAIWithContext,
                            object: nil,
                            userInfo: [
                                "context": "Walk me through this verse: \"\(verse.text)\" \u{2014} \(verse.reference)",
                                "title": verse.reference,
                            ]
                        )
                        HapticService.lightImpact()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text("Discuss")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.15))
                        )
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .onTapGesture {
                onDailyVerseTap()
                HapticService.lightImpact()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(BPAnimation.spring.delay(0.08), value: appeared)
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())

        return VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.streakCount >= 2 ? "\(vm.streakCount)-day streak" : "This Week")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Text("Your activity")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer()

                HStack(spacing: 3) {
                    Text("Details")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.accent.opacity(0.6))
                }
            }

            Rectangle()
                .fill(palette.border.opacity(0.15))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(Array(zip(dayLabels, dayWeekdays)), id: \.1) { label, weekday in
                    let isActive = activeDays.contains(weekday)
                    let isToday = weekday == today

                    VStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isToday ? palette.accent : palette.textMuted)

                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.accent, palette.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                    .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 2)
                                    .scaleEffect(animateStreak ? 1 : 0)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .scaleEffect(animateStreak ? 1 : 0)
                            } else if isToday {
                                Circle()
                                    .stroke(palette.accent, lineWidth: 2)
                                    .frame(width: 32, height: 32)

                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(palette.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(palette.border.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        .onTapGesture {
            onShowProgress()
            HapticService.selection()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.16), value: appeared)
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            quickActionCard(
                icon: "book.fill",
                title: vm.continueReading != nil ? "Continue" : "Read",
                subtitle: vm.continueReading.map { "\($0.bookName) \($0.chapter)" } ?? "Open Bible"
            ) {
                onContinueReading()
                HapticService.lightImpact()
            }

            quickActionCard(
                icon: "calendar",
                title: "Plan",
                subtitle: vm.activeReadingPlan.map { "Day \($0.day)/\($0.total)" } ?? "Start"
            ) {
                showReadingPlans = true
                HapticService.lightImpact()
            }

            quickActionCard(
                icon: "moon.stars",
                title: "Sanctuary",
                subtitle: soundscapeService.isPlaying ? "Playing" : "Enter"
            ) {
                onOpenSanctuary()
                HapticService.lightImpact()
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.24), value: appeared)
    }

    // MARK: - Ask Card

    private var askCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.accent.opacity(0.08))
                    .frame(width: 42, height: 42)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("What\u{2019}s on your heart?")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Text("Ask anything about faith, life, or Scripture")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textSecondary)
                    .italic()
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.textMuted.opacity(0.4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        .onTapGesture {
            NotificationCenter.default.post(name: .switchToAskTab, object: nil)
            HapticService.lightImpact()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.32), value: appeared)
    }

    // MARK: - Quick Action Card

    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.05))
                    .frame(width: 38, height: 38)
                Circle()
                    .fill(palette.accent.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.accent)
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        .onTapGesture(perform: action)
    }
}