import SwiftUI

struct HomeDashboardView: View {
    @Bindable var vm: FeedViewModel
    let soundscapeService: SoundscapeService
    let onEnterFeed: () -> Void
    let onShowProgress: () -> Void
    let onShowSettings: () -> Void
    let onDailyVerseTap: () -> Void
    let onContinueReading: () -> Void
    let onOpenJournal: () -> Void
    let onOpenSanctuary: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var animateStreak = false
    @State private var showReadingPlans = false
    @State private var appeared = false
    @State private var floatingOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var glowPulse = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 16)

                heroVerseCard
                    .padding(.bottom, 12)

                streakProgressStrip
                    .padding(.bottom, 12)

                quickActionsRow

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .offset(y: dragOffset)

            swipeUpPrompt
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let translation = value.translation.height
                    guard translation < 0 else {
                        dragOffset = 0
                        return
                    }
                    let raw = -translation
                    dragOffset = -min(raw, 80 + (raw - 80) * 0.2)

                    if raw > 80 && !hasTriggeredHaptic {
                        HapticService.notification(.success)
                        hasTriggeredHaptic = true
                    }
                }
                .onEnded { value in
                    let translation = -value.translation.height
                    if translation > 80 {
                        onEnterFeed()
                    }
                    withAnimation(BPAnimation.spring) {
                        dragOffset = 0
                    }
                    hasTriggeredHaptic = false
                }
        )
        .sheet(isPresented: $showReadingPlans) {
            ReadingPlansView(
                isPro: vm.profile.isPro,
                onReadChapter: { bookName, chapter in
                    showReadingPlans = false
                    NotificationCenter.default.post(
                        name: .scriptureDeepLink,
                        object: nil,
                        userInfo: ["bookName": bookName, "chapter": chapter]
                    )
                }
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(BPAnimation.spring) {
                    appeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateStreak = true
                }
            }
        }
    }

    // MARK: - Swipe Up Prompt

    private var swipeUpPrompt: some View {
        VStack(spacing: 4) {
            Spacer()

            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.5))
                .offset(y: floatingOffset)

            Text("Swipe up to explore")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [palette.background, palette.background.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 50)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        )
        .allowsHitTesting(false)
        .opacity(appeared ? 1 : 0)
        .animation(BPAnimation.spring.delay(0.4), value: appeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatingOffset = -3
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Bible+ brand
                HStack(spacing: 0) {
                    Text("Bible")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(palette.textPrimary)

                    Text("+")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.88, blue: 0.5),
                                    Color(red: 0.79, green: 0.66, blue: 0.43),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(glowPulse ? 0.6 : 0.2), radius: glowPulse ? 10 : 4)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(glowPulse ? 0.3 : 0.1), radius: glowPulse ? 20 : 8)
                }

                // Greeting + date on one line
                HStack(spacing: 0) {
                    Text("\(vm.greetingLabel), \(vm.userName)")
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

            Spacer()

            Button {
                onShowSettings()
                HapticService.lightImpact()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.surface))
            }
        }
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

            Button {
                onDailyVerseTap()
                HapticService.lightImpact()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(gradient)

                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.35))

                    VStack(spacing: 6) {
                        // Verse text
                        Text("\u{201C}\(verse.text)\u{201D}")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .lineLimit(3)

                        // Ornamental divider
                        OrnamentalDivider(color: .white, opacity: 0.2)

                        // Reference with book icon
                        HStack(spacing: 4) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "C9A96E"))

                            Text(verse.reference)
                                .font(.system(size: 11, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(BPAnimation.spring.delay(0.08), value: appeared)
        }
    }

    // MARK: - Streak Progress Strip

    private var streakProgressStrip: some View {
        let activeDays = vm.activeDaysThisWeek
        let today = Calendar.current.component(.weekday, from: Date())
        let dayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

        return Button {
            onShowProgress()
            HapticService.selection()
        } label: {
            HStack(spacing: 0) {
                // Left: Flame + streak + chevron
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.accent)

                    Text(vm.streakCount >= 2 ? "\(vm.streakCount)-day streak" : "This Week")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                // Right: 7 compact dots, no day labels
                HStack(spacing: 5) {
                    ForEach(dayOrder, id: \.self) { weekday in
                        let isActive = activeDays.contains(weekday)
                        let isToday = weekday == today

                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(palette.accent)
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(animateStreak ? 1 : 0)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .scaleEffect(animateStreak ? 1 : 0)
                            } else if isToday {
                                Circle()
                                    .stroke(palette.accent.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                            } else {
                                Circle()
                                    .fill(palette.surface)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surface)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(BPAnimation.spring.delay(0.16), value: appeared)
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 8) {
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

    private func quickActionCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(palette.accent.opacity(0.12)))

                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.accent.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
