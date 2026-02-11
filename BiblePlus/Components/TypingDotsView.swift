import SwiftUI

struct TypingDotsView: View {
    @Environment(\.bpPalette) private var palette
    @State private var activeIndex: Int = 0

    private let dotCount = 3
    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 5
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(palette.textMuted)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(activeIndex == index ? 1.3 : 0.8)
                    .opacity(activeIndex == index ? 1.0 : 0.4)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1),
                        value: activeIndex
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % dotCount
        }
    }
}
