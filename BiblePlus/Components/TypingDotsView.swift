import SwiftUI

struct TypingDotsView: View {
    var contextLabel: String? = nil
    @Environment(\.bpPalette) private var palette

    @State private var pulsePhase: Bool = false
    @State private var labelOpacity: Double = 0
    @State private var dotPhase: Int = 0

    private let dotTimer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    private var displayLabel: String {
        contextLabel ?? "Thinking"
    }

    private var animatedDots: String {
        switch dotPhase % 4 {
        case 0: return ""
        case 1: return "."
        case 2: return ".."
        case 3: return "..."
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Sparkle avatar — matches the AI message indicator exactly
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.08))
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent.opacity(0.18), palette.accent.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.84, blue: 0.3), palette.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(pulsePhase ? 1.1 : 0.9)
            }

            // Contextual text
            Text(displayLabel + animatedDots)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(palette.textMuted.opacity(0.7))
                .opacity(labelOpacity)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
            withAnimation(.easeOut(duration: 0.5)) {
                labelOpacity = 1
            }
        }
        .onReceive(dotTimer) { _ in
            dotPhase += 1
        }
        .onChange(of: contextLabel) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) {
                labelOpacity = 0.4
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                labelOpacity = 1
            }
        }
    }
}
