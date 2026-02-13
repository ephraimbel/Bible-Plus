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

    @MainActor
    static func renderVerseImage(
        verseText: String,
        reference: String,
        translation: String,
        background: SanctuaryBackground,
        aspectRatio: ShareAspectRatio
    ) -> UIImage? {
        let view = VerseImageCardView(
            verseText: verseText,
            reference: reference,
            translation: translation,
            background: background,
            aspectRatio: aspectRatio
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
