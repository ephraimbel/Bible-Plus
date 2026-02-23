import SwiftUI

/// Shared background view used by all home-screen widgets.
/// Renders gradient + optional image (from embedded Data) + vignette.
///
/// Image is rendered as an .overlay on the gradient base, which constrains
/// it to the gradient's bounds without affecting ZStack layout.
/// This avoids both GeometryReader (zero-size in widget context) and
/// direct ZStack siblings (scaledToFill inflates layout).
struct WidgetBackgroundView: View {
    let gradientColors: [String]
    let imageData: Data?

    var body: some View {
        gradientBase
            .overlay {
                imageLayer
            }
            .overlay {
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.25)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 250
                )
            }
    }

    private var gradientBase: some View {
        ZStack {
            Color(hex: gradientColors.first ?? "C9A96E")

            if gradientColors.count > 1 {
                LinearGradient(
                    colors: gradientColors.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipped()
        }
    }
}
