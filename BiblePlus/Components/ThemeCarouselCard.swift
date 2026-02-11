import SwiftUI

struct ThemeCarouselCard: View {
    let theme: ThemeDefinition
    let isSelected: Bool
    let userName: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            VStack(spacing: 0) {
                // Theme preview: gradient background with mock prayer card
                ZStack {
                    LinearGradient(
                        colors: theme.previewGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Mock prayer card preview
                    VStack(spacing: 8) {
                        Text("\(userName),")
                            .font(BPFont.prayerNameMedium)
                            .foregroundStyle(
                                isDarkTheme ? .white : BPColorPalette.light.textPrimary
                            )

                        Text("God is with you\nright now.")
                            .font(BPFont.prayerMedium)
                            .foregroundStyle(
                                isDarkTheme ? .white.opacity(0.9) : BPColorPalette.light.textPrimary
                            )
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
                .frame(height: 200)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                )

                // Theme name and selection indicator
                HStack {
                    Text(theme.name)
                        .font(BPFont.button)
                        .foregroundStyle(BPColorPalette.light.textPrimary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(BPColorPalette.light.accent)
                    } else {
                        Circle()
                            .stroke(BPColorPalette.light.border, lineWidth: 2)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(16)
                .background(BPColorPalette.light.surfaceElevated)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 0
                    )
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? BPColorPalette.light.accent : BPColorPalette.light.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? BPColorPalette.light.accent.opacity(0.2) : Color.black.opacity(0.05),
                radius: isSelected ? 12 : 4,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .animation(BPAnimation.selection, value: isSelected)
    }

    private var isDarkTheme: Bool {
        // Check if the first color in the gradient is dark
        guard let firstHex = theme.previewGradient.first else { return false }
        let hex = firstHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.5
    }
}
