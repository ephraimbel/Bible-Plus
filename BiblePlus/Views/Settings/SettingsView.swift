import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SoundscapeService.self) private var soundscapeService
    @Environment(AudioBibleService.self) private var audioBibleService
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SettingsContentView(vm: vm, soundscapeService: soundscapeService, audioBibleService: audioBibleService)
            } else {
                BPLoadingView().onAppear { initializeViewModel() }
            }
        }
    }

    private func initializeViewModel() {
        viewModel = SettingsViewModel(
            modelContext: modelContext,
            soundscapeService: soundscapeService
        )
    }
}

// MARK: - Inner Content View

private struct SettingsContentView: View {
    @Bindable var vm: SettingsViewModel
    let soundscapeService: SoundscapeService
    let audioBibleService: AudioBibleService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @Environment(StoreKitService.self) private var storeKitService
    @State private var showPaywall = false
    @State private var isRestoringPurchases = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    profileSection
                    notificationsSection
                    appearanceSection
                    widgetsSection
                    subscriptionSection
                    aboutSection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .sheet(isPresented: $vm.showEditName) {
                EditNameSheet(vm: vm)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $vm.showEditFaithLevel) {
                EditFaithLevelSheet(vm: vm)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $vm.showEditLifeSeasons) {
                EditLifeSeasonsSheet(vm: vm)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $vm.showEditBurdens) {
                EditBurdensSheet(vm: vm)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $vm.showEditPrayerTimes) {
                EditPrayerTimesSheet(vm: vm)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $vm.showSoundscapePicker) {
                SoundscapePickerView(vm: vm.sanctuaryViewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $vm.showBackgroundPicker) {
                BackgroundPickerView(vm: vm.sanctuaryViewModel)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $vm.showWidgetBackgroundPicker) {
                WidgetBackgroundPickerSheet(vm: vm)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $vm.showHomeWidgetGuide) {
                WidgetGuideView(mode: .homeScreen)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $vm.showLockWidgetGuide) {
                WidgetGuideView(mode: .lockScreen)
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showPaywall) {
                SummaryPaywallView()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(BPAnimation.spring) {
                        appeared = true
                    }
                }
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func sectionHeader(_ title: String, index: Int) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(palette.textMuted)
            .textCase(.uppercase)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(Double(index) * 0.05), value: appeared)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(palette.textMuted)
            .padding(.leading, 4)
            .padding(.top, 4)
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Profile", index: 0)

            sectionCard {
                settingsRow(
                    icon: "person",
                    label: "Name",
                    value: vm.profile.firstName.isEmpty ? "Not set" : vm.profile.firstName
                ) {
                    vm.beginEditingName()
                }

                rowDivider

                settingsRow(
                    icon: "sparkles",
                    label: "Faith Level",
                    value: vm.profile.faithLevel.displayName
                ) {
                    vm.beginEditingFaithLevel()
                }

                rowDivider

                settingsRow(
                    icon: "leaf",
                    label: "Life Seasons",
                    value: vm.lifeSeasonsDisplay
                ) {
                    vm.beginEditingLifeSeasons()
                }

                rowDivider

                settingsRow(
                    icon: "heart",
                    label: "Heart Burdens",
                    value: vm.burdensDisplay
                ) {
                    vm.beginEditingBurdens()
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.05), value: appeared)

            sectionFooter("Changes to your profile will refresh your feed.")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notifications", index: 1)

            sectionCard {
                // Master toggle
                HStack(spacing: 14) {
                    Image(systemName: vm.profile.notificationsEnabled ? "bell.fill" : "bell.slash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                        )

                    Text("Notifications")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { vm.profile.notificationsEnabled },
                        set: { _ in vm.toggleNotifications() }
                    ))
                    .tint(palette.accent)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if vm.profile.notificationsEnabled {
                    rowDivider

                    settingsRow(
                        icon: "clock",
                        label: "Prayer Times",
                        value: vm.prayerTimesDisplay
                    ) {
                        vm.beginEditingPrayerTimes()
                    }

                    rowDivider

                    // Faith Boosts toggle
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Faith Boosts")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                            Text("Short verses & prayers every 2 hours")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(palette.textMuted)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { vm.profile.faithBoostsEnabled },
                            set: { _ in vm.toggleFaithBoosts() }
                        ))
                        .tint(palette.accent)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    rowDivider

                    // Gentle Reminders toggle (Pro)
                    HStack(spacing: 14) {
                        Image(systemName: "hand.wave")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Gentle Reminders")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(palette.textPrimary)

                                if !vm.profile.isPro {
                                    Text("PRO")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(palette.accent))
                                }
                            }
                            Text("Short prayers & encouragements throughout the day")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(palette.textMuted)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { vm.profile.gentleRemindersEnabled },
                            set: { _ in vm.toggleGentleReminders() }
                        ))
                        .tint(palette.accent)
                        .labelsHidden()
                        .disabled(!vm.profile.isPro)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    rowDivider

                    // Streak Reminders toggle
                    HStack(spacing: 14) {
                        Image(systemName: "flame")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                            )

                        Text("Streak Reminders")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { vm.profile.streakReminderEnabled },
                            set: { _ in vm.toggleStreakReminder() }
                        ))
                        .tint(palette.accent)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    rowDivider

                    // Plan Reminders toggle
                    HStack(spacing: 14) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                            )

                        Text("Plan Reminders")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { vm.profile.planReminderEnabled },
                            set: { _ in vm.togglePlanReminder() }
                        ))
                        .tint(palette.accent)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.1), value: appeared)
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Appearance", index: 2)

            sectionCard {
                // Theme toggle
                HStack(spacing: 14) {
                    Image(systemName: vm.profile.colorMode == .dark ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                        )
                        .contentTransition(.symbolEffect(.replace))

                    Text("Dark Mode")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { vm.profile.colorMode == .dark },
                        set: { isDark in
                            HapticService.lightImpact()
                            vm.updateColorMode(isDark ? .dark : .light)
                        }
                    ))
                    .tint(palette.accent)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                rowDivider

                settingsRow(
                    icon: "music.note",
                    label: "Soundscape",
                    value: vm.currentSoundscapeDisplay
                ) {
                    vm.showSoundscapePicker = true
                }

                rowDivider

                settingsRow(
                    icon: "photo.on.rectangle",
                    label: "Background",
                    value: vm.currentBackgroundDisplay
                ) {
                    vm.showBackgroundPicker = true
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.15), value: appeared)
        }
    }

    // MARK: - Widgets Section

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Widgets", index: 3)

            sectionCard {
                settingsRow(
                    icon: "square.grid.2x2",
                    label: "Home Screen Widget",
                    value: "Setup Guide"
                ) {
                    vm.showHomeWidgetGuide = true
                }

                rowDivider

                settingsRow(
                    icon: "lock.circle",
                    label: "Lock Screen Widget",
                    value: "Setup Guide"
                ) {
                    vm.showLockWidgetGuide = true
                }

                rowDivider

                settingsRow(
                    icon: "photo.artframe",
                    label: "Widget Background",
                    value: vm.widgetBackgroundDisplay
                ) {
                    vm.showWidgetBackgroundPicker = true
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.2), value: appeared)
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Subscription", index: 4)

            sectionCard {
                if vm.profile.isPro {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [palette.accent, palette.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )

                        Text("Status")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Spacer()

                        Text("Bible+ Pro")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    rowDivider

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "gear")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.accent)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(palette.accent.opacity(0.08))
                                )

                            Text("Manage Subscription")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.textMuted.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "crown")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.accent)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(palette.accent.opacity(0.08))
                                )

                            Text("Status")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary)

                            Spacer()

                            Text("Free")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.accent)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.textMuted.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.25), value: appeared)
        }
    }

    // MARK: - About Section

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("About", index: 5)

            sectionCard {
                aboutRow(icon: "star", label: "Rate the App", trailing: .chevron) {
                    requestReview()
                }

                rowDivider

                aboutRow(icon: "hand.raised", label: "Privacy Policy", trailing: .external) {
                    if let url = URL(string: "https://bibleplus.io/privacy") {
                        openURL(url)
                    }
                }

                rowDivider

                aboutRow(icon: "doc.text", label: "Terms of Service", trailing: .external) {
                    if let url = URL(string: "https://bibleplus.io/terms") {
                        openURL(url)
                    }
                }

                rowDivider

                aboutRow(icon: "questionmark.circle", label: "Support", trailing: .external) {
                    if let url = URL(string: "https://bibleplus.io/support") {
                        openURL(url)
                    }
                }

                rowDivider

                // Restore Purchases
                Button {
                    isRestoringPurchases = true
                    Task {
                        await storeKitService.restorePurchases()
                        isRestoringPurchases = false
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(palette.accent.opacity(0.08))
                            )

                        Text("Restore Purchases")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Spacer()

                        if isRestoringPurchases {
                            ProgressView()
                                .tint(palette.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .disabled(isRestoringPurchases)

                rowDivider

                // Version
                HStack(spacing: 14) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                        )

                    Text("Version")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    Text("\(appVersion) (\(buildNumber))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                #if DEBUG
                .contentShape(Rectangle())
                .onTapGesture(count: 5) {
                    vm.profile.isPro.toggle()
                    try? modelContext.save()
                    HapticService.impact(.heavy)
                }
                #endif
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.3), value: appeared)
        }
    }

    // MARK: - About Row Helper

    private enum TrailingIcon {
        case chevron, external
    }

    private func aboutRow(icon: String, label: String, trailing: TrailingIcon, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.08))
                    )

                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                Image(systemName: trailing == .external ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Row Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.12))
            .frame(height: 0.5)
            .padding(.leading, 62)
    }

    @ViewBuilder
    private func settingsRow(icon: String, label: String, value: String?, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.08))
                    )

                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                if let value {
                    Text(value)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
