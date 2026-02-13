import SwiftUI

struct PlanCompletionView: View {
    let planName: String
    let onDismiss: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var showIcon = false
    @State private var showText = false
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                // Trophy icon with glow
                ZStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(palette.accent)
                        .shadow(color: palette.accent.opacity(glowOpacity), radius: 20)
                }
                .scaleEffect(showIcon ? 1 : 0.3)
                .opacity(showIcon ? 1 : 0)

                VStack(spacing: 12) {
                    Text("Plan Complete!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("You finished")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(planName)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.accent)
                        .multilineTextAlignment(.center)

                    Text("Your faithfulness in God's Word\nis building something beautiful.")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 4)
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                showIcon = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticService.success()
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showText = true
            }
            withAnimation(BPAnimation.glowPulse) {
                glowOpacity = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                onDismiss()
            }
        }
    }
}
