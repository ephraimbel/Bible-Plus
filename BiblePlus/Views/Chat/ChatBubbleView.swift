import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(BPColorPalette.light.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(BPColorPalette.light.accentSoft)
                    )
                    .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty && isStreaming ? "..." : message.content)
                    .font(BPFont.chat)
                    .foregroundStyle(message.role == .user ? .white : BPColorPalette.light.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(bubbleColor)
                    )
                    .textSelection(.enabled)

                if isStreaming && message.role == .assistant {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Thinking...")
                            .font(BPFont.caption)
                            .foregroundStyle(BPColorPalette.light.textMuted)
                    }
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var bubbleColor: Color {
        message.role == .user
            ? BPColorPalette.light.accent
            : BPColorPalette.light.surface
    }
}
