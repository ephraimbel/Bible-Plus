import SwiftUI

struct OnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "FFF8F0"),
                Color(hex: "FAF3E8"),
                Color(hex: "F5EFE0"),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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

            // Subtle radial glow at center top
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
