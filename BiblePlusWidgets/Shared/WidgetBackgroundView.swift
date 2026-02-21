import SwiftUI

/// Shared background view used by all widget containerBackgrounds.
/// Renders gradient + optional image (from embedded Data) + vignette.
/// NOTE: Avoids GeometryReader which can return zero size inside
/// .containerBackground(for: .widget) on .systemSmall widgets.
struct WidgetBackgroundView: View {
    let gradientColors: [String]
    let imageData: Data?

    var body: some View {
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
            }

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.25)],
                center: .center,
                startRadius: 80,
                endRadius: 250
            )
        }
    }
}
