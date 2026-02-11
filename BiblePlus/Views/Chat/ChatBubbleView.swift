import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool
    @Environment(\.bpPalette) private var palette

    private var isTypingPlaceholder: Bool {
        isStreaming && message.role == .assistant && message.content.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(palette.accentSoft)
                    )
                    .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if isTypingPlaceholder {
                    TypingDotsView()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(bubbleColor)
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    Text(message.content)
                        .font(BPFont.chat)
                        .foregroundStyle(message.role == .user ? .white : palette.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(bubbleColor)
                        )
                        .textSelection(.enabled)
                }
            }
            .animation(BPAnimation.spring, value: isTypingPlaceholder)

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var bubbleColor: Color {
        message.role == .user
            ? palette.accent
            : palette.surface
    }
}
