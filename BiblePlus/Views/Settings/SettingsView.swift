import SwiftUI
import SwiftData

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

    var body: some View {
        NavigationStack {
            List {
                profileSection
                bibleSection
                sanctuarySection
                widgetsSection
                subscriptionSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Settings")
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let current = vm.profile.colorMode
                        let next: ColorMode = current == .dark ? .light : .dark
                        vm.updateColorMode(next)
                    } label: {
                        Image(systemName: vm.profile.colorMode == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 16, weight: .medium))
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
            .sheet(isPresented: $vm.showEditTranslation) {
                EditTranslationSheet(vm: vm)
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
            .fullScreenCover(isPresented: $vm.showSanctuary) {
                SanctuaryView(soundscapeService: soundscapeService)
            }
            .sheet(isPresented: $vm.showVoicePicker) {
                VoicePickerView(
                    audioService: audioBibleService,
                    isPro: vm.profile.isPro
                ) { voice in
                    // Stop any active playback so the old voice doesn't keep playing
                    if audioBibleService.hasActivePlayback {
                        audioBibleService.stop()
                    }
                    audioBibleService.setVoice(voice)
                    vm.profile.selectedBibleVoiceID = voice.rawValue
                    try? modelContext.save()
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            settingsRow(
                icon: "person",
                label: "Name",
                value: vm.profile.firstName.isEmpty ? "Not set" : vm.profile.firstName
            ) {
                vm.beginEditingName()
            }

            settingsRow(
                icon: "sparkles",
                label: "Faith Level",
                value: vm.profile.faithLevel.displayName
            ) {
                vm.beginEditingFaithLevel()
            }

            settingsRow(
                icon: "leaf",
                label: "Life Seasons",
                value: vm.lifeSeasonsDisplay
            ) {
                vm.beginEditingLifeSeasons()
            }

            settingsRow(
                icon: "heart",
                label: "Heart Burdens",
                value: vm.burdensDisplay
            ) {
                vm.beginEditingBurdens()
            }

            settingsRow(
                icon: "bell",
                label: "Prayer Times",
                value: vm.prayerTimesDisplay
            ) {
                vm.beginEditingPrayerTimes()
            }

            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(palette.accent)
                    .frame(width: 24)
                Text("Daily Streak")
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(vm.streakDisplay)
                    .foregroundStyle(palette.accent)
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Changes to your profile will refresh your feed.")
        }
        .listRowBackground(palette.surface)
    }

    // MARK: - Bible Section

    private var bibleSection: some View {
        Section("Bible") {
            settingsRow(
                icon: "book",
                label: "Translation",
                value: vm.profile.preferredTranslation.displayName
            ) {
                vm.beginEditingTranslation()
            }

            settingsRow(
                icon: "person.wave.2",
                label: "Narrator Voice",
                value: vm.currentVoiceDisplay
            ) {
                vm.showVoicePicker = true
            }
        }
        .listRowBackground(palette.surface)
    }

    // MARK: - Sanctuary Section

    private var sanctuarySection: some View {
        Section("Sanctuary") {
            settingsRow(
                icon: "music.note",
                label: "Soundscapes",
                value: vm.currentSoundscapeDisplay
            ) {
                vm.showSoundscapePicker = true
            }

            settingsRow(
                icon: "photo.on.rectangle",
                label: "Backgrounds",
                value: vm.currentBackgroundDisplay
            ) {
                vm.showBackgroundPicker = true
            }

            settingsRow(
                icon: "moon.stars",
                label: "Open Sanctuary",
                value: nil
            ) {
                vm.showSanctuary = true
            }
        }
        .listRowBackground(palette.surface)
    }

    // MARK: - Widgets Section

    private var widgetsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 24))
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Bible+ to Your Home Screen")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Daily verses right where you need them")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Divider()

                // Steps
                widgetStep(number: 1, text: "Long-press on your Home Screen")
                widgetStep(number: 2, text: "Tap the + button in the top corner")
                widgetStep(number: 3, text: "Search for \"Bible Plus\"")
                widgetStep(number: 4, text: "Choose a size and tap Add Widget")

                Divider()

                // Lock Screen
                HStack(spacing: 10) {
                    Image(systemName: "lock.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock Screen Widget")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                        Text("Long-press your Lock Screen, tap Customize, and add Bible Plus to your lock screen widgets.")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Widgets")
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private func widgetStep(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(palette.accent)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(palette.textPrimary)
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Image(systemName: vm.profile.isPro ? "crown.fill" : "crown")
                    .foregroundStyle(palette.accent)
                    .frame(width: 24)
                Text("Status")
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text(vm.profile.isPro ? "Bible+ Pro" : "Free")
                    .foregroundStyle(palette.accent)
            }
        }
        .listRowBackground(palette.surface)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(palette.accent)
                    .frame(width: 24)
                Text("Version")
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(palette.accent)
            }
            HStack {
                Image(systemName: "hammer")
                    .foregroundStyle(palette.accent)
                    .frame(width: 24)
                Text("Build")
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("1")
                    .foregroundStyle(palette.accent)
            }
        }
        .listRowBackground(palette.surface)
    }

    // MARK: - Row Helper

    @ViewBuilder
    private func settingsRow(icon: String, label: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(palette.accent)
                    .frame(width: 24)
                Text(label)
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                if let value {
                    Text(value)
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
