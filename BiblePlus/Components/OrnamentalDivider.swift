import SwiftUI

struct OrnamentalDivider: View {
    var color: Color = .white
    var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(opacity))
                .frame(width: 20, height: 0.5)

            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .light))
                .foregroundStyle(color.opacity(opacity + 0.1))

            Rectangle()
                .fill(color.opacity(opacity))
                .frame(width: 20, height: 0.5)
        }
        .frame(height: 12)
    }
}
