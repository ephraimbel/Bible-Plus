import SwiftUI
import SwiftData

struct ChatView: View {
    var initialContext: String? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    ChatContentView(viewModel: vm)
                } else {
                    Color.clear.onAppear {
                        viewModel = ChatViewModel(
                            modelContext: modelContext,
                            initialContext: initialContext
                        )
                    }
                }
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let vm = viewModel, !vm.messages.isEmpty {
                        Button {
                            vm.clearConversation()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(BPColorPalette.light.textMuted)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Inner Content View

private struct ChatContentView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Messages or quick prompts
            if viewModel.messages.isEmpty {
                QuickPromptsView(
                    prompts: viewModel.quickPrompts,
                    userName: viewModel.userName,
                    onTap: { viewModel.sendQuickPrompt($0) }
                )
            } else {
                messageList
            }

            // Error banner
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            // Rate limit indicator
            if !viewModel.profile.isPro && !viewModel.messages.isEmpty {
                rateLimitBanner
            }

            // Input bar
            inputBar
        }
        .background(BPColorPalette.light.background)
        .onAppear {
            viewModel.applyInitialContext()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.messages) { message in
                        if message.role != .system {
                            ChatBubbleView(
                                message: message,
                                isStreaming: viewModel.isStreaming
                                    && message.id == viewModel.messages.last?.id
                                    && message.role == .assistant
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastID = viewModel.messages.last?.id {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(BPFont.caption)
            .foregroundStyle(BPColorPalette.light.error)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(BPColorPalette.light.error.opacity(0.1))
            .onTapGesture {
                viewModel.errorMessage = nil
            }
    }

    // MARK: - Rate Limit Banner

    private var rateLimitBanner: some View {
        Text("\(viewModel.remainingMessages) messages remaining today")
            .font(BPFont.caption)
            .foregroundStyle(BPColorPalette.light.textMuted)
            .padding(.vertical, 6)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask anything about Scripture...", text: $viewModel.inputText, axis: .vertical)
                .font(BPFont.body)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(BPColorPalette.light.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(BPColorPalette.light.border, lineWidth: 1)
                )

            Button {
                viewModel.send()
                HapticService.lightImpact()
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.canSend || viewModel.isStreaming
                            ? BPColorPalette.light.accent
                            : BPColorPalette.light.textMuted
                    )
            }
            .disabled(!viewModel.canSend && !viewModel.isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            BPColorPalette.light.background
                .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
        )
    }
}
