import SwiftUI

/// Shared background view used by all widget containerBackgrounds.
/// Renders gradient + optional image (from embedded Data) + vignette.
struct WidgetBackgroundView: View {
    let gradientColors: [String]
    let imageData: Data?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: gradientColors.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }

                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.25)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 250
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
