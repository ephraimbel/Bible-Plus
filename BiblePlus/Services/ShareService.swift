import SwiftUI

enum ShareService {
    @MainActor
    static func renderShareImage(
        content: PrayerContent,
        displayText: String,
        background: SanctuaryBackground,
        aspectRatio: ShareAspectRatio
    ) -> UIImage? {
        let view = ShareCardView(
            content: content,
            displayText: displayText,
            background: background,
            aspectRatio: aspectRatio
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
