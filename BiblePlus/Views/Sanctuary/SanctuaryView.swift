import SwiftUI
import SwiftData

struct SanctuaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let soundscapeService: SoundscapeService

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
            personalizationService: personalization
        )
    }
}

// MARK: - Content View

private struct SanctuaryContentView: View {
    @Bindable var vm: SanctuaryViewModel
    let dismiss: DismissAction
    @State private var iconScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            // Content
            VStack(spacing: 0) {
                topBar
                Spacer()
                centerContent
                Spacer()
                bottomControls
            }
            .padding(.vertical, 20)
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
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    vm.showBackgroundPicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.15))
                        .clipShape(Circle())
                }

                Button {
                    vm.showSoundscapePicker = true
                } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 44)
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 20) {
            // Pulsing soundscape icon
            Image(systemName: vm.currentSoundscape.icon)
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(iconScale)
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
                .shadow(color: .black.opacity(0.15), radius: 4, y: 1)

            // Status
            Text(vm.isPlaying ? "Now Playing" : "Paused")
                .font(BPFont.caption)
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)

            // Sleep timer display
            if let formatted = vm.sleepTimerFormatted {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 12))
                    Text(formatted)
                        .font(BPFont.reference)
                }
                .foregroundStyle(.white.opacity(0.6))
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
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.15))
                        .clipShape(Circle())
                }

                // Play/Pause button
                Button {
                    HapticService.impact(.medium)
                    vm.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.15))
                            .frame(width: 72, height: 72)

                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 72, height: 72)

                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }

                // Soundscape picker shortcut
                Button {
                    vm.showSoundscapePicker = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }

    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)

                    // Filled track
                    Capsule()
                        .fill(Color(hex: "C9A96E"))
                        .frame(width: geo.size.width * CGFloat(vm.volume), height: 4)

                    // Thumb
                    Circle()
                        .fill(Color(hex: "C9A96E"))
                        .frame(width: 20, height: 20)
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
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Helpers

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            iconScale = 1.1
        }
    }
}
