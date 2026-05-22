import SwiftUI

struct StoryCard: View {
    let title: String
    let summary: String
    let imageKey: String?
    let messageId: UUID
    let conversationId: UUID

    @Environment(\.bpPalette) private var palette

    var body: some View {
        let context = "\(title) \(summary)"
        let resolvedKey = BiblicalImageService.resolveKey(
            for: imageKey ?? "",
            context: context,
            messageId: messageId,
            conversationId: conversationId
        )
        let renderedImage: UIImage? = BiblicalImageService.rawImage(for: resolvedKey)
            ?? BiblicalImageService.defaultImage(for: resolvedKey)

        return VStack(alignment: .leading, spacing: 0) {
            heroHeader(resolvedKey: resolvedKey, renderedImage: renderedImage)
            dropCapText(summary)
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func heroHeader(resolvedKey: String, renderedImage: UIImage?) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let uiImage = renderedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.5),
                                Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.92),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.1)
                    )
            } else {
                BiblicalImageService.fallbackGradient(for: resolvedKey)
                    .frame(height: 120)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("A STORY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.45).opacity(0.9))

                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dropCapText(_ text: String) -> some View {
        if text.count > 1 {
            let first = String(text.prefix(1))
            let rest = String(text.dropFirst())
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(first)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(palette.accent)
                    .baselineOffset(-2)
                Text(rest)
                    .font(.system(size: 14.5, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(4)
            }
        } else {
            Text(text)
                .font(.system(size: 14.5, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(4)
        }
    }
}
