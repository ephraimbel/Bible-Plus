import SwiftUI

enum ShareService {
    @MainActor
    static func renderShareImage(
        content: PrayerContent,
        displayText: String,
        theme: ThemeDefinition,
        aspectRatio: ShareAspectRatio
    ) -> UIImage? {
        let view = ShareCardView(
            content: content,
            displayText: displayText,
            theme: theme,
            aspectRatio: aspectRatio
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
