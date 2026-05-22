import SwiftUI

/// Assistant/user message bubble. Each card renderer lives in its own file
/// under `Bubble/Cards/` — this struct only composes the layout and
/// dispatches parsed segments to the appropriate card view.
struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool
    var onSave: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onShareAsCard: (() -> Void)? = nil
    var onScriptureTap: ((String, Int, Int) -> Void)? = nil
    var onListen: (() -> Void)? = nil
    var isPlayingTTS: Bool = false
    var isFailedMessage: Bool = false
    var previousMessageRole: MessageRole? = nil
    var typingContextLabel: String? = nil
    var isFirstInAssistantSequence: Bool = true
    var isLastInAssistantSequence: Bool = true
    var appearDelay: Double = 0

    @Environment(\.bpPalette) private var palette
    @State private var appeared: Bool = false
    @State private var isSaved: Bool = false
    @State private var saveScale: CGFloat = 1.0

    private var isTypingPlaceholder: Bool {
        isStreaming && message.role == .assistant && message.content.isEmpty
    }

    private var isActivelyStreaming: Bool {
        isStreaming && message.role == .assistant && !message.content.isEmpty
    }

    private var shouldSkipFadeIn: Bool {
        isStreaming && message.role == .assistant
    }

    private var showRoleGap: Bool {
        guard let prev = previousMessageRole else { return false }
        return prev != message.role
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 56)
            } else if !isTypingPlaceholder {
                if isFirstInAssistantSequence {
                    aiIndicator
                } else {
                    Spacer().frame(width: 32)
                }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if isTypingPlaceholder {
                    TypingDotsView(contextLabel: typingContextLabel)
                        .transition(.opacity)
                } else if message.role == .user {
                    userContent
                } else {
                    assistantContent

                    if isLastInAssistantSequence && !isStreaming {
                        actionRow
                    }
                }
            }
            .animation(BPAnimation.spring, value: isTypingPlaceholder)

            if message.role == .assistant {
                Spacer(minLength: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, showRoleGap ? 14 : 2)
        .padding(.bottom, 2)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .contextMenu(message.role == .assistant && !isStreaming ? contextMenuItems : nil)
        .onAppear {
            if shouldSkipFadeIn || appeared {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82).delay(appearDelay)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - AI Indicator

    private var aiIndicator: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.08))
                .frame(width: 38, height: 38)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.18), palette.accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.84, blue: 0.3), palette.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(.top, 2)
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - User Message

    private var userContent: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.custom("Georgia", size: 17))
                .lineSpacing(4)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 6
                    )
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: palette.accent.opacity(0.25), radius: 10, y: 5)
                )
                .textSelection(.enabled)

            if isFailedMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Failed to send")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(palette.error)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Assistant Content
    //
    // Unified rendering path: always parse via the streaming-aware parser.
    // One render path means no view-tree swap when streaming finishes — all
    // segments keep identity, so cards never "snap" into place.

    private var assistantContent: some View {
        let segments = MessageParser.parseStreaming(message.content)

        return VStack(alignment: .leading, spacing: 14) {
            if segments.isEmpty && isActivelyStreaming {
                BlinkingCursor(color: palette.accent)
                    .padding(.leading, 2)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    segmentRow(
                        segment: segment,
                        isLast: index == segments.count - 1
                    )
                    .onAppear {
                        triggerSegmentHaptic(segment, index: index)
                    }
                }
            }
        }
        .animation(.spring(response: 0.95, dampingFraction: 0.86), value: segments.count)
    }

    @ViewBuilder
    private func segmentRow(segment: MessageParser.Segment, isLast: Bool) -> some View {
        let isText = isTextSegment(segment)
        let showCursor = isLast && isActivelyStreaming && isText
        VStack(alignment: .leading, spacing: 4) {
            segmentBody(segment)
            if showCursor {
                BlinkingCursor(color: palette.accent)
                    .padding(.leading, 2)
            }
        }
        .transition(isText ? AnyTransition.textSegmentReveal : AnyTransition.cardReveal)
    }

    private func isTextSegment(_ segment: MessageParser.Segment) -> Bool {
        if case .text = segment { return true }
        return false
    }

    @ViewBuilder
    private func segmentBody(_ segment: MessageParser.Segment) -> some View {
        switch segment {
        case .text(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                BubbleMarkdownText(text: text, onScriptureTap: onScriptureTap)
            }
        case .verseCard(let quote, let reference):
            VerseCard(quote: quote, reference: reference, onScriptureTap: onScriptureTap)
        case .prayerCard(let text):
            PrayerCard(text: text)
        case .reflectionCard(let question):
            ReflectionCard(question: question)
        case .actionCard(let label, let link, let description):
            ActionCard(label: label, link: link, description: description, onScriptureTap: onScriptureTap)
        case .scriptureCard(let quote, let reference, let imageKey):
            ScriptureCard(
                quote: quote,
                reference: reference,
                imageKey: imageKey,
                messageId: message.id,
                conversationId: message.resolvedConversationId,
                onScriptureTap: onScriptureTap
            )
        case .storyCard(let title, let summary, let imageKey):
            StoryCard(
                title: title,
                summary: summary,
                imageKey: imageKey,
                messageId: message.id,
                conversationId: message.resolvedConversationId
            )
        case .timelineCard(let events):
            TimelineCard(events: events)
        case .insightCard(let text):
            InsightCard(text: text)
        case .imageCard(let key, let caption):
            ImageCard(key: key, caption: caption)
        case .crossRefsCard(let refs):
            CrossRefsCard(refs: refs, onScriptureTap: onScriptureTap)
        case .toolResultCard(let name, let summary, let isError):
            ToolResultCard(name: name, summary: summary, isError: isError)
        case .quoteCard(let text, let attribution):
            QuoteCard(text: text, attribution: attribution)
        case .applyCard(let title, let items):
            ApplyCard(title: title, items: items)
        case .originalWordCard(let word, let language, let transliteration, let meaning):
            OriginalWordCard(
                word: word,
                language: language,
                transliteration: transliteration,
                meaning: meaning
            )
        }
    }

    private func triggerSegmentHaptic(_ segment: MessageParser.Segment, index: Int) {
        let delay = Double(index) * 0.12
        switch segment {
        case .crossRefsCard:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.lightImpact()
            }
        case .scriptureCard, .storyCard, .imageCard:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.impact(.medium)
            }
        case .toolResultCard:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.lightImpact()
            }
        case .prayerCard:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.success()
            }
        case .quoteCard, .originalWordCard:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.impact(.medium)
            }
        case .applyCard:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.success()
            }
        case .text:
            break
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HapticService.lightImpact()
            }
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 4) {
            if let onListen {
                listenButton(action: onListen)
            }

            if let onSave {
                saveActionButton(onSave: onSave)
            }

            if let onShare {
                actionButton(icon: "square.and.arrow.up", label: "Share") {
                    onShare()
                    HapticService.lightImpact()
                }
            }
        }
        .padding(.top, 6)
    }

    private func saveActionButton(onSave: @escaping () -> Void) -> some View {
        Button {
            if !isSaved {
                onSave()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isSaved = true
                    saveScale = 1.3
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7).delay(0.15)) {
                    saveScale = 1.0
                }
                HapticService.success()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 10, weight: .medium))
                Text(isSaved ? "Saved" : "Save")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isSaved ? palette.accent : palette.textMuted.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isSaved ? palette.accent.opacity(0.06) : palette.surface.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isSaved ? palette.accent.opacity(0.2) : palette.border.opacity(0.08), lineWidth: 0.5)
            )
            .scaleEffect(saveScale)
        }
        .buttonStyle(.plain)
    }

    private func listenButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticService.lightImpact()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isPlayingTTS ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10, weight: .medium))
                Text(isPlayingTTS ? "Stop" : "Listen")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isPlayingTTS ? palette.accent : palette.textMuted.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isPlayingTTS ? palette.accent.opacity(0.06) : palette.surface.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isPlayingTTS ? palette.accent.opacity(0.2) : palette.border.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionButton(icon: String, label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(palette.textMuted.opacity(disabled ? 0.3 : 0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(palette.surface.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(palette.border.opacity(0.08), lineWidth: 0.5)
            )
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }

    // MARK: - Context Menu

    private var contextMenuItems: ContextMenu<some View>? {
        ContextMenu {
            if let onSave {
                Button {
                    onSave()
                } label: {
                    Label("Save Response", systemImage: "bookmark")
                }
            }

            Button {
                UIPasteboard.general.string = message.content
                HapticService.success()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if let onShare {
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

            if let onShareAsCard {
                Button {
                    onShareAsCard()
                } label: {
                    Label("Share as Card", systemImage: "photo.artframe")
                }
            }
        }
    }
}
