import SwiftUI

struct ImageCard: View {
    let key: String
    let caption: String

    @Environment(\.bpPalette) private var palette

    var body: some View {
        let resolvedKey = BiblicalImageService.resolveKey(for: key, context: caption)
        let renderedImage: UIImage? = BiblicalImageService.rawImage(for: resolvedKey)
            ?? BiblicalImageService.defaultImage(for: resolvedKey)

        return VStack(spacing: 0) {
            imageLayer(resolvedKey: resolvedKey, renderedImage: renderedImage)

            if !caption.isEmpty {
                captionRow
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func imageLayer(resolvedKey: String, renderedImage: UIImage?) -> some View {
        if let uiImage = renderedImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.06)
                )
        } else {
            BiblicalImageService.fallbackGradient(for: resolvedKey)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
        }
    }

    private var captionRow: some View {
        Text(caption)
            .font(.system(size: 13, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(palette.textMuted.opacity(0.85))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .padding(.vertical, 14)
            .background(palette.surfaceElevated.opacity(0.35))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(palette.accent.opacity(0.5))
                    .frame(width: 2)
                    .padding(.vertical, 14)
            }
    }
}
