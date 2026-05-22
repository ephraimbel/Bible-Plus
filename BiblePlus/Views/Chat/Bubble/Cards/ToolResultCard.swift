import SwiftUI

struct ToolResultCard: View {
    let name: String
    let summary: String
    let isError: Bool

    @Environment(\.bpPalette) private var palette

    var body: some View {
        let accent: Color = isError ? palette.error : palette.accent

        return VStack(alignment: .leading, spacing: 4) {
            Text(isError ? "AGENT ERROR" : "AGENT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(accent.opacity(0.7))

            Text(summary)
                .font(.system(size: 13.5, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.leading, 18)
        .padding(.trailing, 0)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, 8)
                Circle()
                    .fill(accent.opacity(0.9))
                    .frame(width: 5, height: 5)
                    .offset(x: -2, y: 8)
            }
            .frame(width: 5)
        }
    }
}
