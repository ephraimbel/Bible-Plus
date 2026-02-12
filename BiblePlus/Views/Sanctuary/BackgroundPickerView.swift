import SwiftUI
import AVFoundation

// MARK: - Filter Type

private enum BackgroundFilter: CaseIterable, Identifiable {
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

private final class ThumbnailCache: @unchecked Sendable {
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

private struct AsyncThumbnailView: View {
    let bg: SanctuaryBackground
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            // Gradient fallback (always visible)
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: bg.gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.2, contentMode: .fit)

            // Thumbnail once loaded
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1.2, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
        generator.maximumSize = CGSize(width: 200, height: 360)

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
        let maxSize: CGFloat = 200
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
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterChips

                // Background grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(filteredCollections()) { collection in
                            let backgrounds = filteredBackgrounds(in: vm.backgroundsByCollection(collection))
                            Section {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(backgrounds) { bg in
                                        backgroundCard(bg, locked: bg.isProOnly && !vm.profile.isPro)
                                    }
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Text(collection.displayName)
                                        .font(BPFont.button)
                                        .foregroundStyle(.secondary)

                                    if collection.isProOnly {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(hex: "C9A96E"))
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .animation(.easeInOut(duration: 0.25), value: selectedFilter)
                }
            }
            .background(palette.background)
            .navigationTitle("Backgrounds")
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
        .sheet(isPresented: $showPaywall) {
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
                    .font(.system(size: 13))

                Text(filter.displayName)
                    .font(BPFont.button)

                Text("\(backgroundCount(for: filter))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(palette.accent)
                        .matchedGeometryEffect(id: "activeChip", in: chipAnimation)
                } else {
                    Capsule()
                        .fill(palette.surface)
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
        Button {
            if locked {
                showPaywall = true
            } else {
                HapticService.selection()
                vm.selectBackground(bg)
            }
        } label: {
            ZStack {
                // Async thumbnail (gradient → image/video thumbnail)
                AsyncThumbnailView(bg: bg)

                // Dark scrim for text
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.2))

                // Content overlay
                VStack(spacing: 4) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if vm.selectedBackground.id == bg.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }

                    Text(bg.name)
                        .font(BPFont.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Type badge for video/image backgrounds
                if bg.hasVideo || bg.hasImage {
                    VStack {
                        HStack {
                            Spacer()
                            Text(bg.hasVideo ? "ANIMATED" : "IMAGE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "C9A96E").opacity(0.85))
                                .clipShape(Capsule())
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .opacity(locked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
