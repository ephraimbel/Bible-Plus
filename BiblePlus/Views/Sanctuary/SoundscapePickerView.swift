import SwiftUI

struct SoundscapePickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Volume control
                    volumeControl
                        .padding(.horizontal, 20)

                    // Free soundscapes
                    soundscapeSection(title: "Free", icon: nil, sounds: Soundscape.freeSoundscapes, locked: false)

                    // Nature sounds
                    soundscapeSection(title: "Nature", icon: "leaf.fill", sounds: Soundscape.natureSoundscapes, locked: !vm.profile.isPro)

                    // Ambient & Music
                    soundscapeSection(title: "Ambient & Music", icon: "music.note", sounds: Soundscape.ambientSoundscapes, locked: !vm.profile.isPro)

                    // Classic
                    soundscapeSection(title: "Classic", icon: "crown.fill", sounds: Soundscape.classicSoundscapes, locked: !vm.profile.isPro)
                }
                .padding(.vertical, 16)
            }
            .background(palette.background)
            .navigationTitle("Soundscapes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationBackground(palette.background)
    }

    // MARK: - Volume Control

    @ViewBuilder
    private var volumeControl: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { vm.volume },
                    set: { vm.volume = $0 }
                ), in: 0...1)
                .tint(palette.accent)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Text("Volume: \(Int(vm.volume * 100))%")
                .font(BPFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Soundscape Section

    @ViewBuilder
    private func soundscapeSection(title: String, icon: String?, sounds: [Soundscape], locked: Bool) -> some View {
        Section {
            ForEach(sounds) { soundscape in
                soundscapeRow(soundscape, locked: locked)
            }
        } header: {
            HStack(spacing: 5) {
                Text(title)
                    .font(BPFont.button)
                    .foregroundStyle(.secondary)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "C9A96E"))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Soundscape Row

    @ViewBuilder
    private func soundscapeRow(_ soundscape: Soundscape, locked: Bool) -> some View {
        Button {
            if !locked {
                HapticService.selection()
                vm.selectSoundscape(soundscape)
            }
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "C9A96E").opacity(vm.currentSoundscape == soundscape ? 0.2 : 0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: soundscape.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(vm.currentSoundscape == soundscape ? Color(hex: "C9A96E") : .primary)
                }

                // Name + description
                VStack(alignment: .leading, spacing: 3) {
                    Text(soundscape.displayName)
                        .font(BPFont.body)
                        .foregroundStyle(.primary)

                    Text(soundscape.description)
                        .font(BPFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status badge
                if vm.currentSoundscape == soundscape {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "C9A96E"))
                } else if !soundscape.isAvailable {
                    Text("Coming Soon")
                        .font(BPFont.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.6 : 1.0)
    }
}
