import SwiftUI

struct VerseImageSheet: View {
    let verseText: String
    let reference: String
    let translation: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @Environment(StoreKitService.self) private var storeKitService
    @State private var selectedRatio: ShareAspectRatio = .story
    @State private var selectedBackground: SanctuaryBackground = SanctuaryBackground.allBackgrounds[0]
    @State private var showActivitySheet = false
    @State private var showPaywall = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Aspect ratio picker
                Picker("Format", selection: $selectedRatio) {
                    ForEach(ShareAspectRatio.allCases) { ratio in
                        Label(ratio.displayName, systemImage: ratio.icon)
                            .tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .onChange(of: selectedRatio) { _, _ in
                    HapticService.selection()
                }

                // Scaled card preview
                GeometryReader { geo in
                    let cardWidth = selectedRatio.size.width / 3.0
                    let cardHeight = selectedRatio.size.height / 3.0
                    let scaleX = (geo.size.width - 48) / cardWidth
                    let scaleY = geo.size.height / cardHeight
                    let scale = min(scaleX, scaleY, 1.0)

                    VerseImageCardView(
                        verseText: verseText,
                        reference: reference,
                        translation: translation,
                        background: selectedBackground,
                        aspectRatio: selectedRatio
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12 / scale))
                    .scaleEffect(scale)
                    .frame(width: cardWidth * scale, height: cardHeight * scale)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Background picker
                backgroundPicker

                // Share button
                GoldButton(title: "Share") {
                    renderAndShare()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Verse Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(palette.accent)
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                if let image = renderedImage {
                    ActivityViewControllerRepresentable(activityItems: [image]) {
                        showActivitySheet = false
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showPaywall) {
                SummaryPaywallView()
            }
        }
    }

    // MARK: - Background Picker

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background")
                .font(BPFont.caption)
                .foregroundStyle(palette.textMuted)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SanctuaryBackground.allBackgrounds, id: \.id) { bg in
                        backgroundThumbnail(bg)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func backgroundThumbnail(_ bg: SanctuaryBackground) -> some View {
        let isSelected = bg.id == selectedBackground.id
        let isLocked = bg.isProOnly && !storeKitService.isPro

        return Button {
            if isLocked {
                showPaywall = true
                HapticService.lightImpact()
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBackground = bg
            }
            HapticService.lightImpact()
        } label: {
            ZStack {
                if let imageName = bg.imageName,
                   let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: bg.gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                if isSelected {
                    Color.black.opacity(0.3)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                if isLocked {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        Spacer()
                    }
                    .padding(3)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? palette.accent : .clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Render

    private func renderAndShare() {
        renderedImage = ShareService.renderVerseImage(
            verseText: verseText,
            reference: reference,
            translation: translation,
            background: selectedBackground,
            aspectRatio: selectedRatio
        )
        if renderedImage != nil {
            HapticService.success()
            showActivitySheet = true
        }
    }
}

