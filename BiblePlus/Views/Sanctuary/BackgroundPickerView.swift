import SwiftUI
import AVFoundation

struct BackgroundPickerView: View {
    @Bindable var vm: SanctuaryViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(BackgroundCollection.allCases) { collection in
                        Section {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(vm.backgroundsByCollection(collection)) { bg in
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
            }
            .navigationTitle("Backgrounds")
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
    private func backgroundCard(_ bg: SanctuaryBackground, locked: Bool) -> some View {
        Button {
            if !locked {
                HapticService.selection()
                vm.selectBackground(bg)
            }
        } label: {
            ZStack {
                // Background preview (video thumbnail, image, or gradient)
                if bg.hasVideo, let videoName = bg.videoFileName, let thumbnail = Self.videoThumbnail(for: videoName) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1.2, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if bg.hasImage, let imageName = bg.imageName, let preview = Self.imagePreview(named: imageName) {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1.2, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: bg.gradientColors.map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(1.2, contentMode: .fit)
                }

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

    // MARK: - Video Thumbnail

    private static var thumbnailCache: [String: UIImage] = [:]

    private static func videoThumbnail(for videoName: String) -> UIImage? {
        if let cached = thumbnailCache[videoName] {
            return cached
        }

        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            return nil
        }

        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        thumbnailCache[videoName] = image
        return image
    }

    // MARK: - Image Preview

    private static var imageCache: [String: UIImage] = [:]

    private static func imagePreview(named imageName: String) -> UIImage? {
        if let cached = imageCache[imageName] {
            return cached
        }

        guard let uiImage = SanctuaryBackground.loadImage(named: imageName) else {
            return nil
        }

        // Downsample for picker preview
        let maxSize: CGFloat = 300
        let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumbnail = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        imageCache[imageName] = thumbnail
        return thumbnail
    }
}
