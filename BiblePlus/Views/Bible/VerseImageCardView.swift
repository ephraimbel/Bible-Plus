import SwiftUI

struct VerseImageCardView: View {
    let verseText: String
    let reference: String
    let translation: String
    let background: SanctuaryBackground
    let aspectRatio: ShareAspectRatio

    private var renderSize: CGSize {
        CGSize(
            width: aspectRatio.size.width / 3.0,
            height: aspectRatio.size.height / 3.0
        )
    }

    private var fontScale: CGFloat {
        aspectRatio == .wide ? 0.85 : 1.0
    }

    var body: some View {
        ZStack {
            // LAYER 1: Background
            if let imageName = background.imageName,
               let uiImage = SanctuaryBackground.loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: renderSize.width, height: renderSize.height)
                    .clipped()
            } else {
                LinearGradient(
                    colors: background.gradientColors.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // LAYER 2: Readability overlay
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.15),
                        Color.black.opacity(0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: renderSize.height * 0.15)

                Spacer()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.25),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: renderSize.height * 0.45)
            }

            // LAYER 3: Content
            VStack(spacing: 0) {
                Spacer()

                // Open quote mark
                Text("\u{201C}")
                    .font(.system(size: 36 * fontScale, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 4)

                // Verse text
                Text(verseText)
                    .font(.system(size: contentFontSize * fontScale, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, renderSize.width * 0.1)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                // Reference
                Text("— \(reference)")
                    .font(.system(size: 12 * fontScale, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 14)

                // Translation badge
                Text(translation)
                    .font(.system(size: 9 * fontScale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.0)
                    .padding(.top, 4)

                Spacer()
            }

            // LAYER 4: Watermark
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Bible+")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(12)
                }
            }
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }

    private var contentFontSize: CGFloat {
        if verseText.count > 250 {
            return 16
        } else if verseText.count > 120 {
            return 18
        } else {
            return 22
        }
    }
}
