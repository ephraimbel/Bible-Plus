import SwiftUI

struct QuoteCard: View {
    let text: String
    let attribution: String

    @Environment(\.bpPalette) private var palette
    @State private var marksGlow = false

    var body: some View {
        VStack(spacing: 14) {
            Text("\u{201C}")
                .font(.custom("Georgia", size: 72))
                .foregroundStyle(palette.accent.opacity(marksGlow ? 0.45 : 0.25))
                .offset(y: 14)
                .frame(height: 32)

            Text(text)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(9)
                .fixedSize(horizontal: false, vertical: true)

            if !attribution.isEmpty {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(palette.accent.opacity(0.4))
                        .frame(width: 18, height: 1)
                    Text(attribution)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .tracking(0.5)
                        .foregroundStyle(palette.accent.opacity(0.9))
                    Rectangle()
                        .fill(palette.accent.opacity(0.4))
                        .frame(width: 18, height: 1)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surfaceElevated.opacity(0.55),
                            palette.surfaceElevated.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                marksGlow = true
            }
        }
    }
}
