import SwiftUI

struct ChatShareCardView: View {
    let messageContent: String
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

    private var displayText: String {
        if messageContent.count > 300 {
            return String(messageContent.prefix(297)) + "..."
        }
        return messageContent
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
            } else if let videoName = background.videoFileName,
                      let uiImage = SanctuaryBackground.loadVideoThumbnail(named: videoName) {
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

                Text("AI COMPANION")
                    .font(.system(size: 10 * fontScale, weight: .regular))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 12)

                Text(displayText)
                    .font(.system(size: contentFontSize * fontScale, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, renderSize.width * 0.1)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

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
        if displayText.count > 250 {
            return 14
        } else if displayText.count > 150 {
            return 16
        } else if displayText.count > 80 {
            return 18
        } else {
            return 22
        }
    }
}
