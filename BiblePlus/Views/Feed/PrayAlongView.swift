import SwiftUI

struct PrayAlongView: View {
    let displayText: String
    let background: SanctuaryBackground

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var currentStep: Int = 0
    @State private var direction: NavigationDirection = .forward
    @State private var showContent = false

    private var sections: [String] {
        displayText.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var isLastStep: Bool {
        currentStep >= sections.count - 1
    }

    var body: some View {
        ZStack {
            // Layer 1: Background (video/gradient)
            backgroundLayer

            // Layer 2: Dark overlay for readability
            Color.black.opacity(0.4)

            // Layer 3: Content
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 12)

                Spacer()

                // Section text with animated transitions
                sectionContent
                    .padding(.horizontal, 36)

                Spacer()

                bottomControls
                    .padding(.bottom, 40)
            }
            .opacity(showContent ? 1 : 0)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .gesture(swipeGesture)
        .onAppear {
            withAnimation(BPAnimation.spring.delay(0.2)) {
                showContent = true
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: background.gradientColors.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let videoName = background.videoFileName {
                LoopingVideoPlayer(videoName: videoName)
            } else if let imageName = background.imageName,
                      let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Center: Step label
            Text("Step \(currentStep + 1) of \(sections.count)")
                .font(BPFont.caption)
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.7))

            // Left: Dismiss button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Section Content

    private var sectionContent: some View {
        ZStack {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                if index == currentStep {
                    Text(section)
                        .font(sectionFont(for: section))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 0)
                        .transition(direction == .forward ? .onboardingForward : .onboardingBackward)
                }
            }
        }
        .animation(BPAnimation.pageTransition, value: currentStep)
    }

    private func sectionFont(for section: String) -> Font {
        if section.count > 200 {
            return BPFont.prayerSmall
        } else if section.count > 100 {
            return BPFont.prayerMedium
        } else {
            return BPFont.prayerLarge
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Progress dots
            progressDots

            // Navigation buttons
            HStack(spacing: 16) {
                // Back button (hidden on first step)
                if currentStep > 0 {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .transition(.opacity)
                }

                // Next / Finish button
                GoldButton(title: isLastStep ? "Amen" : "Next") {
                    if isLastStep {
                        dismiss()
                    } else {
                        goForward()
                    }
                }
                .frame(maxWidth: 200)
            }
            .animation(BPAnimation.spring, value: currentStep)
        }
        .padding(.horizontal, 40)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<sections.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentStep ? 10 : 7, height: index == currentStep ? 10 : 7)
                    .animation(BPAnimation.selection, value: currentStep)
            }
        }
    }

    // MARK: - Navigation

    private func goForward() {
        guard currentStep < sections.count - 1 else { return }
        direction = .forward
        currentStep += 1
        HapticService.lightImpact()
    }

    private func goBack() {
        guard currentStep > 0 else { return }
        direction = .backward
        currentStep -= 1
        HapticService.lightImpact()
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal < -50 {
                    goForward()
                } else if horizontal > 50 {
                    goBack()
                }
            }
    }
}

// MARK: - Direction

private enum NavigationDirection {
    case forward, backward
}
