import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.92
    @State private var glowIntensity: Double = 0
    @State private var exitOpacity: Double = 1

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.3)

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "2B2A27") : Color(hex: "EFE4D6"))
                .ignoresSafeArea()

            HStack(spacing: 2) {
                Text("Bible")
                    .font(.system(size: 42, weight: .light, design: .serif))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color(hex: "3B2B1D"))

                Image(systemName: "sparkle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(gold)
                    .shadow(color: gold.opacity(glowIntensity), radius: 4)
                    .shadow(color: gold.opacity(glowIntensity), radius: 10)
                    .shadow(color: gold.opacity(glowIntensity * 0.7), radius: 20)
                    .shadow(color: gold.opacity(glowIntensity * 0.4), radius: 40)
            }
            .scaleEffect(textScale)
            .opacity(textOpacity)
        }
        .opacity(exitOpacity)
        .onAppear {
            // Phase 1: Fade in text
            withAnimation(.easeOut(duration: 0.6)) {
                textOpacity = 1.0
                textScale = 1.0
            }

            // Phase 2: Glow blooms after text settles
            withAnimation(.easeInOut(duration: 0.8).delay(0.4)) {
                glowIntensity = 1.0
            }
        }
    }
}
