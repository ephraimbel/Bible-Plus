import SwiftUI

struct PrayerCard: View {
    let text: String

    @Environment(\.bpPalette) private var palette
    @State private var amenTapped = false
    @State private var amenGlow = false
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A PRAYER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(text)
                .font(.system(size: 15.5, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(5)
                .italic()

            if !amenTapped {
                amenButton
            } else {
                amenConfirmed
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.08),
                            Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.03),
                            palette.surfaceElevated.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: palette.accent.opacity(0.08), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
        )
        .overlay(
            LinearGradient(
                colors: [.clear, palette.accent.opacity(0.15), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120)
            .offset(x: shimmerOffset)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .padding(.vertical, 4)
    }

    private var amenButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                amenTapped = true
            }
            shimmerOffset = -200
            withAnimation(.easeInOut(duration: 0.6)) {
                shimmerOffset = 400
            }
            HapticService.success()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hands.clap.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Amen")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: palette.accent.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var amenConfirmed: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
            Text("Amen")
                .font(.system(size: 13, weight: .medium, design: .serif))
        }
        .foregroundStyle(palette.accent.opacity(0.6))
        .shadow(color: palette.accent.opacity(amenGlow ? 0.4 : 0), radius: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                amenGlow = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                amenGlow = false
            }
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}
