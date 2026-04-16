import SwiftUI

struct OnboardingBackground: View {
    @Environment(\.bpPalette) private var palette

    var body: some View {
        ZStack {
            // Blurred biblical art — matches the welcome screen aesthetic
            Image("biblical_jacob_ladder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 28)
                .scaleEffect(1.15)
                .clipped()

            // Warm cream overlay for legibility
            palette.background.opacity(0.72)

            // Gold glow from top
            RadialGradient(
                colors: [Color(hex: "C9A96E").opacity(0.10), Color.clear],
                center: .init(x: 0.5, y: 0.12),
                startRadius: 0,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
    }
}

struct SunriseBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "FFF1E0"),
                    Color(hex: "FFDBB5"),
                    Color(hex: "F5EFE0"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(hex: "C9A96E").opacity(0.15),
                    Color.clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}
