import SwiftUI

struct BibleView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                BPColorPalette.light.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "book")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(BPColorPalette.light.accent)

                    Text("Bible Reader")
                        .font(BPFont.headingMedium)
                        .foregroundStyle(BPColorPalette.light.textPrimary)

                    Text("A beautiful Bible reader with\nAI-powered verse interpretation\nis coming soon.")
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
