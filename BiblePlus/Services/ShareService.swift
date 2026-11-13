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
    static func renderChatImage(
        messageContent: String,
        background: SanctuaryBackground,
        aspectRatio: ShareAspectRatio
    ) -> UIImage? {
        let view = ChatShareCardView(
            messageContent: messageContent,
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
        attribution: String? = nil,
        background: SanctuaryBackground,
        aspectRatio: ShareAspectRatio
    ) -> UIImage? {
        let view = VerseImageCardView(
            verseText: verseText,
            reference: reference,
            translation: translation,
            attribution: attribution,
            background: background,
            aspectRatio: aspectRatio
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
