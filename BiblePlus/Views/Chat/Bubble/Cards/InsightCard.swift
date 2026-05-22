import SwiftUI

struct InsightCard: View {
    let text: String

    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(spacing: 18) {
            Rectangle()
                .fill(palette.accent.opacity(0.4))
                .frame(width: 32, height: 1)

            Text("KEY INSIGHT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(text)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)

            Rectangle()
                .fill(palette.accent.opacity(0.4))
                .frame(width: 32, height: 1)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.vertical, 6)
    }
}
