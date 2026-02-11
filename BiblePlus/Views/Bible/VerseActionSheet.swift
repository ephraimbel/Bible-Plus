import SwiftUI

struct VerseActionSheet: View {
    let verse: VerseItem
    let reference: String
    let onExplain: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(BPColorPalette.light.textMuted.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            // Verse preview
            VStack(spacing: 8) {
                Text(reference)
                    .font(BPFont.reference)
                    .foregroundStyle(BPColorPalette.light.accent)

                Text(verse.text)
                    .font(BPFont.bibleMedium)
                    .foregroundStyle(BPColorPalette.light.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()
                .foregroundStyle(BPColorPalette.light.border)

            // Action buttons
            VStack(spacing: 0) {
                actionRow(icon: "bubble.left.and.bubble.right", title: "Explain This Verse", action: onExplain)
                actionRow(icon: "doc.on.doc", title: "Copy", action: onCopy)
                actionRow(icon: "square.and.arrow.up", title: "Share", action: onShare)
            }
            .padding(.vertical, 8)

            // Cancel
            Button {
                onDismiss()
            } label: {
                Text("Cancel")
                    .font(BPFont.button)
                    .foregroundStyle(BPColorPalette.light.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 8)
        }
        .background(BPColorPalette.light.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(BPColorPalette.light.accent)
                    .frame(width: 28)

                Text(title)
                    .font(BPFont.body)
                    .foregroundStyle(BPColorPalette.light.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}
