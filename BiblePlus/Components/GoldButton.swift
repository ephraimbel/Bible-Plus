import SwiftUI

struct GoldButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var showGlow: Bool = false
    let action: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        Button(action: {
            HapticService.impact(.light)
            action()
        }) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .serif))
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            isEnabled
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(Color.gray.opacity(0.3))
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(palette.accent.opacity(0.5), lineWidth: 1.5)
                        .blur(radius: showGlow ? 8 : 0)
                        .opacity(showGlow ? glowOpacity : 0)
                )
                .shadow(
                    color: isEnabled ? palette.accent.opacity(0.35) : .clear,
                    radius: 12,
                    y: 4
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .onAppear {
            if showGlow {
                withAnimation(BPAnimation.glowPulse) {
                    glowOpacity = 0.8
                }
            }
        }
    }
}
