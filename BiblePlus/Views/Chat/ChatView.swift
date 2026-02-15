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
    @State private var sendButtonScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Messages or quick prompts
            if viewModel.messages.isEmpty {
                QuickPromptsView(
                    prompts: viewModel.quickPrompts,
                    userName: viewModel.userName,
                    categories: PromptCategory.allCases,
                    selectedCategory: $viewModel.selectedPromptCategory,
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

            // Retry banner
            if viewModel.failedMessageContent != nil {
                retryBanner
            }

            // Rate limit indicator
            if !viewModel.profile.isPro && !viewModel.messages.isEmpty {
                rateLimitBanner
            }

            // Input bar
            inputBar
        }
        .background(palette.background)
        .overlay(alignment: .bottom) {
            // Saved to Journal toast
            if viewModel.showSavedToJournalToast {
                savedToJournalToast
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(BPAnimation.spring, value: viewModel.showSavedToJournalToast)
            }
        }
        .onAppear {
            viewModel.applyInitialContext()
        }
        .fullScreenCover(isPresented: $showPaywall) {
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
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        if message.role != .system {
                            let previousRole: MessageRole? = {
                                guard index > 0 else { return nil }
                                let prev = viewModel.messages[index - 1]
                                return prev.role == .system ? nil : prev.role
                            }()

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
                                },
                                onSavePrayerToJournal: viewModel.messageContainsPrayer(message) || viewModel.savedToJournalMessageIDs.contains(message.id) ? {
                                    viewModel.savePrayerToJournal(message)
                                } : nil,
                                isPrayerMessage: viewModel.messageContainsPrayer(message) || viewModel.savedToJournalMessageIDs.contains(message.id),
                                isSavedToJournal: viewModel.savedToJournalMessageIDs.contains(message.id),
                                isFailedMessage: message.role == .user && viewModel.failedMessageId == message.id,
                                previousMessageRole: previousRole
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
                ForEach(Array(viewModel.followUpSuggestions.enumerated()), id: \.element) { index, suggestion in
                    Button {
                        viewModel.sendQuickPrompt(suggestion)
                        HapticService.lightImpact()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: suggestionIcon(for: suggestion))
                                .font(.system(size: 11, weight: .semibold))
                            Text(suggestion)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [palette.accent.opacity(0.4), palette.accent.opacity(0.15)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .animation(BPAnimation.spring.delay(Double(index) * 0.05), value: viewModel.followUpSuggestions)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(BPAnimation.spring, value: viewModel.followUpSuggestions)
    }

    private func suggestionIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("verse") || lower.contains("scripture") || lower.contains("bible") || lower.contains("read") {
            return "book.fill"
        } else if lower.contains("pray") || lower.contains("prayer") {
            return "hands.sparkles"
        } else if lower.contains("explain") || lower.contains("mean") || lower.contains("understand") {
            return "lightbulb.fill"
        }
        return "arrow.right.circle.fill"
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

    // MARK: - Retry Banner

    private var retryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(palette.error)

            Text("Message failed to send")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.error)

            Spacer()

            Button {
                viewModel.retryLastMessage()
                HapticService.lightImpact()
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.error)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.error.opacity(0.08))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(BPAnimation.spring, value: viewModel.failedMessageContent != nil)
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
        VStack(spacing: 0) {
            // Subtle top divider
            Rectangle()
                .fill(palette.border.opacity(0.5))
                .frame(height: 0.5)

            HStack(spacing: 12) {
                TextField("Ask anything about Scripture...", text: $viewModel.inputText, axis: .vertical)
                    .font(BPFont.body)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
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
                        .font(.system(size: 34))
                        .foregroundStyle(
                            viewModel.canSend || viewModel.isStreaming
                                ? palette.accent
                                : palette.textMuted
                        )
                        .scaleEffect(sendButtonScale)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!viewModel.canSend && !viewModel.isStreaming)
                .onChange(of: viewModel.canSend) { _, canSend in
                    withAnimation(BPAnimation.buttonPress) {
                        sendButtonScale = canSend ? 1.1 : 1.0
                    }
                    // Reset after pop
                    if canSend {
                        withAnimation(BPAnimation.spring.delay(0.15)) {
                            sendButtonScale = 1.0
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Saved to Journal Toast

    private var savedToJournalToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("Saved to Journal")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.green)
                .shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
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
