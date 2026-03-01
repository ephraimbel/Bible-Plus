import SwiftUI
import SwiftData

struct SanctuaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let soundscapeService: SoundscapeService
    var verseText: String? = nil
    var verseReference: String? = nil

    @State private var viewModel: SanctuaryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SanctuaryContentView(vm: vm, dismiss: dismiss)
            } else {
                Color.black.onAppear { initializeViewModel() }
            }
        }
    }

    private func initializeViewModel() {
        let personalization = PersonalizationService(modelContext: modelContext)
        viewModel = SanctuaryViewModel(
            soundscapeService: soundscapeService,
            personalizationService: personalization,
            verseText: verseText,
            verseReference: verseReference
        )
    }
}

// MARK: - Content View

private struct SanctuaryContentView: View {
    @Bindable var vm: SanctuaryViewModel
    let dismiss: DismissAction
    @State private var iconScale: CGFloat = 1.0
    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            // Tap layer to toggle controls
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }

            // Verse display (always visible, not tied to controlsVisible)
            if vm.hasVerse {
                verseDisplay
            }

            // Content (controls hide/show on tap)
            VStack(spacing: 0) {
                topBar
                Spacer()
                if !vm.hasVerse {
                    centerContent
                    Spacer()
                }
                bottomControls
            }
            .padding(.vertical, 20)
            .opacity(controlsVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: controlsVisible)
            .allowsHitTesting(controlsVisible)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .sheet(isPresented: $vm.showSoundscapePicker) {
            SoundscapePickerView(vm: vm)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $vm.showBackgroundPicker) {
            BackgroundPickerView(vm: vm)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $vm.showSleepTimerPicker) {
            SleepTimerPickerView(vm: vm)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        LinearGradient(
            colors: vm.selectedBackground.gradientColors.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if let videoName = vm.selectedBackground.videoFileName {
                LoopingVideoPlayer(videoName: videoName)
            } else if let imageName = vm.selectedBackground.imageName,
                      let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                HapticService.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            }
            .accessibilityLabel("Close sanctuary")

            Spacer()

            Button {
                vm.showBackgroundPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            }
            .accessibilityLabel("Choose background")
        }
        .padding(.horizontal, 16)
        .padding(.top, 44)
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 20) {
            // Pulsing soundscape icon with layered glow rings
            ZStack {
                // Outermost breath ring
                Circle()
                    .stroke(.white.opacity(0.04), lineWidth: 0.5)
                    .frame(width: 170, height: 170)
                    .scaleEffect(iconScale)

                // Outer glow ring
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 140, height: 140)
                    .scaleEffect(iconScale)

                // Inner glow circle
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconScale)

                Image(systemName: vm.currentSoundscape.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.25), radius: 16)
                    .scaleEffect(iconScale)
            }
            .onAppear {
                if vm.isPlaying {
                    startPulse()
                }
            }
            .onChange(of: vm.isPlaying) { _, playing in
                if playing {
                    startPulse()
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        iconScale = 1.0
                    }
                }
            }

            // Soundscape name
            Text(vm.currentSoundscape.displayName)
                .font(BPFont.prayerLarge)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)

            // Status
            Text(vm.isPlaying ? "Now Playing" : "Paused")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)

            // Sleep timer display
            if let formatted = vm.sleepTimerFormatted {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 12, weight: .medium))
                    Text(formatted)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 28) {
            // Volume slider
            volumeSlider

            // Play/Pause + Sleep Timer
            HStack(spacing: 48) {
                // Sleep timer button
                Button {
                    vm.showSleepTimerPicker = true
                } label: {
                    Image(systemName: vm.sleepTimer != nil ? "moon.zzz.fill" : "moon.zzz")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(vm.sleepTimer != nil ? Color(hex: "C9A96E") : .white)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .accessibilityLabel("Set sleep timer")

                // Play/Pause button
                Button {
                    HapticService.impact(.medium)
                    vm.togglePlayback()
                } label: {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(Color(hex: "C9A96E").opacity(0.15), lineWidth: 1)
                            .frame(width: 90, height: 90)

                        // Glass circle
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 76, height: 76)
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 5)

                        // Accent ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "C9A96E"), Color(hex: "C9A96E").opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 76, height: 76)

                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(vm.isPlaying ? "Pause" : "Play")

                // Soundscape picker shortcut
                Button {
                    vm.showSoundscapePicker = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .accessibilityLabel("Choose soundscape")
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }

    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)

                    // Filled track with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "C9A96E"), Color(hex: "C9A96E").opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(vm.volume), height: 4)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        .overlay(
                            Circle()
                                .fill(Color(hex: "C9A96E"))
                                .frame(width: 8, height: 8)
                        )
                        .offset(x: geo.size.width * CGFloat(vm.volume) - 10)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newVolume = Float(max(0, min(1, value.location.x / geo.size.width)))
                                    vm.volume = newVolume
                                }
                        )
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Verse Display

    private var verseDisplay: some View {
        VStack(spacing: 16) {
            Text(vm.verseText ?? "")
                .font(verseFontForLength)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .padding(.horizontal, 32)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 1)

            if let ref = vm.verseReference {
                Text("— \(ref)")
                    .font(BPFont.reference)
                    .foregroundStyle(.white.opacity(0.6))
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            }
        }
    }

    private var verseFontForLength: Font {
        let count = vm.verseText?.count ?? 0
        if count > 300 { return BPFont.prayerXSmall }
        if count > 150 { return BPFont.prayerMedium }
        return BPFont.prayerLarge
    }

    // MARK: - Helpers

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.25)) {
            controlsVisible.toggle()
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            iconScale = 1.1
        }
    }
}
