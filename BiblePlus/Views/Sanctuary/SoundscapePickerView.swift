import SwiftUI

struct SoundscapePickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Free soundscapes
                    Section {
                        ForEach(Soundscape.freeSoundscapes) { soundscape in
                            soundscapeRow(soundscape, locked: false)
                        }
                    } header: {
                        Text("Free")
                            .font(BPFont.button)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    // Pro soundscapes
                    Section {
                        ForEach(Soundscape.proSoundscapes) { soundscape in
                            soundscapeRow(soundscape, locked: !vm.profile.isPro)
                        }
                    } header: {
                        HStack {
                            Text("Pro")
                                .font(BPFont.button)
                                .foregroundStyle(.secondary)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "C9A96E"))
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Soundscapes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "C9A96E"))
                }
            }
        }
    }

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
