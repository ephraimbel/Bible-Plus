import SwiftUI

struct ScriptureCard: View {
    let quote: String
    let reference: String
    let imageKey: String?
    let messageId: UUID
    let conversationId: UUID
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        let context = "\(quote) \(reference)"
        let resolvedKey: String? = BiblicalImageService.resolveKey(
            for: imageKey ?? "",
            context: context,
            messageId: messageId,
            conversationId: conversationId
        )

        return VStack(spacing: 0) {
            artImage(resolvedKey: resolvedKey)
            textBlock(resolvedKey: resolvedKey)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func artImage(resolvedKey: String?) -> some View {
        if let key = resolvedKey, let uiImage = BiblicalImageService.rawImage(for: key) {
            imageLayer(Image(uiImage: uiImage))
        } else if let defaultImage = BiblicalImageService.defaultImage(for: resolvedKey ?? imageKey ?? quote) {
            imageLayer(Image(uiImage: defaultImage))
        } else {
            BiblicalImageService.fallbackGradient(for: resolvedKey ?? imageKey ?? "default")
                .frame(maxWidth: .infinity)
                .frame(height: 200)
        }
    }

    private func imageLayer(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .clear,
                        palette.surfaceElevated.opacity(0.4),
                        palette.surfaceElevated.opacity(0.8),
                        palette.surfaceElevated
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
                .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private func textBlock(resolvedKey: String?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("FROM SCRIPTURE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(quote)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(9)
                .fixedSize(horizontal: false, vertical: true)

            if !reference.isEmpty {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(palette.accent.opacity(0.4))
                        .frame(width: 18, height: 1)
                    BubbleReferenceButton(reference: reference, onScriptureTap: onScriptureTap)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                }
            }

            if let key = resolvedKey, let entry = resolveArtistEntry(for: key) {
                Text(entry.artist.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(palette.textMuted.opacity(0.5))
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceElevated)
    }

    private func resolveArtistEntry(for key: String) -> ImageEntry? {
        if BiblicalImageService.rawImage(for: key) != nil {
            return BiblicalImageService.entry(for: key)
        }
        return BiblicalImageService.defaultEntry(for: key)
    }
}
