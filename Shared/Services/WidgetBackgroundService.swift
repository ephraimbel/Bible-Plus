import AVFoundation
import UIKit
import WidgetKit

// MARK: - Widget Content Cache Models

/// A single cached content item — lightweight Codable representation
struct CachedWidgetContent: Codable {
    let id: String          // UUID string
    let displayText: String
    let shortText: String
    let verseReference: String?
    let contentType: String // ContentType raw value
}

/// Container for the cached content list + metadata for staleness checks
struct WidgetContentCache: Codable {
    let items: [CachedWidgetContent]
    let timeWindow: String  // WidgetTimeWindow raw value when cache was built
    let createdAt: Date
    let daySeed: Int        // day-of-year seed used for deterministic scoring

    /// Cache is stale if time window changed or cache is older than 3 hours
    var isStale: Bool {
        let currentWindow = WidgetTimeWindow.current().rawValue
        if currentWindow != timeWindow { return true }
        return Date().timeIntervalSince(createdAt) > 3 * 60 * 60
    }
}

/// Stores the user's selected background for widgets.
/// Gradient colors are stored in UserDefaults (App Group) — tiny data.
/// Image data is stored as a **file** in the App Group container to avoid
/// bloating timeline entries (which would exceed the 30 MB Jetsam limit).
enum WidgetBackgroundService {
    private static let gradientKey = "widgetGradientColors"
    private static let contentOffsetKey = "widgetContentOffset"
    private static let contentCacheKey = "widgetContentCache"
    private static let cacheTimeWindowKey = "widgetCacheTimeWindow"
    private static let imageFileName = "widget-background.jpg"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.io.bibleplus.shared")
    }

    private static var imageFileURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.io.bibleplus.shared"
        )?.appendingPathComponent(imageFileName)
    }

    // MARK: - Public API

    /// Call when the user changes their background. Extracts a frame from video,
    /// copies a static image, or clears the image for gradient-only backgrounds.
    /// Persists gradient colors to UserDefaults, image to App Group file.
    /// Automatically reloads widget timelines after the data is ready.
    static func updateWidgetBackground(for background: SanctuaryBackground) {
        // Always persist gradient colors to UserDefaults (App Group)
        sharedDefaults?.set(background.gradientColors, forKey: gradientKey)

        if let videoName = background.videoFileName {
            extractVideoFrame(named: videoName)
        } else if let imageName = background.imageName {
            copyImage(named: imageName)
            reloadWidgets()
        } else {
            // Gradient-only — remove any stale image
            removeImageFile()
            reloadWidgets()
        }
    }

    /// Read gradient colors from UserDefaults (App Group).
    static func loadGradientColors() -> [String]? {
        sharedDefaults?.stringArray(forKey: gradientKey)
    }

    /// Load widget background image from the App Group file.
    /// Called at render time by WidgetBackgroundView — NOT stored in entries.
    static func loadWidgetBackgroundImage() -> UIImage? {
        guard let url = imageFileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Read the user's manual content offset (for next/prev navigation arrows)
    static func loadContentOffset() -> Int {
        sharedDefaults?.integer(forKey: contentOffsetKey) ?? 0
    }

    /// Save the user's manual content offset
    static func saveContentOffset(_ offset: Int) {
        sharedDefaults?.set(offset, forKey: contentOffsetKey)
    }

    // MARK: - Content Cache

    /// Save a pre-scored content list to UserDefaults for fast offset lookups
    static func saveContentCache(_ cache: WidgetContentCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        sharedDefaults?.set(data, forKey: contentCacheKey)
    }

    /// Load the cached content list (returns nil if missing or corrupt)
    static func loadContentCache() -> WidgetContentCache? {
        guard let data = sharedDefaults?.data(forKey: contentCacheKey) else { return nil }
        return try? JSONDecoder().decode(WidgetContentCache.self, from: data)
    }

    /// Clear the content cache (e.g. when profile changes)
    static func clearContentCache() {
        sharedDefaults?.removeObject(forKey: contentCacheKey)
    }

    // MARK: - Private

    private static func extractVideoFrame(named videoName: String) {
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            removeImageFile()
            reloadWidgets()
            return
        }

        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)

        // Grab a frame at 2 seconds (more representative than first frame)
        let time = CMTime(seconds: 2.0, preferredTimescale: 600)

        Task.detached(priority: .utility) {
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let uiImage = UIImage(cgImage: cgImage)
                saveImageToFile(uiImage)
            } catch {
                // Fallback: try first frame
                do {
                    let (cgImage, _) = try await generator.image(at: .zero)
                    let uiImage = UIImage(cgImage: cgImage)
                    saveImageToFile(uiImage)
                } catch {
                    removeImageFile()
                }
            }
            await MainActor.run {
                reloadWidgets()
            }
        }
    }

    private static func copyImage(named imageName: String) {
        // Try .jpg first, then .jpeg, then .png
        let extensions = ["jpg", "jpeg", "png"]
        var image: UIImage?

        for ext in extensions {
            if let url = Bundle.main.url(forResource: imageName, withExtension: ext),
               let loaded = UIImage(contentsOfFile: url.path) {
                image = loaded
                break
            }
        }

        guard let image else {
            removeImageFile()
            return
        }

        saveImageToFile(image)
    }

    /// Downscale image to max 300px, compress as JPEG, write to App Group file.
    private static func saveImageToFile(_ image: UIImage) {
        let maxDimension: CGFloat = 300
        let resized = downsample(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.6),
              let url = imageFileURL else { return }
        try? data.write(to: url, options: .atomic)

        // Clean up legacy UserDefaults image data if present
        sharedDefaults?.removeObject(forKey: "widgetBackgroundImageData")
    }

    private static func removeImageFile() {
        guard let url = imageFileURL else { return }
        try? FileManager.default.removeItem(at: url)

        // Clean up legacy UserDefaults image data if present
        sharedDefaults?.removeObject(forKey: "widgetBackgroundImageData")
    }

    private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
