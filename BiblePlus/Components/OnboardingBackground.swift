import SwiftUI

struct OnboardingBackground: View {
    @Environment(\.bpPalette) private var palette

    var body: some View {
        ZStack {
            // Palette tan canvas FIRST so nothing reads through as yellow
            palette.background
                .ignoresSafeArea()

            // Biblical art as a whisper of texture (was 100% bg — now
            // ~15% overlay so the tan/peach palette fully dominates).
            Image("biblical_jacob_ladder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 44)
                .scaleEffect(1.22)
                .clipped()
                .opacity(0.15)
                .ignoresSafeArea()

            // Subtle gold glow from top — palette accent
            RadialGradient(
                colors: [palette.accent.opacity(0.06), Color.clear],
                center: .init(x: 0.5, y: 0.12),
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()
        }
    }
}
