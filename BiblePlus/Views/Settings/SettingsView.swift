import SwiftUI
import SwiftData
import StoreKit
import PhotosUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SoundscapeService.self) private var soundscapeService
    @Environment(AudioBibleService.self) private var audioBibleService
    @Environment(LocalizationService.self) private var localization
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SettingsContentView(
                    vm: vm,
                    soundscapeService: soundscapeService,
                    audioBibleService: audioBibleService,
                    localization: localization
                )
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
    let localization: LocalizationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @Environment(StoreKitService.self) private var storeKitService
    @State private var showPaywall = false
    @State private var isRestoringPurchases = false
    @State private var appeared = false
    @State private var showMemorySettings = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showPhotoActions = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    profileHeader
                    profileSection
                    notificationsSection
                    appearanceSection
                    widgetsSection
                    subscriptionSection
                    aboutSection
                    versionFooter

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.lightImpact()
                        let isDark = vm.profile.colorMode != .dark
                        vm.updateColorMode(isDark ? .dark : .light)
                    } label: {
                        Image(systemName: vm.profile.colorMode == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .contentTransition(.symbolEffect(.replace))
                    }
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
            .sheet(isPresented: $vm.showNotificationTopics) {
                NotificationTopicsView(vm: vm, showPaywall: $showPaywall)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $vm.showLanguagePicker) {
                LanguagePickerView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showMemorySettings) {
                MemorySettingsView(profile: vm.profile)
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallContainerView()
            }
            .photosPicker(
                isPresented: $vm.showPhotoPicker,
                selection: $pickedPhoto,
                matching: .images,
                photoLibrary: .shared()
            )
            .confirmationDialog(
                "Profile Picture",
                isPresented: $showPhotoActions,
                titleVisibility: .visible
            ) {
                Button("Choose from Library") {
                    vm.showPhotoPicker = true
                }
                if vm.profile.profileImageData != nil {
                    Button("Remove Photo", role: .destructive) {
                        vm.updateProfileImage(nil)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: pickedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        // Downscale to a reasonable avatar size to keep
                        // SwiftData rows light and avoid storing 10MB photos.
                        let resized = Self.resizedAvatar(from: data) ?? data
                        await MainActor.run {
                            vm.updateProfileImage(resized)
                            pickedPhoto = nil
                        }
                    }
                }
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

    // MARK: - Profile Header (Hero Card)

    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Avatar circle — tappable to set/change/remove the user's PFP
            Button {
                HapticService.lightImpact()
                showPhotoActions = true
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
                        .frame(width: 56, height: 56)
                        .shadow(color: palette.accent.opacity(0.25), radius: 8, y: 3)

                    if let data = vm.profile.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Text(vm.profile.firstName.prefix(1).uppercased())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // Tiny camera badge so the avatar reads as editable
                    Circle()
                        .fill(palette.surfaceElevated)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(palette.accent)
                        )
                        .overlay(Circle().stroke(palette.background, lineWidth: 1.5))
                        .offset(x: 20, y: 20)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.profile.firstName.isEmpty ? "Welcome" : vm.profile.firstName)
                    .font(.custom("Georgia-Bold", size: 20))
                    .foregroundStyle(palette.textPrimary)

                HStack(spacing: 6) {
                    Text(vm.profile.faithLevel.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(palette.accent.opacity(0.1))
                        )

                    if vm.profile.isPro {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(0.5)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.accent.opacity(0.08), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.02), value: appeared)
    }

    // MARK: - Section Helpers

    private func sectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func sectionHeader(_ title: String, icon: String, index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.accent)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textMuted)
                .tracking(1.5)

            VStack { Divider() }
                .padding(.leading, 4)
        }
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
            sectionHeader("Profile", icon: "person.fill", index: 0)

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

                rowDivider

                settingsRow(
                    icon: "brain.head.profile",
                    label: "AI Memory",
                    value: memoryRowValue
                ) {
                    showMemorySettings = true
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.05), value: appeared)

            sectionFooter("Changes to your profile will refresh your feed.")
        }
    }

    /// Compact summary for the AI Memory row's trailing label.
    private var memoryRowValue: String {
        let factCount = vm.profile.aiPinnedFacts.count
        let hasDigest = (vm.profile.aiMemoryDigest?.isEmpty ?? true) == false
        if factCount == 0 && !hasDigest { return "Empty" }
        if factCount == 0 { return "Digest only" }
        return "\(factCount) pinned"
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notifications", icon: "bell.fill", index: 1)

            sectionCard {
                // Master toggle
                toggleRow(
                    icon: vm.profile.notificationsEnabled ? "bell.fill" : "bell.slash",
                    label: "Notifications",
                    isOn: Binding(
                        get: { vm.profile.notificationsEnabled },
                        set: { _ in vm.toggleNotifications() }
                    )
                )

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

                    // Faith Boosts toggle + topic picker
                    toggleRow(
                        icon: "sparkles",
                        label: "Faith Boosts",
                        subtitle: "Verses & prayers throughout your day",
                        isOn: Binding(
                            get: { vm.profile.faithBoostsEnabled },
                            set: { _ in vm.toggleFaithBoosts() }
                        )
                    )

                    if vm.profile.faithBoostsEnabled {
                        rowDivider

                        settingsRow(
                            icon: "list.bullet",
                            label: "Topics",
                            value: "\(vm.profile.selectedNotificationTopics.count) selected"
                        ) {
                            vm.showNotificationTopics = true
                        }
                    }

                    rowDivider

                    toggleRow(
                        icon: "flame",
                        label: "Streak Reminders",
                        isOn: Binding(
                            get: { vm.profile.streakReminderEnabled },
                            set: { _ in vm.toggleStreakReminder() }
                        )
                    )

                    rowDivider

                    toggleRow(
                        icon: "calendar",
                        label: "Plan Reminders",
                        isOn: Binding(
                            get: { vm.profile.planReminderEnabled },
                            set: { _ in vm.togglePlanReminder() }
                        )
                    )
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
            sectionHeader("Appearance", icon: "paintbrush.fill", index: 2)

            sectionCard {
                settingsRow(
                    icon: "globe",
                    label: "Language",
                    value: languageRowValue
                ) {
                    vm.showLanguagePicker = true
                }

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

    /// Compact trailing label for the Language row. Uses `flag + nativeName`
    /// so the user's eye lands on the emoji first — fastest way to confirm
    /// the current pick without reading.
    private var languageRowValue: String {
        let lang = localization.current
        if localization.currentCode == nil {
            return "\(lang.flag) System"
        }
        return "\(lang.flag) \(lang.nativeName)"
    }

    // MARK: - Widgets Section

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Widgets", icon: "square.grid.2x2.fill", index: 3)

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
            sectionHeader("Subscription", icon: "crown.fill", index: 4)

            if vm.profile.isPro {
                // Pro status — accent gradient card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        (Text("Bible") + Text(Image(systemName: "sparkle")) + Text(" Pro"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)

                        Text("All features unlocked")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }

                    Spacer()

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Manage")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(palette.accent.opacity(0.1))
                            )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.accent.opacity(0.15), lineWidth: 1)
                )
            } else {
                // Free — upgrade CTA
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(palette.accent.opacity(0.12))
                                .frame(width: 40, height: 40)

                            Image(systemName: "crown")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(palette.accent)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Upgrade to Pro")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)

                            Text("Unlock all features & content")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(palette.accent.opacity(0.1))
                            )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            // Restore purchases (always visible)
            if !vm.profile.isPro {
                Button {
                    isRestoringPurchases = true
                    Task {
                        await storeKitService.restorePurchases()
                        isRestoringPurchases = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRestoringPurchases {
                            ProgressView()
                                .tint(palette.accent)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                        }
                        Text("Restore Purchases")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                }
                .disabled(isRestoringPurchases)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.25), value: appeared)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("About", icon: "info.circle.fill", index: 5)

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
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(BPAnimation.spring.delay(0.3), value: appeared)
        }
    }

    // MARK: - Version Footer

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var versionFooter: some View {
        (Text("Bible") + Text(Image(systemName: "sparkle")) + Text(" v\(appVersion) (\(buildNumber))"))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(palette.textMuted.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: - About Row Helper

    private enum TrailingIcon {
        case chevron, external
    }

    private func aboutRow(icon: String, label: LocalizedStringKey, trailing: TrailingIcon, action: @escaping () -> Void) -> some View {
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Row Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.1))
            .frame(height: 0.5)
            .padding(.leading, 62)
    }

    @ViewBuilder
    private func settingsRow(icon: String, label: LocalizedStringKey, value: String?, action: @escaping () -> Void) -> some View {
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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Toggle Row Helper

    @ViewBuilder
    private func toggleRow(
        icon: String,
        label: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Binding<Bool>,
        useSymbolTransition: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(palette.accent.opacity(0.08))
                )
                .if(useSymbolTransition) { view in
                    view.contentTransition(.symbolEffect(.replace))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(palette.accent)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Avatar Helpers

extension SettingsContentView {
    /// Downscale a picked photo to a square ~512px JPEG so it stores cheaply
    /// in SwiftData and renders fast at avatar sizes. Returns nil if decoding
    /// fails — caller falls back to the raw data.
    static func resizedAvatar(from data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let longest = max(size.width, size.height)
        let scale: CGFloat = longest > maxDimension ? maxDimension / longest : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
