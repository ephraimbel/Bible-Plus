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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let vm = viewModel {
                    if let character = vm.conversationCharacter {
                        HStack(spacing: 5) {
                            Image(systemName: character.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(character.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(0.1))
                        )
                    } else if let mode = vm.conversationMode {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(mode.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(palette.accent.opacity(0.1))
                        )
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let vm = viewModel, !vm.messages.isEmpty {
                    Button {
                        vm.clearConversation()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(palette.surface)
                            )
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPaywall = false
    @State private var sendButtonScale: CGFloat = 1.0
    @State private var showGuidedPrayer = false
    @State private var shareAsCardMessage: ChatMessage?

    var body: some View {
        VStack(spacing: 0) {
            // Messages or quick prompts
            if viewModel.displayMessages.isEmpty {
                QuickPromptsView(
                    prompts: viewModel.quickPrompts,
                    userName: viewModel.userName,
                    categories: PromptCategory.allCases,
                    selectedCategory: $viewModel.selectedPromptCategory,
                    currentMode: viewModel.conversationMode,
                    onTap: { viewModel.sendQuickPrompt($0) },
                    onSelectMode: { viewModel.setConversationMode($0) },
                    onSelectCharacter: { viewModel.startCharacterConversation($0) },
                    onSelectEmotion: { viewModel.sendQuickPrompt($0.prompt) },
                    onGuidedPrayer: { showGuidedPrayer = true }
                )
            } else {
                messageList
            }

            // Follow-up suggestion chips
            if !viewModel.followUpSuggestions.isEmpty && !viewModel.isStreaming && !viewModel.isChunkTyping {
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
        .background(topGoldGradient)
        .overlay(alignment: .bottom) {
            // Saved to Journal toast
            if viewModel.showSavedPrayerToast {
                savedPrayerToast
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(BPAnimation.spring, value: viewModel.showSavedPrayerToast)
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
        .sheet(isPresented: $showGuidedPrayer) {
            GuidedPrayerSheet { prompt in
                viewModel.sendQuickPrompt(prompt)
            }
        }
        .sheet(item: $shareAsCardMessage) { message in
            ChatSharePreviewSheet(
                messageContent: message.content,
                background: SanctuaryBackground.background(for: viewModel.profile.selectedBackgroundID) ?? SanctuaryBackground.allBackgrounds[0]
            )
        }
    }

    // MARK: - Top Gold Gradient

    private var topGoldGradient: some View {
        let tint: Color = colorScheme == .dark
            ? palette.accent
            : Color(red: 0.65, green: 0.48, blue: 0.25)
        let strength: CGFloat = colorScheme == .dark ? 0.20 : 0.28
        let bg = palette.background

        return LinearGradient(
            stops: [
                .init(color: bg.blend(with: tint, amount: strength), location: 0.0),
                .init(color: bg.blend(with: tint, amount: strength * 0.9), location: 0.12),
                .init(color: bg.blend(with: tint, amount: strength * 0.7), location: 0.25),
                .init(color: bg.blend(with: tint, amount: strength * 0.45), location: 0.40),
                .init(color: bg.blend(with: tint, amount: strength * 0.15), location: 0.55),
                .init(color: bg, location: 0.65),
                .init(color: bg, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.displayMessages.enumerated()), id: \.element.id) { index, message in
                        if message.role != .system {
                            // Date divider
                            if let dividerLabel = viewModel.dateDividerLabel(for: message, at: index) {
                                dateDivider(label: dividerLabel)
                            }

                            let previousRole: MessageRole? = {
                                guard index > 0 else { return nil }
                                let prev = viewModel.displayMessages[index - 1]
                                return prev.role == .system ? nil : prev.role
                            }()

                            let nextRole: MessageRole? = {
                                guard index < viewModel.displayMessages.count - 1 else { return nil }
                                let next = viewModel.displayMessages[index + 1]
                                return next.role == .system ? nil : next.role
                            }()

                            let isFirst = message.role == .assistant && previousRole != .assistant
                            // During chunk typing, the last visible message isn't truly the "last" yet
                            let isLast = message.role == .assistant
                                && nextRole != .assistant
                                && !viewModel.isChunkTyping

                            let isStreamingMsg = viewModel.isStreaming
                                && message.id == viewModel.displayMessages.last?.id
                                && message.role == .assistant

                            ChatBubbleView(
                                message: message,
                                isStreaming: isStreamingMsg,
                                onSave: message.role == .assistant ? {
                                    viewModel.saveResponse(message)
                                } : nil,
                                onShare: message.role == .assistant ? {
                                    viewModel.prepareShare(message)
                                } : nil,
                                onShareAsCard: message.role == .assistant && !isStreamingMsg ? {
                                    shareAsCardMessage = message
                                } : nil,
                                onScriptureTap: { bookName, chapter, verse in
                                    viewModel.navigateToScripture(bookName: bookName, chapter: chapter, verse: verse)
                                },
                                onSavePrayer: viewModel.messageContainsPrayer(message) || viewModel.savedPrayerMessageIDs.contains(message.id) ? {
                                    viewModel.savePrayer(message)
                                } : nil,
                                isPrayerMessage: viewModel.messageContainsPrayer(message) || viewModel.savedPrayerMessageIDs.contains(message.id),
                                isSavedPrayer: viewModel.savedPrayerMessageIDs.contains(message.id),
                                isFailedMessage: message.role == .user && viewModel.failedMessageId == message.id,
                                previousMessageRole: previousRole,
                                typingContextLabel: isStreamingMsg ? viewModel.typingContextLabel : nil,
                                isFirstInAssistantSequence: isFirst,
                                isLastInAssistantSequence: isLast
                            )
                            .id(message.id)
                        }
                    }

                    // Chunk typing indicator
                    if viewModel.isChunkTyping {
                        chunkTypingIndicator
                            .id("chunk-typing")
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }

                    // Invisible anchor for scroll tracking
                    Color.clear.frame(height: 1).id("bottom-anchor")
                }
                .padding(.vertical, 16)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.displayMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isChunkTyping) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var chunkTypingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer()
                .frame(width: 26)

            TypingDotsView(contextLabel: viewModel.typingContextLabel)

            Spacer(minLength: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Date Divider

    private func dateDivider(label: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(palette.border.opacity(0.2))
                .frame(height: 0.5)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)
            Rectangle()
                .fill(palette.border.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
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
                        Text(suggestion)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.06))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(BPAnimation.spring.delay(Double(index) * 0.05), value: viewModel.followUpSuggestions)
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
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.error)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.error)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.error.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.error.opacity(0.08))
    }

    // MARK: - Retry Banner

    private var retryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(palette.error)

            Text("Message failed to send")
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textMuted)

            if viewModel.isRateLimited {
                Button {
                    showPaywall = true
                } label: {
                    Text("Go Pro")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.75)],
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
                .fill(palette.border.opacity(0.3))
                .frame(height: 0.5)

            HStack(spacing: 12) {
                TextField("Ask anything about Scripture...", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
                    )

                Button {
                    if viewModel.isStreaming {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.send()
                    }
                    HapticService.lightImpact()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                viewModel.canSend || viewModel.isStreaming
                                    ? LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [palette.surface, palette.surface],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 38, height: 38)
                            .shadow(
                                color: viewModel.canSend || viewModel.isStreaming
                                    ? palette.accent.opacity(0.2) : .clear,
                                radius: 4, y: 2
                            )

                        Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: viewModel.isStreaming ? 12 : 15, weight: .semibold))
                            .foregroundStyle(
                                viewModel.canSend || viewModel.isStreaming
                                    ? .white
                                    : palette.textMuted
                            )
                    }
                    .scaleEffect(sendButtonScale)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!viewModel.canSend && !viewModel.isStreaming)
                .onChange(of: viewModel.canSend) { _, canSend in
                    withAnimation(BPAnimation.buttonPress) {
                        sendButtonScale = canSend ? 1.1 : 1.0
                    }
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

    // MARK: - Saved Prayer Toast

    private var savedPrayerToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("Prayer Saved")
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
