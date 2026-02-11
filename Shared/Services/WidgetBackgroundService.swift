import AVFoundation
import UIKit
import WidgetKit

/// Extracts a static frame from the user's selected background (video or image)
/// and writes it to the shared App Group container so the widget can use it.
enum WidgetBackgroundService {
    private static let fileName = "widget-background.jpg"

    static var sharedImageURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.bibleplus.shared")?
            .appendingPathComponent(fileName)
    }

    /// Call when the user changes their background. Extracts a frame from video,
    /// copies a static image, or clears the file for gradient-only backgrounds.
    /// Automatically reloads widget timelines after the image is ready.
    static func updateWidgetBackground(for background: SanctuaryBackground) {
        if let videoName = background.videoFileName {
            extractVideoFrame(named: videoName)
        } else if let imageName = background.imageName {
            copyImage(named: imageName)
            reloadWidgets()
        } else {
            // Gradient-only — remove any stale image so widget falls back to gradient
            removeImage()
            reloadWidgets()
        }
    }

    /// Load the saved widget background image (used by widget extension)
    static func loadWidgetBackgroundImage() -> UIImage? {
        guard let url = sharedImageURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Private

    private static func extractVideoFrame(named videoName: String) {
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            removeImage()
            reloadWidgets()
            return
        }

        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)

        // Grab a frame at 2 seconds (more representative than first frame)
        let time = CMTime(seconds: 2.0, preferredTimescale: 600)

        Task.detached(priority: .utility) {
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let uiImage = UIImage(cgImage: cgImage)
                saveImage(uiImage)
            } catch {
                // Fallback: try first frame
                do {
                    let (cgImage, _) = try await generator.image(at: .zero)
                    let uiImage = UIImage(cgImage: cgImage)
                    saveImage(uiImage)
                } catch {
                    removeImage()
                }
            }
            // Reload after image is saved (or removed on failure)
            await MainActor.run {
                reloadWidgets()
            }
        }
    }

    private static func copyImage(named imageName: String) {
        guard let url = Bundle.main.url(forResource: imageName, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else {
            removeImage()
            return
        }
        saveImage(image)
    }

    private static func saveImage(_ image: UIImage) {
        guard let url = sharedImageURL,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func removeImage() {
        guard let url = sharedImageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
