import SwiftUI
import SwiftData

struct ChatView: View {
    let conversationId: UUID
    var initialContext: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ChatContentView(viewModel: vm)
            } else {
                BPLoadingView().onAppear {
                    viewModel = ChatViewModel(
                        modelContext: modelContext,
                        conversationId: conversationId,
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
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textMuted)
                    }
                    .accessibilityLabel("Delete conversation")
                }
            }
        }
    }
}

// MARK: - Inner Content View

private struct ChatContentView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.bpPalette) private var palette
    @State private var showPaywall = false

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

            // Follow-up suggestion chips
            if !viewModel.followUpSuggestions.isEmpty && !viewModel.isStreaming {
                followUpChips
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
        .background(palette.background)
        .onAppear {
            viewModel.applyInitialContext()
        }
        .sheet(isPresented: $showPaywall) {
            SummaryPaywallView()
        }
        .sheet(item: $viewModel.shareText) { text in
            ShareSheet(text: text)
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
                                    && message.role == .assistant,
                                onSave: message.role == .assistant ? {
                                    viewModel.saveResponse(message)
                                } : nil,
                                onShare: message.role == .assistant ? {
                                    viewModel.prepareShare(message)
                                } : nil,
                                onScriptureTap: { bookName, chapter in
                                    viewModel.navigateToScripture(bookName: bookName, chapter: chapter)
                                }
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Follow-Up Chips

    private var followUpChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.followUpSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.sendQuickPrompt(suggestion)
                        HapticService.lightImpact()
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(palette.accent.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(BPAnimation.spring, value: viewModel.followUpSuggestions)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(BPFont.caption)
            .foregroundStyle(palette.error)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(palette.error.opacity(0.1))
            .onTapGesture {
                viewModel.errorMessage = nil
            }
    }

    // MARK: - Rate Limit Banner

    private var rateLimitBanner: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.remainingMessages) messages remaining this week")
                .font(BPFont.caption)
                .foregroundStyle(palette.textMuted)

            if viewModel.isRateLimited {
                Button {
                    showPaywall = true
                } label: {
                    Text("Go Pro")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.79, green: 0.66, blue: 0.43),
                                        Color(red: 0.65, green: 0.52, blue: 0.3),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                }
            }
        }
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
                        .fill(palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(palette.border, lineWidth: 1)
                )

            Button {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    viewModel.send()
                }
                HapticService.lightImpact()
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.canSend || viewModel.isStreaming
                            ? palette.accent
                            : palette.textMuted
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!viewModel.canSend && !viewModel.isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            palette.background
                .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
        )
    }
}

// MARK: - Share Sheet (plain text)

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Make String identifiable for sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
