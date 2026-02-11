import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SoundscapeService.self) private var soundscapeService
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SettingsContentView(vm: vm, soundscapeService: soundscapeService)
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
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            List {
                profileSection
                bibleSection
                sanctuarySection
                appearanceSection
                subscriptionSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Settings")
            .toolbarBackground(palette.background, for: .navigationBar)
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

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            HStack {
                Image(systemName: "paintbrush")
                    .foregroundStyle(palette.accent)
                    .frame(width: 24)
                Text("Color Mode")
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Picker("", selection: Binding(
                    get: { vm.profile.colorMode },
                    set: { vm.updateColorMode($0) }
                )) {
                    ForEach(ColorMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.accent)
            }
        }
        .listRowBackground(palette.surface)
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
