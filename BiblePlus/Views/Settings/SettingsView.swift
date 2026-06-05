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
    @State private var showPathSettings = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showPhotoActions = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: BPSpacing.xxl) {
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
                .padding(.horizontal, BPSpacing.lg)
                .padding(.top, BPSpacing.xs)
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
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
            .sheet(isPresented: $showPathSettings) {
                PathSettingsSheet(isPro: vm.profile.isPro)
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

    // MARK: - Profile Header (Editorial Hero)
    //
    // Calm, centered identity: a clean avatar with a thin gold ring (no gradient
    // fill), the name in serif, and one muted status line. Accent (gold) is
    // reserved for the ring and the camera badge only — everything else is
    // neutral text hierarchy.

    private var profileHeader: some View {
        VStack(spacing: BPSpacing.md) {
            // Avatar — tappable to set/change/remove the user's PFP
            Button {
                HapticService.lightImpact()
                showPhotoActions = true
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.surfaceElevated)
                        .frame(width: 86, height: 86)
                        .overlay(Circle().strokeBorder(palette.accent.opacity(0.45), lineWidth: 1.5))
                        .shadow(color: palette.accent.opacity(0.12), radius: 10, y: 4)

                    if let data = vm.profile.profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 86, height: 86)
                            .clipShape(Circle())
                    } else {
                        Text(vm.profile.firstName.prefix(1).uppercased())
                            .font(.custom("Georgia", size: 38))
                            .foregroundStyle(palette.accent)
                    }

                    // Crisp gold camera badge so the avatar reads as editable
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().strokeBorder(palette.background, lineWidth: 2.5))
                        .offset(x: 31, y: 31)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: BPSpacing.xxs) {
                Text(vm.profile.firstName.isEmpty ? "Welcome" : vm.profile.firstName)
                    .font(.custom("Georgia-Bold", size: 24))
                    .foregroundStyle(palette.textPrimary)

                Text(statusLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BPSpacing.xs)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(BPAnimation.spring.delay(0.02), value: appeared)
    }

    /// Muted one-liner under the name: faith stage · plan.
    private var statusLine: String {
        let faith = vm.profile.faithLevel.displayName
        return vm.profile.isPro ? "\(faith) · Bible+ Pro" : "\(faith) · Free"
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
    }

    /// Plain, quiet section label — no icon, no divider line. The label is the
    /// hierarchy; whitespace does the separating.
    private func sectionHeader(_ title: String, icon: String, index: Int) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.2)
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, BPSpacing.xs)
            .opacity(appeared ? 1 : 0)
            .animation(BPAnimation.spring.delay(Double(index) * 0.05), value: appeared)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(palette.textMuted)
            .padding(.leading, BPSpacing.xxs)
            .padding(.top, BPSpacing.xxs)
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            sectionHeader("You", icon: "person.fill", index: 0)

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
                    icon: "figure.walk",
                    label: "Daily Path",
                    value: "Browse"
                ) {
                    showPathSettings = true
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
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
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
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
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
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
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
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
            sectionHeader("Subscription", icon: "crown.fill", index: 4)

            if vm.profile.isPro {
                // Pro status — accent gradient card
                HStack(spacing: BPSpacing.md) {
                    VStack(alignment: .leading, spacing: BPSpacing.xxs) {
                        (Text("Bible") + Text(Image(systemName: "sparkle")) + Text(" Pro"))
                            .font(.custom("Georgia-Bold", size: 19))
                            .foregroundStyle(palette.textPrimary)

                        Text("All features unlocked")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textSecondary)
                    }

                    Spacer()

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Manage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, BPSpacing.md)
                            .padding(.vertical, BPSpacing.xs)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.12))
                                    .overlay(Capsule().strokeBorder(palette.accent.opacity(0.45), lineWidth: 0.8))
                            )
                    }
                }
                .padding(BPSpacing.md)
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
                    HStack(spacing: BPSpacing.md) {
                        VStack(alignment: .leading, spacing: BPSpacing.xxs) {
                            Text("Upgrade to Pro")
                                .font(.custom("Georgia-Bold", size: 19))
                                .foregroundStyle(palette.textPrimary)

                            Text("Unlock all features & content")
                                .font(.system(size: 13))
                                .foregroundStyle(palette.textSecondary)
                        }

                        Spacer()

                        Text("Upgrade")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, BPSpacing.md)
                            .padding(.vertical, BPSpacing.xs)
                            .background(Capsule().fill(palette.accent))
                    }
                    .padding(BPSpacing.md)
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
                    HStack(spacing: BPSpacing.xs) {
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
                    .padding(.top, BPSpacing.xs)
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
        VStack(alignment: .leading, spacing: BPSpacing.sm) {
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
            .padding(.top, BPSpacing.xxs)
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
            HStack(spacing: BPSpacing.sm) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                Image(systemName: trailing == .external ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.35))
            }
            .padding(.horizontal, BPSpacing.lg)
            .padding(.vertical, BPSpacing.md)
        }
    }

    // MARK: - Row Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(palette.border.opacity(0.1))
            .frame(height: 0.5)
            .padding(.leading, BPSpacing.lg)
    }

    @ViewBuilder
    private func settingsRow(icon: String, label: LocalizedStringKey, value: String?, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            HStack(spacing: BPSpacing.sm) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textPrimary)

                Spacer(minLength: 12)

                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.35))
            }
            .padding(.horizontal, BPSpacing.lg)
            .padding(.vertical, BPSpacing.md)
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
        HStack(spacing: BPSpacing.sm) {
            VStack(alignment: .leading, spacing: BPSpacing.xxs) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textMuted)
                }
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(palette.accent)
                .labelsHidden()
        }
        .padding(.horizontal, BPSpacing.lg)
        .padding(.vertical, BPSpacing.sm)
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
