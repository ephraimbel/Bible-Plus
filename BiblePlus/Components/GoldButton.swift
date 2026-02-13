import SwiftUI

struct GoldButton: View {
    let title: String
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
                .font(BPFont.button)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEnabled ? palette.accent : Color.gray.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.accent.opacity(0.6), lineWidth: 2)
                        .blur(radius: showGlow ? 8 : 0)
                        .opacity(showGlow ? glowOpacity : 0)
                )
                .shadow(
                    color: isEnabled ? palette.accent.opacity(0.3) : .clear,
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
