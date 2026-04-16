import SwiftUI
import AVFoundation

struct OnboardingBackgroundCard: View {
    let background: SanctuaryBackground
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    ZStack {
                        // Layer 1: Gradient fill (always visible)
                        LinearGradient(
                            colors: background.gradientColors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        // Layer 2: Image thumbnail (async loaded)
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        }

                        // Layer 3: Selection checkmark
                        if isSelected {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.25))
                                    .frame(width: 28, height: 28)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? Color(hex: "C9A96E") : .white.opacity(0.1),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                )
                .shadow(
                    color: isSelected ? Color(hex: "C9A96E").opacity(0.3) : .black.opacity(0.1),
                    radius: isSelected ? 10 : 2,
                    y: isSelected ? 4 : 1
                )
        }
        .buttonStyle(.plain)
        .task(priority: .utility) {
            await loadThumbnail()
        }
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() async {
        if background.hasVideo, let videoName = background.videoFileName {
            let cacheKey = "video-\(videoName)"
            if let cached = OnboardingThumbnailCache.shared.get(cacheKey) {
                await MainActor.run { thumbnail = cached }
                return
            }
            if let img = await generateVideoThumbnail(videoName) {
                OnboardingThumbnailCache.shared.set(cacheKey, image: img)
                await MainActor.run { thumbnail = img }
            }
        } else if background.hasImage, let imageName = background.imageName {
            let cacheKey = "image-\(imageName)"
            if let cached = OnboardingThumbnailCache.shared.get(cacheKey) {
                await MainActor.run { thumbnail = cached }
                return
            }
            if let img = await loadImageThumbnail(imageName) {
                OnboardingThumbnailCache.shared.set(cacheKey, image: img)
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
        generator.maximumSize = CGSize(width: 200, height: 270)
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

// MARK: - Thumbnail Cache (shared singleton)

private final class OnboardingThumbnailCache: @unchecked Sendable {
    static let shared = OnboardingThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
    }
}
