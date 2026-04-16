import SwiftUI

struct SoundscapePickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Volume control
                    volumeControl
                        .padding(.horizontal, 20)

                    // Free soundscapes
                    soundscapeSection(title: "FREE", icon: nil, sounds: Soundscape.freeSoundscapes, locked: false)

                    // Nature sounds
                    soundscapeSection(title: "NATURE", icon: "leaf.fill", sounds: Soundscape.natureSoundscapes, locked: !vm.profile.isPro)

                    // Ambient & Music
                    soundscapeSection(title: "AMBIENT & MUSIC", icon: "music.note", sounds: Soundscape.ambientSoundscapes, locked: !vm.profile.isPro)

                    // Classic
                    soundscapeSection(title: "CLASSIC", icon: "crown.fill", sounds: Soundscape.classicSoundscapes, locked: !vm.profile.isPro)
                }
                .padding(.vertical, 16)
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Soundscapes")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .presentationBackground(palette.background)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
    }

    // MARK: - Volume Control

    @ViewBuilder
    private var volumeControl: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textMuted)

                Slider(value: Binding(
                    get: { vm.volume },
                    set: { vm.volume = $0 }
                ), in: 0...1)
                .tint(palette.accent)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textMuted)
            }

            Text("Volume: \(Int(vm.volume * 100))%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
        }
        .padding(16)
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

    // MARK: - Soundscape Section

    @ViewBuilder
    private func soundscapeSection(title: String, icon: String?, sounds: [Soundscape], locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                        )
                }

                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(palette.textMuted)

                Rectangle()
                    .fill(palette.border.opacity(0.1))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(sounds.enumerated()), id: \.element.id) { index, soundscape in
                    soundscapeRow(soundscape, locked: locked)

                    if index < sounds.count - 1 {
                        Rectangle()
                            .fill(palette.border.opacity(0.12))
                            .frame(height: 0.5)
                            .padding(.leading, 78)
                            .padding(.trailing, 20)
                    }
                }
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
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Soundscape Row

    @ViewBuilder
    private func soundscapeRow(_ soundscape: Soundscape, locked: Bool) -> some View {
        let isActive = vm.currentSoundscape == soundscape

        Button {
            if !soundscape.isAvailable {
                // Coming soon — do nothing
            } else if locked {
                showPaywall = true
            } else {
                HapticService.selection()
                vm.selectSoundscape(soundscape)
            }
        } label: {
            HStack(spacing: 14) {
                // Icon with double-layer ring
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(palette.accent.opacity(isActive ? 0.12 : 0.04))
                        .frame(width: 50, height: 50)

                    // Inner icon circle
                    Image(systemName: soundscape.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isActive ? .white : palette.accent)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(
                                    isActive
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(palette.accent.opacity(0.08))
                                )
                        )
                        .shadow(
                            color: isActive ? palette.accent.opacity(0.3) : .clear,
                            radius: 4, y: 2
                        )
                }

                // Name + description
                VStack(alignment: .leading, spacing: 3) {
                    Text(soundscape.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text(soundscape.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                }

                Spacer()

                // Status badge
                if isActive {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .shadow(color: palette.accent.opacity(0.25), radius: 3, y: 1)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else if !soundscape.isAvailable {
                    Text("SOON")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(palette.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(palette.surface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                        )
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(palette.surface)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(locked && soundscape.isAvailable ? 0.6 : 1.0)
    }
}
