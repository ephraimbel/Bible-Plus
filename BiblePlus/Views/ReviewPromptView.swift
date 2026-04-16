import SwiftUI

struct ReviewPromptView: View {
    @Environment(\.bpPalette) private var palette
    let onYes: () -> Void
    let onNotYet: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(palette.accent)

            Text("Enjoying Bible+?")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Text("Your rating helps others find\nGod's Word through this app.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: onYes) {
                    Text("Yes, I'll Rate It")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onNotYet) {
                    Text("Not Yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .padding(28)
        .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, 40)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}
