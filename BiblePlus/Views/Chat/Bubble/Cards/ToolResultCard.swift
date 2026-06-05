import SwiftUI

struct ToolResultCard: View {
    let name: String
    let summary: String
    let isError: Bool

    @Environment(\.bpPalette) private var palette

    var body: some View {
        let accent: Color = isError ? palette.error : palette.accent

        // A quiet companion aside — our Ask ✦ star, then the action in muted
        // italic serif. No "AGENT" label: this reads as Scripture being
        // consulted, not a machine reporting a tool call.
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent.opacity(0.85))

            Text(summary)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }
}
