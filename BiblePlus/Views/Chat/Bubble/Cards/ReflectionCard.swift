import SwiftUI

struct ReflectionCard: View {
    let question: String

    @Environment(\.bpPalette) private var palette
    @State private var barGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FOR REFLECTION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(question)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(6)
                .italic()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.4))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(palette.accent.opacity(barGlow ? 0.35 : 0.2))
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                barGlow = true
            }
        }
    }
}
