import SwiftUI

/// Shared background view used by all home-screen widgets.
/// Renders gradient + optional image (from embedded Data) + vignette.
/// Now embedded directly inside each entry view's ZStack (not in containerBackground),
/// so GeometryReader is safe to use for image sizing.
struct WidgetBackgroundView: View {
    let gradientColors: [String]
    let imageData: Data?

    var body: some View {
        ZStack {
            // Solid fallback in case gradientColors is empty
            Color(hex: gradientColors.first ?? "C9A96E")

            if gradientColors.count > 1 {
                LinearGradient(
                    colors: gradientColors.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if let imageData, let uiImage = UIImage(data: imageData) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
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
