import SwiftUI
import SwiftData

struct ChatView: View {
    let conversationId: UUID
    var initialContext: String? = nil
    /// When non-nil, the messages list scrolls to this specific message
    /// after load. Used by the Saved page to jump back to the original
    /// chat moment when a user taps a saved AI reply.
    var initialMessageId: UUID? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ChatContentView(viewModel: vm, initialMessageId: initialMessageId)
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
        .onDisappear {
            viewModel?.stopStreaming()
        }
        .navigationBarTitleDisplayMode(.inline)
        // Toolbar stays transparent so the chat gradient flows through
        // unbroken. Content bleed-through behind the toolbar buttons is
        // prevented by a top fade mask on the ScrollView itself (see
        // messageList) — content elegantly fades out as it scrolls past
        // the toolbar zone.
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
                        .overlay(
                            Capsule()
                                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
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
                        .overlay(
                            Capsule()
                                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
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
                            .overlay(
                                Circle()
                                    .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
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
    var initialMessageId: UUID? = nil

    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPaywall = false
    @State private var sendButtonScale: CGFloat = 1.0
    @State private var showGuidedPrayer = false
    @State private var shareAsCardMessage: ChatMessage?
    @State private var ttsService = ChatTTSService()
    @State private var scripturePreview: ScriptureReferenceTarget? = nil
    @State private var showVoiceChat = false
    /// Set to false once `initialMessageId` has been scrolled to, so the
    /// jump only fires on first appearance — subsequent re-renders (e.g.
    /// when the user starts streaming a new reply) don't yank the view
    /// back up to the saved message.
    @State private var pendingInitialJump = true

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
                    onGuidedPrayer: { showGuidedPrayer = true },
                    onRefresh: { viewModel.refreshPrompts() }
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

            // Rate limit indicator (hidden while streaming to reduce clutter)
            if !viewModel.profile.isPro && !viewModel.messages.isEmpty && !viewModel.isStreaming {
                rateLimitBanner
            }

            // Input bar
            inputBar
        }
        .background(topGoldGradient)
        .onAppear {
            viewModel.applyInitialContext()
        }
        .onDisappear {
            // Halt any in-progress speech read so it doesn't keep playing
            // after the user navigates back to the conversation list.
            ttsService.stop()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallContainerView()
        }
        .onChange(of: viewModel.shouldShowPaywall) { _, show in
            if show {
                showPaywall = true
                viewModel.shouldShowPaywall = false
            }
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
        .sheet(item: $scripturePreview) { target in
            ScripturePopoverSheet(
                target: target,
                onOpenInBible: {
                    viewModel.navigateToScripture(
                        bookName: target.bookName,
                        chapter: target.chapter,
                        verse: target.verse
                    )
                },
                onDiscuss: { prompt in
                    viewModel.sendQuickPrompt(prompt)
                }
            )
        }
        .fullScreenCover(isPresented: $showVoiceChat) {
            VoiceChatView(chatViewModel: viewModel)
        }
    }

    // MARK: - Top Gold Gradient

    private var topGoldGradient: some View {
        let tint = palette.accent
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
                            let isLast = message.role == .assistant
                                && nextRole != .assistant

                            let isStreamingMsg = viewModel.isStreaming
                                && message.id == viewModel.displayMessages.last?.id
                                && message.role == .assistant

                            bubbleView(
                                for: message,
                                isStreamingMsg: isStreamingMsg,
                                previousRole: previousRole,
                                isFirst: isFirst,
                                isLast: isLast
                            )
                            .id(message.id)
                        }
                    }

                    // Invisible anchor for scroll tracking
                    Color.clear.frame(height: 1).id("bottom-anchor")
                }
                .padding(.top, 70)   // clear the toolbar zone
                .padding(.bottom, 16)
            }
            .defaultScrollAnchor(.bottom)
            // Top fade mask: content elegantly fades to invisible as it
            // scrolls into the top 50pt of the ScrollView, so messages don't
            // visibly bleed through the transparent toolbar. The gradient
            // background still shows through unbroken — this only masks the
            // ScrollView's scroll content, not its background.
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                    Color.black
                }
                .ignoresSafeArea()
            )
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.displayMessages.count) { _, newCount in
                // First-load deep-link: if we have a target message, jump
                // there instead of bottom. After the first scroll, fall
                // back to the normal "follow the latest message" behavior.
                if pendingInitialJump,
                   let targetId = initialMessageId,
                   newCount > 0,
                   viewModel.displayMessages.contains(where: { $0.id == targetId }) {
                    pendingInitialJump = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                } else {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onAppear {
                // Cover the case where messages are already loaded (cached
                // ChatViewModel) and the count-change above never fires.
                guard pendingInitialJump,
                      let targetId = initialMessageId,
                      viewModel.displayMessages.contains(where: { $0.id == targetId })
                else { return }
                pendingInitialJump = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Bubble Builder
    //
    // Extracted from the ScrollView body so the SwiftUI type checker doesn't
    // have to infer the entire bubble construction inline. Adding new
    // ChatBubbleView parameters (e.g. onListen, isPlayingTTS) tipped the
    // inline expression past the inference budget; the helper keeps it cheap.

    @ViewBuilder
    private func bubbleView(
        for message: ChatMessage,
        isStreamingMsg: Bool,
        previousRole: MessageRole?,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        let onSave: (() -> Void)? = message.role == .assistant
            ? { viewModel.saveResponse(message) }
            : nil

        let onShare: (() -> Void)? = message.role == .assistant
            ? { viewModel.prepareShare(message) }
            : nil

        let onShareAsCard: (() -> Void)? = (message.role == .assistant && !isStreamingMsg)
            ? { shareAsCardMessage = message }
            : nil

        // Tapping a scripture reference (citation pill, cross-ref row, etc.)
        // now shows an in-conversation half-sheet preview instead of jumping
        // straight to the Bible reader. The popover has its own "Open in
        // Bible" CTA so users can still navigate explicitly when they want to.
        let onScriptureTap: ((String, Int, Int) -> Void) = { bookName, chapter, verse in
            scripturePreview = ScriptureReferenceTarget(
                bookName: bookName,
                chapter: chapter,
                verse: verse
            )
        }

        let onListen: (() -> Void)? = (message.role == .assistant && !isStreamingMsg)
            ? {
                // Chat narration is always the deep male "Solomon" voice
                // regardless of the Bible reader voice preference — a user
                // who picked a female voice for Scripture playback still
                // wants the AI companion to read with gravitas here.
                ttsService.play(messageId: message.id, content: message.content, voice: .onyx)
            }
            : nil

        let isPlayingTTS = ttsService.isPlaying(messageId: message.id)
        let isFailed = message.role == .user && viewModel.failedMessageId == message.id
        let typingLabel: String? = isStreamingMsg ? viewModel.typingContextLabel : nil

        ChatBubbleView(
            message: message,
            isStreaming: isStreamingMsg,
            onSave: onSave,
            onShare: onShare,
            onShareAsCard: onShareAsCard,
            onScriptureTap: onScriptureTap,
            onListen: onListen,
            isPlayingTTS: isPlayingTTS,
            isFailedMessage: isFailed,
            previousMessageRole: previousRole,
            typingContextLabel: typingLabel,
            isFirstInAssistantSequence: isFirst,
            isLastInAssistantSequence: isLast
        )
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

    // MARK: - Follow-Up Pills
    //
    // Compact horizontal-scrolling quick-reply pills. Replaces the previous
    // numbered editorial list which took ~200pt of vertical space and felt
    // like a major UI element. The new design is subtle: capsule pills with
    // small rounded text, scrollable horizontally, sit just above the input
    // bar like keyboard suggestions.

    private var followUpChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.followUpSuggestions.enumerated()), id: \.element) { _, suggestion in
                    Button {
                        viewModel.sendQuickPrompt(suggestion)
                        Analytics.track(.aiFollowUpTapped)
                        HapticService.lightImpact()
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.accent)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.08))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(palette.accent.opacity(0.18), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
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
            Text(rateLimitLabel)
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

    /// Free users see lifetime quota left ("3 free messages remaining"),
    /// pro users see today's count. Once the quota is exhausted the label
    /// flips to a more aggressive ask.
    private var rateLimitLabel: String {
        if viewModel.profile.isPro {
            return viewModel.remainingMessages > 0
                ? "\(viewModel.remainingMessages) messages remaining today"
                : "Daily cap reached"
        }
        if viewModel.remainingMessages > 0 {
            return "\(viewModel.remainingMessages) free messages remaining"
        }
        return "Free messages used — upgrade to keep going"
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Subtle top divider
            Rectangle()
                .fill(palette.border.opacity(0.3))
                .frame(height: 0.5)

            HStack(spacing: 12) {
                // Voice chat entry — opens a hands-free conversation surface.
                Button {
                    HapticService.lightImpact()
                    showVoiceChat = true
                } label: {
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(palette.accent.opacity(0.10))
                        )
                        .overlay(
                            Circle().stroke(palette.accent.opacity(0.18), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isStreaming)
                .opacity(viewModel.isStreaming ? 0.4 : 1.0)

                TextField("Ask anything about Scripture...", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
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
                        // Outer glow ring when active
                        if viewModel.canSend || viewModel.isStreaming {
                            Circle()
                                .fill(palette.accent.opacity(0.08))
                                .frame(width: 48, height: 48)
                        }

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
                                    ? palette.accent.opacity(0.25) : .clear,
                                radius: 6, y: 3
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
        // Dark mode keeps the system material (it reads warm there).
        // Light mode swaps to surfaceElevated — `.ultraThinMaterial` was
        // landing as a cool gray in light mode that fought the warm
        // tan/gold palette.
        .background(
            colorScheme == .dark
                ? AnyShapeStyle(.ultraThinMaterial)
                : AnyShapeStyle(palette.background)
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
