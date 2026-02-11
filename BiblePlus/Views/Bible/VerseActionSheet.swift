import SwiftUI

struct VerseActionSheet: View {
    let verse: VerseItem
    let reference: String
    let onExplain: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onDismiss: () -> Void
    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(palette.textMuted.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            // Verse preview
            VStack(spacing: 8) {
                Text(reference)
                    .font(BPFont.reference)
                    .foregroundStyle(palette.accent)

                Text(verse.text)
                    .font(BPFont.bibleMedium)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()
                .overlay(palette.border)

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
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 8)
        }
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)

                Text(title)
                    .font(BPFont.body)
                    .foregroundStyle(palette.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}
