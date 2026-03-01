import SwiftUI
import AVFoundation

// MARK: - Filter Type

enum BackgroundFilter: CaseIterable, Identifiable {
    case all, animated, images, gradients

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .all: "All"
        case .animated: "Animated"
        case .images: "Images"
        case .gradients: "Gradients"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .animated: "play.circle"
        case .images: "photo"
        case .gradients: "paintpalette"
        }
    }

    func matches(_ bg: SanctuaryBackground) -> Bool {
        switch self {
        case .all: true
        case .animated: bg.hasVideo
        case .images: bg.hasImage
        case .gradients: !bg.hasVideo && !bg.hasImage
        }
    }
}

// MARK: - Thumbnail Cache

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Async Thumbnail View

struct AsyncThumbnailView: View {
    let bg: SanctuaryBackground
    @State private var thumbnail: UIImage?

    /// Fills its parent completely — parent must provide the size
    var body: some View {
        ZStack {
            // Gradient base (always visible)
            LinearGradient(
                colors: bg.gradientColors.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Thumbnail fills and crops to parent bounds
            if let thumbnail {
                GeometryReader { geo in
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
        .task(priority: .utility) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let cacheKey: String
        if bg.hasVideo, let videoName = bg.videoFileName {
            cacheKey = "video-\(videoName)"
            if let cached = ThumbnailCache.shared.get(cacheKey) {
                thumbnail = cached
                return
            }
            if let img = await generateVideoThumbnail(videoName) {
                ThumbnailCache.shared.set(cacheKey, image: img)
                await MainActor.run { thumbnail = img }
            }
        } else if bg.hasImage, let imageName = bg.imageName {
            cacheKey = "image-\(imageName)"
            if let cached = ThumbnailCache.shared.get(cacheKey) {
                thumbnail = cached
                return
            }
            if let img = await loadImageThumbnail(imageName) {
                ThumbnailCache.shared.set(cacheKey, image: img)
                await MainActor.run { thumbnail = img }
            }
        }
    }

    private nonisolated func generateVideoThumbnail(_ videoName: String) async -> UIImage? {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            return nil
        }
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 320)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated func loadImageThumbnail(_ imageName: String) async -> UIImage? {
        guard let url = Bundle.main.url(forResource: imageName, withExtension: "jpg"),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        let maxSize: CGFloat = 240
        let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Background Picker

struct BackgroundPickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette

    @State private var selectedFilter: BackgroundFilter = .all
    @State private var showPaywall = false
    @Namespace private var chipAnimation

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterChips

                // Background grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(filteredCollections()) { collection in
                            let backgrounds = filteredBackgrounds(in: vm.backgroundsByCollection(collection))
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: collection.isProOnly ? "crown.fill" : "paintpalette.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(palette.accent)
                                        .frame(width: 22, height: 22)
                                        .background(
                                            Circle()
                                                .fill(palette.accent.opacity(0.08))
                                        )

                                    Text(collection.displayName.uppercased())
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .tracking(1.5)
                                        .foregroundStyle(palette.textMuted)

                                    Rectangle()
                                        .fill(palette.border.opacity(0.1))
                                        .frame(height: 0.5)
                                }

                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(backgrounds) { bg in
                                        backgroundCard(bg, locked: bg.isProOnly && !vm.profile.isPro)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .animation(.easeInOut(duration: 0.25), value: selectedFilter)
                }
            }
            .background(palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Backgrounds")
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
            SummaryPaywallView()
        }
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BackgroundFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func filterChip(for filter: BackgroundFilter) -> some View {
        let isSelected = selectedFilter == filter

        Button {
            HapticService.selection()
            withAnimation(BPAnimation.selection) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(filter.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text("\(backgroundCount(for: filter))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : palette.textMuted)
            }
            .foregroundStyle(isSelected ? .white : palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: palette.accent.opacity(0.25), radius: 4, y: 2)
                        .matchedGeometryEffect(id: "activeChip", in: chipAnimation)
                } else {
                    Capsule()
                        .fill(palette.surfaceElevated)
                        .overlay(
                            Capsule()
                                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtering

    private func filteredCollections() -> [BackgroundCollection] {
        BackgroundCollection.allCases.filter { collection in
            let backgrounds = vm.backgroundsByCollection(collection)
            return backgrounds.contains(where: { selectedFilter.matches($0) })
        }
    }

    private func filteredBackgrounds(in backgrounds: [SanctuaryBackground]) -> [SanctuaryBackground] {
        backgrounds.filter { selectedFilter.matches($0) }
    }

    private func backgroundCount(for filter: BackgroundFilter) -> Int {
        SanctuaryBackground.allBackgrounds.filter { filter.matches($0) }.count
    }

    // MARK: - Background Card

    @ViewBuilder
    private func backgroundCard(_ bg: SanctuaryBackground, locked: Bool) -> some View {
        let isActive = vm.selectedBackground.id == bg.id

        Button {
            if locked {
                showPaywall = true
            } else {
                HapticService.selection()
                vm.selectBackground(bg)
            }
        } label: {
            ZStack {
                // Async thumbnail (gradient -> image/video thumbnail)
                AsyncThumbnailView(bg: bg)

                // Dark scrim for text
                Color.black.opacity(0.15)

                // Content overlay
                VStack(spacing: 6) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if isActive {
                        ZStack {
                            // Outer glow
                            Circle()
                                .fill(.white.opacity(0.12))
                                .frame(width: 32, height: 32)

                            // Inner circle
                            Circle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text(bg.name)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Type badge for video/image backgrounds
                if bg.hasVideo || bg.hasImage {
                    VStack {
                        HStack {
                            Spacer()
                            Text(bg.hasVideo ? "ANIMATED" : "IMAGE")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "C9A96E").opacity(0.85))
                                    )
                                .padding(5)
                        }
                        Spacer()
                    }
                }
            }
            .aspectRatio(3.0/4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive ? Color(hex: "C9A96E").opacity(0.6) : .white.opacity(0.1),
                        lineWidth: isActive ? 2 : 0.5
                    )
            )
            .shadow(
                color: isActive ? Color(hex: "C9A96E").opacity(0.25) : .black.opacity(0.06),
                radius: isActive ? 10 : 6, y: isActive ? 5 : 3
            )
            .opacity(locked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
