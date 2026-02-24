import SwiftUI

/// Shared background view used by all home-screen widgets.
/// Renders gradient + optional image (loaded from App Group file) + vignette.
///
/// Image is loaded at render time from the App Group container file,
/// NOT from timeline entry data. This avoids duplicating large image data
/// across multiple timeline entries which would exceed the 30 MB Jetsam limit.
struct WidgetBackgroundView: View {
    let gradientColors: [String]

    var body: some View {
        Color(hex: gradientColors.first ?? "C9A96E")
            .overlay {
                if gradientColors.count > 1 {
                    LinearGradient(
                        colors: gradientColors.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay {
                if let uiImage = WidgetBackgroundService.loadWidgetBackgroundImage() {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay {
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.25)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 250
                )
            }
    }
}
