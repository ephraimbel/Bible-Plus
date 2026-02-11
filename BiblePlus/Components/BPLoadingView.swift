import SwiftUI

struct BPLoadingView: View {
    @Environment(\.bpPalette) private var palette
    @State private var pulse = false

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(palette.accent)
                    .scaleEffect(pulse ? 1.1 : 0.9)
                    .opacity(pulse ? 1.0 : 0.5)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}
