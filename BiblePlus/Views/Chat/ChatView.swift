import SwiftUI

struct ChatView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                BPColorPalette.light.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(BPColorPalette.light.accent)

                    Text("AI Bible Companion")
                        .font(BPFont.headingMedium)
                        .foregroundStyle(BPColorPalette.light.textPrimary)

                    Text("Ask anything about Scripture,\nfaith, and life. Your AI companion\nis coming soon.")
                        .font(BPFont.body)
                        .foregroundStyle(BPColorPalette.light.textMuted)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, 32)
            }
        }
    }
}
