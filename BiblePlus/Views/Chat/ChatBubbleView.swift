import SwiftUI

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
                // AI indicator — only on first in sequence
                if isFirstInAssistantSequence {
                    aiIndicator
                } else {
                    Spacer()
                        .frame(width: 32)
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

                    // Actions on last in sequence
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
            // Outer glow
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

            // Sparkle icon
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
                .font(.custom("NewYorkLarge-Regular", size: 17, relativeTo: .body))
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

    private var assistantContent: some View {
        // Unified rendering path: always parse via the streaming-aware parser
        // (it produces identical output for completed messages and gracefully
        // hides in-progress openers mid-stream). Using ONE render path means
        // there's no view-tree swap when streaming finishes — all segments
        // keep their identity, so cards never "snap" into place.
        let segments = MessageParser.parseStreaming(message.content)

        return VStack(alignment: .leading, spacing: 14) {
            if segments.isEmpty && isActivelyStreaming {
                // Edge case: opener emitted but no visible content yet — show
                // the cursor so the user knows something is happening.
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
        // A single, slow, deliberate spring drives every segment insertion.
        // Cards reveal over ~1s with a blur+slide+fade so they feel like they
        // are *developing* into the conversation rather than snapping in.
        .animation(.spring(response: 0.95, dampingFraction: 0.86), value: segments.count)
    }

    /// One row in the assistant body. The wrapper view is the same for every
    /// segment kind, so SwiftUI keeps stable identity as the trailing text
    /// transitions from "growing tail" to "completed segment" — no remount,
    /// no flicker, just the cursor disappearing when it's no longer needed.
    @ViewBuilder
    private func segmentRow(segment: MessageParser.Segment, isLast: Bool) -> some View {
        let isText = bubbleSegmentIsText(segment)
        let showCursor = isLast && isActivelyStreaming && isText
        VStack(alignment: .leading, spacing: 4) {
            segmentBody(segment)
            if showCursor {
                BlinkingCursor(color: palette.accent)
                    .padding(.leading, 2)
            }
        }
        // Cards (story / scripture / prayer / reflection / image …) get a
        // dramatic slow reveal — blur clears, the card slides up, and it
        // fades in over ~1s. Text segments use a lighter fade so the live
        // word-by-word stream stays calm.
        .transition(isText ? AnyTransition.textSegmentReveal : AnyTransition.cardReveal)
    }

    /// Local mirror of `MessageParser.isTextSegment` (which is private) so the
    /// view can decide whether to anchor the cursor to a segment.
    private func bubbleSegmentIsText(_ segment: MessageParser.Segment) -> Bool {
        if case .text = segment { return true }
        return false
    }

    @ViewBuilder
    private func segmentBody(_ segment: MessageParser.Segment) -> some View {
        switch segment {
        case .text(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textView(text)
            }
        case .verseCard(let quote, let reference):
            verseCardView(quote: quote, reference: reference)
        case .prayerCard(let text):
            prayerCardView(text: text)
        case .reflectionCard(let question):
            reflectionCardView(question: question)
        case .actionCard(let label, let link, let description):
            actionCardView(label: label, link: link, description: description)
        case .scriptureCard(let quote, let reference, let imageKey):
            scriptureCardView(quote: quote, reference: reference, imageKey: imageKey)
        case .storyCard(let title, let summary, let imageKey):
            storyCardView(title: title, summary: summary, imageKey: imageKey)
        case .timelineCard(let events):
            timelineCardView(events: events)
        case .insightCard(let text):
            insightCardView(text: text)
        case .imageCard(let key, let caption):
            imageCardView(key: key, caption: caption)
        case .crossRefsCard(let refs):
            crossRefsCardView(refs: refs)
        case .toolResultCard(let name, let summary, let isError):
            toolResultCardView(name: name, summary: summary, isError: isError)
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
            actionButton(icon: "doc.on.doc", label: "Copy") {
                UIPasteboard.general.string = message.content
                HapticService.success()
            }

            if let onListen {
                listenButton(action: onListen)
            }

            if let onSave {
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

            if let onShare {
                actionButton(icon: "square.and.arrow.up", label: "Share") {
                    onShare()
                    HapticService.lightImpact()
                }
            }
        }
        .padding(.top, 6)
    }

    /// Listen action — toggles between Listen and Stop based on whether
    /// THIS bubble is currently being read aloud. Visual treatment matches
    /// the existing action chips so it doesn't introduce new chrome.
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

    // MARK: - Context Menu (replaces overflow + reaction bar)

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

    // MARK: - Text View

    @ViewBuilder
    private func textView(_ text: String) -> some View {
        let blocks = parseTextBlocks(text)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let title):
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(palette.accent.opacity(0.5))
                            .frame(width: 24, height: 1)
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.4)
                            .foregroundStyle(palette.accent.opacity(0.75))
                    }
                    .padding(.top, 6)
                case .paragraph(let body):
                    paragraphTextView(body)
                }
            }
        }
    }

    private func paragraphTextView(_ text: String) -> some View {
        highlightedMarkdownText(text)
            .font(.custom("NewYorkLarge-Regular", size: 17, relativeTo: .body))
            .lineSpacing(7)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "bibleplus",
                   url.host == "bible",
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let bookName = components.queryItems?.first(where: { $0.name == "book" })?.value,
                   let chapterStr = components.queryItems?.first(where: { $0.name == "ch" })?.value,
                   let chapter = Int(chapterStr) {
                    let verse = components.queryItems?.first(where: { $0.name == "v" }).flatMap { Int($0.value ?? "") } ?? 0
                    onScriptureTap?(bookName, chapter, verse)
                    HapticService.lightImpact()
                    return .handled
                }
                return .systemAction
            })
            .textSelection(.enabled)
    }

    // MARK: - Text Block Parsing

    private enum TextBlock {
        case heading(String)
        case paragraph(String)
    }

    private func parseTextBlocks(_ text: String) -> [TextBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [TextBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            let combined = paragraphLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                blocks.append(.paragraph(combined))
            }
            paragraphLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                flushParagraph()
                let title = String(trimmed.dropFirst(3)).uppercased()
                blocks.append(.heading(title))
            } else if trimmed.hasPrefix("# ") {
                flushParagraph()
                let title = String(trimmed.dropFirst(2)).uppercased()
                blocks.append(.heading(title))
            } else {
                paragraphLines.append(line)
            }
        }
        flushParagraph()

        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }

    // MARK: - Verse Card

    private func verseCardView(quote: String, reference: String) -> some View {
        ZStack(alignment: .topLeading) {
            // Decorative opening quotation mark
            Text("\u{201C}")
                .font(.system(size: 44, weight: .bold, design: .serif))
                .foregroundStyle(palette.accent.opacity(0.12))
                .offset(x: 8, y: -2)

            VStack(alignment: .leading, spacing: 10) {
                Text(quote)
                    .font(.custom("NewYorkLarge-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(6)
                    .italic()

                if !reference.isEmpty {
                    referenceButton(reference)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                }
            }
            .padding(16)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.07), palette.accent.opacity(0.02), palette.accent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: palette.accent.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
    }

    // MARK: - Prayer Card

    private func prayerCardView(text: String) -> some View {
        PrayerCardContent(text: text, palette: palette)
            .padding(.vertical, 4)
    }

    // MARK: - Reflection Card

    private func reflectionCardView(question: String) -> some View {
        ReflectionCardContent(question: question, palette: palette)
            .padding(.vertical, 4)
    }

    // MARK: - Action Card

    private func actionCardView(label: String, link: String, description: String) -> some View {
        Button {
            handleActionLink(link)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                    }
                    Text(label)
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: - Scripture Card (Illustrated Verse)

    /// Shared image rendering for scripture and story cards. The image
    /// fills the top of the card and fades seamlessly into the surface
    /// color via a tall, multi-stop gradient so there's no visible seam.
    private func scriptureArtImage(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            // Bottom fade — overlay the card's surface color so the image
            // blends seamlessly into the text section below (same approach
            // as the Home dashboard verse card).
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .clear,
                        palette.surfaceElevated.opacity(0.4),
                        palette.surfaceElevated.opacity(0.8),
                        palette.surfaceElevated
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
                .allowsHitTesting(false)
            }
    }

    private func scriptureCardView(quote: String, reference: String, imageKey: String?) -> some View {
        // Resolve the AI-supplied key (or nothing) against verse text + reference,
        // scoped to this message + conversation so each scripture card in a
        // session rotates through a different artwork.
        let context = "\(quote) \(reference)"
        let resolvedKey: String? = BiblicalImageService.resolveKey(
            for: imageKey ?? "",
            context: context,
            messageId: message.id,
            conversationId: message.resolvedConversationId
        )

        return VStack(spacing: 0) {
            // CINEMATIC IMAGE — full bleed, with bottom seamlessly fading
            // into the verse text section's surface color so there's no
            // visible seam where the image meets the prose.
            if let key = resolvedKey, let uiImage = BiblicalImageService.rawImage(for: key) {
                scriptureArtImage(Image(uiImage: uiImage))
            } else if let defaultImage = BiblicalImageService.defaultImage(for: resolvedKey ?? imageKey ?? quote) {
                scriptureArtImage(Image(uiImage: defaultImage))
            } else {
                // Last-resort fallback if the asset catalog is somehow empty
                // (shouldn't happen in a real build). Warm wash, not the
                // colored hue rotation.
                BiblicalImageService.fallbackGradient(for: resolvedKey ?? imageKey ?? "default")
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }

            // EDITORIAL TEXT BLOCK — generous, magazine-style
            VStack(alignment: .leading, spacing: 18) {
                // Tiny editorial label
                Text("FROM SCRIPTURE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(palette.accent.opacity(0.7))

                // The verse — large, breathing serif
                Text(quote)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(9)
                    .fixedSize(horizontal: false, vertical: true)

                // Reference — understated
                if !reference.isEmpty {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(palette.accent.opacity(0.4))
                            .frame(width: 18, height: 1)
                        referenceButton(reference)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                    }
                }

                // Artist credit — fine print. Picks the entry whose artwork
                // actually rendered: if the resolved key had a binary, use
                // its catalog entry; otherwise the defaultImage path is in
                // play and we use the matching default entry.
                if let key = resolvedKey {
                    let renderedEntry: ImageEntry? = {
                        if BiblicalImageService.rawImage(for: key) != nil {
                            return BiblicalImageService.entry(for: key)
                        }
                        return BiblicalImageService.defaultEntry(for: key)
                    }()
                    if let entry = renderedEntry {
                        Text(entry.artist.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(palette.textMuted.opacity(0.5))
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfaceElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        .padding(.vertical, 6)
    }

    // MARK: - Story Card

    private func storyCardView(title: String, summary: String, imageKey: String?) -> some View {
        // Resolve key against title + summary, scoped to this message +
        // conversation so each story card in a session rotates through a
        // different artwork.
        let context = "\(title) \(summary)"
        let resolvedKey = BiblicalImageService.resolveKey(
            for: imageKey ?? "",
            context: context,
            messageId: message.id,
            conversationId: message.resolvedConversationId
        )

        // Resolve a real bundled artwork — falls back to defaultImage if the
        // resolver-returned key has no binary, so we always show real art.
        let renderedImage: UIImage? = BiblicalImageService.rawImage(for: resolvedKey)
            ?? BiblicalImageService.defaultImage(for: resolvedKey)

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let uiImage = renderedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.5),
                                    Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.92),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.1)
                        )
                } else {
                    BiblicalImageService.fallbackGradient(for: resolvedKey)
                        .frame(height: 120)
                }

                // Title overlay — editorial typography
                VStack(alignment: .leading, spacing: 6) {
                    Text("A STORY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.4)
                        .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.45).opacity(0.9))

                    Text(title)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)

            // Summary text with drop cap
            storyDropCapText(summary)
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func storyDropCapText(_ text: String) -> some View {
        if text.count > 1 {
            let first = String(text.prefix(1))
            let rest = String(text.dropFirst())
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(first)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(palette.accent)
                    .baselineOffset(-2)
                Text(rest)
                    .font(.system(size: 14.5, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(4)
            }
        } else {
            Text(text)
                .font(.system(size: 14.5, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(4)
        }
    }

    // MARK: - Timeline Card

    private func timelineCardView(events: [(label: String, reference: String, period: String)]) -> some View {
        TimelineCardContent(events: events, palette: palette)
            .padding(.vertical, 4)
    }

    // MARK: - Insight Card

    // MARK: - Image Card (inline scene-setter)

    private func imageCardView(key: String, caption: String) -> some View {
        // Resolve the AI-supplied key against the caption so unknown keys still
        // produce thematically relevant artwork.
        let resolvedKey = BiblicalImageService.resolveKey(for: key, context: caption)
        let renderedImage: UIImage? = BiblicalImageService.rawImage(for: resolvedKey)
            ?? BiblicalImageService.defaultImage(for: resolvedKey)

        return VStack(spacing: 0) {
            if let uiImage = renderedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        // Subtle warm tint
                        Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.06)
                    )
            } else {
                BiblicalImageService.fallbackGradient(for: resolvedKey)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }

            // Magazine-style caption — leading accent rule sized via overlay
            // so the caption box is exactly the height of its text. The
            // previous `frame(maxHeight: .infinity)` rule was making the
            // caption box stretch to fill its container, producing tall
            // empty cards.
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textMuted.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.trailing, 18)
                    .padding(.vertical, 14)
                    .background(palette.surfaceElevated.opacity(0.35))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(palette.accent.opacity(0.5))
                            .frame(width: 2)
                            .padding(.vertical, 14)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        .padding(.vertical, 6)
    }

    // MARK: - Cross-References Card

    /// OpenEvidence-style citations footer: a clean panel of 2-4 parallel verses,
    /// each row tappable to open the Bible reader at that reference.
    private func crossRefsCardView(refs: [(reference: String, quote: String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Editorial label
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.accent.opacity(0.75))
                Text("CROSS-REFERENCES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(palette.accent.opacity(0.75))
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                ForEach(Array(refs.enumerated()), id: \.offset) { idx, ref in
                    crossRefRow(reference: ref.reference, quote: ref.quote)
                    if idx < refs.count - 1 {
                        Divider()
                            .background(palette.border.opacity(0.4))
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
            )
        }
        .padding(.vertical, 6)
    }

    private func crossRefRow(reference: String, quote: String) -> some View {
        Button {
            if let (bookName, chapter, verse) = ScriptureParser.parseReference(reference) {
                onScriptureTap?(bookName, chapter, verse)
                HapticService.lightImpact()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Numbered citation marker
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(palette.accent.opacity(0.10))
                    )
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reference)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.accent)

                    Text(quote)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textPrimary.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Tool result card — a small inline note like "Looked up Romans 8:28 in
    /// your KJV Bible" that shows where the agent ran a tool. Editorial styling
    /// (small caps + serif) so it reads as part of the message, not as chrome.
    ///
    /// Layout note: the leading accent rule is rendered as an OVERLAY of the
    /// text content so it sizes naturally to the text's height. A previous
    /// implementation used `Rectangle().frame(maxHeight: .infinity)` inside an
    /// HStack which caused the card to stretch and consume all available
    /// vertical space, producing a giant gap before the next segment.
    private func toolResultCardView(name: String, summary: String, isError: Bool) -> some View {
        let accent: Color = isError ? palette.error : palette.accent

        return VStack(alignment: .leading, spacing: 4) {
            Text(isError ? "AGENT ERROR" : "AGENT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(accent.opacity(0.7))

            Text(summary)
                .font(.system(size: 13.5, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.leading, 18)
        .padding(.trailing, 0)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            // Hairline accent rule + small leading dot. Sized via overlay so
            // its height matches the text content naturally — never stretches.
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, 8)
                Circle()
                    .fill(accent.opacity(0.9))
                    .frame(width: 5, height: 5)
                    .offset(x: -2, y: 8)
            }
            .frame(width: 5)
        }
    }

    private func insightCardView(text: String) -> some View {
        VStack(spacing: 18) {
            // Top hairline
            Rectangle()
                .fill(palette.accent.opacity(0.4))
                .frame(width: 32, height: 1)

            Text("KEY INSIGHT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(text)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)

            // Bottom hairline
            Rectangle()
                .fill(palette.accent.opacity(0.4))
                .frame(width: 32, height: 1)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.vertical, 6)
    }

    private func handleActionLink(_ link: String) {
        HapticService.lightImpact()
        if link.hasPrefix("bible://") {
            let parts = link.replacingOccurrences(of: "bible://", with: "").replacingOccurrences(of: "+", with: " ")
            let components = parts.components(separatedBy: " ")
            // Try to parse as "Book Chapter" e.g. "Psalm 23"
            if components.count >= 2, let chapter = Int(components.last ?? "") {
                let bookName = components.dropLast().joined(separator: " ")
                onScriptureTap?(bookName, chapter, 0)
            }
        } else if link.hasPrefix("sanctuary://") {
            NotificationCenter.default.post(name: .init("openSanctuary"), object: nil)
        } else if link.hasPrefix("plan://") {
            NotificationCenter.default.post(name: .init("openPlans"), object: nil)
        }
    }

    // MARK: - Tappable Reference

    private func referenceButton(_ reference: String) -> some View {
        Group {
            if let (bookName, chapter, verse) = ScriptureParser.parseReference(reference) {
                Button {
                    onScriptureTap?(bookName, chapter, verse)
                    HapticService.lightImpact()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text(reference)
                    }
                    .foregroundStyle(palette.accent)
                }
            } else {
                Text(reference)
                    .foregroundStyle(palette.accent)
            }
        }
    }

    // MARK: - Markdown + Scripture Highlighting

    private func highlightedMarkdownText(_ content: String) -> Text {
        var attributed: AttributedString
        do {
            attributed = try AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            attributed = AttributedString(content)
        }

        attributed.foregroundColor = palette.textPrimary

        let plainText = String(attributed.characters)
        let highlights = scriptureRanges(in: plainText)

        for highlight in highlights {
            let startOffset = plainText.distance(from: plainText.startIndex, to: highlight.lowerBound)
            let endOffset = plainText.distance(from: plainText.startIndex, to: highlight.upperBound)
            let attrStart = attributed.characters.index(attributed.startIndex, offsetBy: startOffset)
            let attrEnd = attributed.characters.index(attributed.startIndex, offsetBy: endOffset)

            let segment = String(plainText[highlight])

            if let (bookName, chapter, verse) = ScriptureParser.parseReference(segment),
               let encoded = bookName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "bibleplus://bible?book=\(encoded)&ch=\(chapter)&v=\(verse)") {
                // OpenEvidence-style citation pill: subtle tinted background, accent text,
                // medium weight, and tap target via the existing link.
                attributed[attrStart..<attrEnd].link = url
                attributed[attrStart..<attrEnd].foregroundColor = palette.accent
                attributed[attrStart..<attrEnd].backgroundColor = palette.accent.opacity(0.10)
                attributed[attrStart..<attrEnd].font = .system(size: 15.5, weight: .semibold, design: .rounded)
                attributed[attrStart..<attrEnd].underlineStyle = nil
            } else {
                // Quoted Scripture string — italic accent, no background pill
                attributed[attrStart..<attrEnd].foregroundColor = palette.accent
                attributed[attrStart..<attrEnd].font = .system(size: 16, weight: .regular, design: .serif).italic()
            }
        }

        return Text(attributed)
    }

    // MARK: - Scripture Range Detection

    private func scriptureRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let nsString = text as NSString
        let full = NSRange(location: 0, length: nsString.length)

        let quotePatterns = [
            #"\"[^\"]{4,}\""#,
            #"\u201C[^\u201D]{4,}\u201D"#
        ]

        let refPattern = #"(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?(?:,\s*\d{1,3}(?:\s*[-–]\s*\d{1,3})?)*"#

        for pattern in quotePatterns + [refPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: full) {
                if let range = Range(match.range, in: text) {
                    ranges.append(range)
                }
            }
        }

        ranges.sort { $0.lowerBound < $1.lowerBound }
        return mergeRanges(ranges)
    }

    private func mergeRanges(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        guard var current = ranges.first else { return [] }
        var merged: [Range<String.Index>] = []
        for range in ranges.dropFirst() {
            if range.lowerBound <= current.upperBound {
                current = current.lowerBound..<max(current.upperBound, range.upperBound)
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)
        return merged
    }
}

// MARK: - Blinking Cursor

// MARK: - Prayer Card with Amen Button

private struct PrayerCardContent: View {
    let text: String
    let palette: BPColorPalette

    @State private var amenTapped = false
    @State private var amenGlow = false
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Editorial label — pure typography
            Text("A PRAYER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(text)
                .font(.system(size: 15.5, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(5)
                .italic()

            // Amen button
            if !amenTapped {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        amenTapped = true
                    }
                    // Trigger shimmer sweep
                    shimmerOffset = -200
                    withAnimation(.easeInOut(duration: 0.6)) {
                        shimmerOffset = 400
                    }
                    HapticService.success()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hands.clap.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("Amen")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: palette.accent.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                // After tap: confirmed state with gentle glow
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Amen")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                }
                .foregroundStyle(palette.accent.opacity(0.6))
                .shadow(color: palette.accent.opacity(amenGlow ? 0.4 : 0), radius: 8)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.6)) {
                        amenGlow = true
                    }
                    withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                        amenGlow = false
                    }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.08),
                            Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.03),
                            palette.surfaceElevated.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: palette.accent.opacity(0.08), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
        )
        // Golden shimmer sweep on Amen tap
        .overlay(
            LinearGradient(
                colors: [.clear, palette.accent.opacity(0.15), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120)
            .offset(x: shimmerOffset)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }
}

// MARK: - Reflection Card with Pulsing Bar

private struct ReflectionCardContent: View {
    let question: String
    let palette: BPColorPalette

    @State private var barGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FOR REFLECTION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))

            Text(question)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(6)
                .italic()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.4))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(palette.accent.opacity(barGlow ? 0.35 : 0.2))
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                barGlow = true
            }
        }
    }
}

// MARK: - Timeline Card with Animated Line

private struct TimelineCardContent: View {
    let events: [(label: String, reference: String, period: String)]
    let palette: BPColorPalette

    @State private var lineDrawn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — editorial typography
            Text("A TIMELINE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 14)

            // Events
            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                let progress = events.count > 1 ? Double(index) / Double(events.count - 1) : 0
                let dotColor = Color(
                    red: 0.79 - progress * 0.15,
                    green: 0.66 - progress * 0.15,
                    blue: 0.43 - progress * 0.1
                )

                HStack(alignment: .top, spacing: 12) {
                    // Timeline line + gradient dot
                    VStack(spacing: 0) {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(dotColor.opacity(0.2))
                                    .frame(width: 16, height: 16)
                            )

                        if index < events.count - 1 {
                            Rectangle()
                                .fill(palette.accent.opacity(0.2))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                                .scaleEffect(y: lineDrawn ? 1 : 0, anchor: .top)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.15),
                                    value: lineDrawn
                                )
                        }
                    }
                    .frame(width: 16)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.label)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(palette.textPrimary)

                        HStack(spacing: 8) {
                            if !event.reference.isEmpty {
                                Text(event.reference)
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundStyle(palette.accent)
                            }
                            if !event.period.isEmpty {
                                Text(event.period)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(palette.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(palette.accent.opacity(0.06))
                                    )
                            }
                        }
                    }
                    .padding(.bottom, index < events.count - 1 ? 16 : 0)
                }
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                lineDrawn = true
            }
        }
    }
}

private struct BlinkingCursor: View {
    let color: Color
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Message Parser

enum MessageParser {
    enum Segment {
        case text(String)
        case verseCard(quote: String, reference: String)
        case prayerCard(text: String)
        case reflectionCard(question: String)
        case actionCard(label: String, link: String, description: String)
        // Phase 1: Rich visual cards
        case scriptureCard(quote: String, reference: String, imageKey: String?)
        case storyCard(title: String, summary: String, imageKey: String?)
        case timelineCard(events: [(label: String, reference: String, period: String)])
        case insightCard(text: String)
        case imageCard(key: String, caption: String)
        case crossRefsCard(refs: [(reference: String, quote: String)])
        // Phase 2A: Agent tool result card
        case toolResultCard(name: String, summary: String, isError: Bool)
    }

    // MARK: - Cache (prevents re-parsing on every SwiftUI body evaluation)

    private static var cache: [String: [Segment]] = [:]
    private static let cacheLimit = 50

    static func parseCached(_ content: String) -> [Segment] {
        if let cached = cache[content] { return cached }
        let result = parse(content)
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[content] = result
        return result
    }

    /// Streaming-aware parse. Designed to be called repeatedly on a growing
    /// content buffer so completed cards render immediately while in-progress
    /// content stays as plain text. Specifically:
    ///   1. Strips the trailing `|||...` follow-ups marker if it appears.
    ///   2. Extracts every CLOSED `[TAG]...[/TAG]` block as its proper card.
    ///   3. Hides any unclosed `[TAG` opener from the trailing text so users
    ///      never see raw markup mid-stream.
    /// NOT cached — content changes every word during streaming, so caching
    /// would just thrash. The parse cost is small (few hundred bytes per call).
    static func parseStreaming(_ content: String) -> [Segment] {
        // 1. Strip the |||suggestion||| trailing block if the model has started
        //    emitting it. The follow-ups are post-processed elsewhere.
        var working = content
        if let pipeRange = working.range(of: "|||") {
            working = String(working[..<pipeRange.lowerBound])
        }

        // 2. Parse closed tag blocks (same logic as parseWithTags). Anything
        //    that's still unclosed remains in the trailing text segment.
        var segments = parseWithTags(working)

        // 3. Clean the final text segment of any in-progress opener. parseWithTags
        //    has already extracted closed blocks, so any `[TAG` remaining in
        //    the tail is by definition unclosed.
        if let lastIndex = segments.indices.last,
           case .text(let tailText) = segments[lastIndex] {
            let cleaned = stripUnclosedOpener(tailText)
            // Also strip stray full-tag noise that the regex didn't catch.
            let final = stripStrayTags(cleaned)
            if final.isEmpty {
                segments.removeLast()
            } else {
                segments[lastIndex] = .text(final)
            }
        }

        return segments
    }

    /// Known tag names (matched by `parseWithTags` regex).
    private static let knownTagNames = [
        "VERSE", "PRAYER", "REFLECT", "ACTION",
        "SCRIPTURE", "STORY", "TIMELINE", "INSIGHT", "IMAGE", "CROSSREFS",
        "TOOLRESULT"
    ]

    /// Removes everything from the first unclosed `[TAG` to end of string.
    /// Used to hide partially-streamed openers like `[SCRIPTURE img="cal` from
    /// the user during live streaming.
    private static func stripUnclosedOpener(_ text: String) -> String {
        let nsText = text as NSString
        var earliestPos = NSNotFound
        for tag in knownTagNames {
            let opener = "[\(tag)"
            let range = nsText.range(of: opener)
            if range.location != NSNotFound,
               (earliestPos == NSNotFound || range.location < earliestPos) {
                earliestPos = range.location
            }
        }
        if earliestPos != NSNotFound {
            return nsText.substring(to: earliestPos)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    // MARK: - Tag-Based Parsing (Primary)

    /// Matches [TAG]...[/TAG] or [TAG attr="val"]...[/TAG]
    private static let tagPattern = #"\[(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT)(?:\s+[^\]]*?)?\](.*?)\[/\1\]"#

    /// Extracts attribute values from tag opening, e.g. label="Read Psalm 23" link="bible://Psalm+23"
    private static func extractAttribute(_ name: String, from tag: String) -> String {
        let pattern = name + #"="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              let range = Range(match.range(at: 1), in: tag)
        else { return "" }
        return String(tag[range])
    }

    /// Strips stray [TAG] or [/TAG] markers from a text string
    private static let strayTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\[/?(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT)(?:\s+[^\]]*)?\]"#)
    }()

    private static func stripStrayTags(_ text: String) -> String {
        guard let regex = strayTagRegex else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ content: String) -> [Segment] {
        // First try tag-based parsing
        let tagSegments = parseWithTags(content)
        if tagSegments.contains(where: { !isTextSegment($0) }) {
            // Clean any stray tags from text segments only
            return tagSegments.compactMap { segment in
                if case .text(let text) = segment {
                    let cleaned = stripStrayTags(text)
                    return cleaned.isEmpty ? nil : .text(cleaned)
                }
                return segment
            }
        }

        // Fall back to legacy verse detection for older/untagged responses
        return parseLegacy(content)
    }

    private static func isTextSegment(_ segment: Segment) -> Bool {
        if case .text = segment { return true }
        return false
    }

    // MARK: - Tag Parsing

    private static func parseWithTags(_ content: String) -> [Segment] {
        // Match full tag blocks including attributes
        let fullTagPattern = #"\[(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT)(\s+[^\]]*)?\](.*?)\[/\1\]"#
        guard let regex = try? NSRegularExpression(pattern: fullTagPattern, options: .dotMatchesLineSeparators) else {
            return [.text(content)]
        }

        let nsString = content as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: content, range: fullRange)

        if matches.isEmpty {
            return [.text(content)]
        }

        var segments: [Segment] = []
        var cursor = content.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: content),
                  let tagRange = Range(match.range(at: 1), in: content),
                  let bodyRange = Range(match.range(at: 3), in: content)
            else { continue }

            // Text before this tag
            if cursor < matchRange.lowerBound {
                let text = String(content[cursor..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    segments.append(.text(text))
                }
            }

            let tag = String(content[tagRange])
            let body = String(content[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Get attributes string if present
            let attrs: String
            if match.range(at: 2).location != NSNotFound, let attrRange = Range(match.range(at: 2), in: content) {
                attrs = String(content[attrRange])
            } else {
                attrs = ""
            }

            // Helper: trimmed body for empty checks. Anything that comes back
            // empty after trimming whitespace counts as a hollow card and is
            // dropped — we'd rather drop a card than render an empty box.
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

            switch tag {
            case "VERSE":
                let parsed = parseVerseBody(body)
                let quote = parsed.quote.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !quote.isEmpty else { break }
                segments.append(.verseCard(quote: quote, reference: parsed.reference))
            case "PRAYER":
                guard !trimmedBody.isEmpty else { break }
                segments.append(.prayerCard(text: trimmedBody))
            case "REFLECT":
                guard !trimmedBody.isEmpty else { break }
                segments.append(.reflectionCard(question: trimmedBody))
            case "ACTION":
                let label = extractAttribute("label", from: attrs)
                let link = extractAttribute("link", from: attrs)
                // An action card with neither a label nor a link is meaningless.
                guard !link.isEmpty || !label.isEmpty else { break }
                segments.append(.actionCard(
                    label: label.isEmpty ? "Open" : label,
                    link: link,
                    description: trimmedBody
                ))
            case "SCRIPTURE":
                let imgKey = extractAttribute("img", from: attrs)
                let parsed = parseVerseBody(body)
                let quote = parsed.quote.trimmingCharacters(in: .whitespacesAndNewlines)
                // A scripture card without a verse text is just a picture
                // with chrome — drop it.
                guard !quote.isEmpty else { break }
                segments.append(.scriptureCard(
                    quote: quote,
                    reference: parsed.reference,
                    imageKey: imgKey.isEmpty ? nil : imgKey
                ))
            case "STORY":
                let title = extractAttribute("title", from: attrs)
                let imgKey = extractAttribute("img", from: attrs)
                // Need at least a title OR a summary — both empty means the
                // model emitted a hollow [STORY][/STORY] block. Drop it.
                guard !trimmedBody.isEmpty || !title.isEmpty else { break }
                segments.append(.storyCard(
                    title: title.isEmpty ? "Biblical Story" : title,
                    summary: trimmedBody,
                    imageKey: imgKey.isEmpty ? nil : imgKey
                ))
            case "TIMELINE":
                let events = parseTimelineBody(body)
                guard !events.isEmpty else { break }
                segments.append(.timelineCard(events: events))
            case "INSIGHT":
                guard !trimmedBody.isEmpty else { break }
                segments.append(.insightCard(text: trimmedBody))
            case "IMAGE":
                let key = extractAttribute("key", from: attrs)
                // Image cards need a key. The caption is optional — a
                // captionless image is still a valid scene-setter — but a
                // keyless image card is meaningless.
                guard !key.isEmpty else { break }
                segments.append(.imageCard(key: key, caption: trimmedBody))
            case "CROSSREFS":
                let refs = parseCrossRefsBody(body)
                guard !refs.isEmpty else { break }
                segments.append(.crossRefsCard(refs: refs))
            case "TOOLRESULT":
                // Persisted record of a tool the agent ran during this turn.
                // Format: [TOOLRESULT name="lookup_verse" status="ok"]Looked up Romans 8:28[/TOOLRESULT]
                let name = extractAttribute("name", from: attrs)
                let status = extractAttribute("status", from: attrs)
                guard !trimmedBody.isEmpty else { break }
                segments.append(.toolResultCard(
                    name: name,
                    summary: trimmedBody,
                    isError: status == "error"
                ))
            default:
                if !trimmedBody.isEmpty {
                    segments.append(.text(trimmedBody))
                }
            }

            cursor = matchRange.upperBound
        }

        // Remaining text after last tag
        if cursor < content.endIndex {
            let text = String(content[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(.text(text))
            }
        }

        return segments
    }

    /// Parses crossrefs body: each line is "Reference || Quote text"
    /// Returns up to 4 entries; tolerates a single | separator as fallback.
    private static func parseCrossRefsBody(_ body: String) -> [(reference: String, quote: String)] {
        body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line -> (reference: String, quote: String)? in
                let separator: String
                if line.contains("||") { separator = "||" }
                else if line.contains("|") { separator = "|" }
                else { return nil }
                let parts = line.components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard parts.count >= 2 else { return nil }
                let reference = parts[0]
                let quote = parts.dropFirst().joined(separator: " ")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
                return (reference, quote)
            }
            .prefix(4)
            .map { $0 }
    }

    /// Parses timeline body: each line is "Event | Reference | ~Period"
    private static func parseTimelineBody(_ body: String) -> [(label: String, reference: String, period: String)] {
        body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard parts.count >= 2 else { return nil }
                return (
                    label: parts[0],
                    reference: parts[1],
                    period: parts.count >= 3 ? parts[2] : ""
                )
            }
    }

    /// Parses verse body: "Quote text" — Reference or "Quote text" (Reference)
    private static func parseVerseBody(_ body: String) -> (quote: String, reference: String) {
        // Try: "quote" — Reference or "quote" (Reference)
        let patterns = [
            #"(?:"|"|\")(.*?)(?:"|"|\")\s*[-–—(]\s*(.*?)\)?\s*$"#,
            #"^(.*?)\s*[-–—]\s*(\S.*)$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: body, range: NSRange(location: 0, length: (body as NSString).length)),
               let quoteRange = Range(match.range(at: 1), in: body),
               let refRange = Range(match.range(at: 2), in: body) {
                let quote = String(body[quoteRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let reference = String(body[refRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^\*{1,2}|\*{1,2}$"#, with: "", options: .regularExpression)
                if !quote.isEmpty && !reference.isEmpty {
                    return (quote, reference)
                }
            }
        }
        // Fallback: entire body as quote, no reference
        return (body, "")
    }

    // MARK: - Legacy Parsing (Backward Compatibility)

    /// Reference pattern shared across verse detection regexes.
    private static let refPattern = #"(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?(?:,\s*\d{1,3}(?:\s*[-–]\s*\d{1,3})?)*"#

    /// Quote patterns (straight or curly quotes, min 20 chars).
    private static let quoteGroup = #"(?:\"([^\"]{20,})\"|(?:\u201C)([^\u201D]{20,})(?:\u201D))"#

    private static func parseLegacy(_ content: String) -> [Segment] {
        let quoteFirstPattern = quoteGroup + #"\s*[-–—(]\s*\*{0,2}("# + refPattern + #")\*{0,2}\)?"#
        let refFirstPattern = #"\*{0,2}("# + refPattern + #")\*{0,2}\s+(?:says|writes|reads|tells\s+us)[,:]\s*"# + quoteGroup

        let nsString = content as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        var verseMatches: [(range: Range<String.Index>, quote: String, reference: String)] = []

        if let regex = try? NSRegularExpression(pattern: quoteFirstPattern) {
            for match in regex.matches(in: content, range: fullRange) {
                guard let matchRange = Range(match.range, in: content) else { continue }
                var quote = ""
                if match.range(at: 1).location != NSNotFound, let r = Range(match.range(at: 1), in: content) {
                    quote = String(content[r])
                } else if match.range(at: 2).location != NSNotFound, let r = Range(match.range(at: 2), in: content) {
                    quote = String(content[r])
                }
                var reference = ""
                if match.range(at: 3).location != NSNotFound, let r = Range(match.range(at: 3), in: content) {
                    reference = String(content[r])
                }
                if !quote.isEmpty && !reference.isEmpty {
                    verseMatches.append((matchRange, quote, reference))
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: refFirstPattern) {
            for match in regex.matches(in: content, range: fullRange) {
                guard let matchRange = Range(match.range, in: content) else { continue }
                var reference = ""
                if match.range(at: 1).location != NSNotFound, let r = Range(match.range(at: 1), in: content) {
                    reference = String(content[r])
                }
                var quote = ""
                if match.range(at: 2).location != NSNotFound, let r = Range(match.range(at: 2), in: content) {
                    quote = String(content[r])
                } else if match.range(at: 3).location != NSNotFound, let r = Range(match.range(at: 3), in: content) {
                    quote = String(content[r])
                }
                if !quote.isEmpty && !reference.isEmpty {
                    let overlaps = verseMatches.contains { $0.range.overlaps(matchRange) }
                    if !overlaps {
                        verseMatches.append((matchRange, quote, reference))
                    }
                }
            }
        }

        if verseMatches.isEmpty {
            return [.text(content)]
        }

        verseMatches.sort { $0.range.lowerBound < $1.range.lowerBound }

        var segments: [Segment] = []
        var cursor = content.startIndex

        let introPattern = #"[\s,.;:—–-]*\*{0,2}(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?\*{0,2}\s+(?:says|writes|reads|tells\s+us)[,:]*\s*$"#
        let introRegex = try? NSRegularExpression(pattern: introPattern)

        for vm in verseMatches {
            if cursor < vm.range.lowerBound {
                var textBefore = String(content[cursor..<vm.range.lowerBound])
                if let introRegex {
                    let range = NSRange(location: 0, length: (textBefore as NSString).length)
                    textBefore = introRegex.stringByReplacingMatches(
                        in: textBefore, range: range, withTemplate: ""
                    )
                }
                if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(textBefore))
                }
            }
            segments.append(.verseCard(quote: vm.quote, reference: vm.reference))
            cursor = vm.range.upperBound
        }

        if cursor < content.endIndex {
            var remaining = String(content[cursor...])
            remaining = remaining.replacingOccurrences(
                of: #"^[\s]*[.,;:]\s*"#, with: "", options: .regularExpression
            )
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(remaining))
            }
        }

        return segments
    }
}

// MARK: - AI Plus Symbol (4-pointed star logo)

struct AIPlusSymbol: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let armLength = min(size.width, size.height) * 0.48
            let armWidth: CGFloat = max(size.width * 0.14, 1.5)

            var path = Path()

            // Vertical arm
            path.move(to: CGPoint(x: center.x, y: center.y - armLength))
            path.addLine(to: CGPoint(x: center.x + armWidth, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + armLength))
            path.addLine(to: CGPoint(x: center.x - armWidth, y: center.y))
            path.closeSubpath()

            // Horizontal arm
            path.move(to: CGPoint(x: center.x - armLength, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + armWidth))
            path.addLine(to: CGPoint(x: center.x + armLength, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y - armWidth))
            path.closeSubpath()

            let gradient = Gradient(colors: [
                Color(red: 1.0, green: 0.84, blue: 0.3),
                Color(red: 0.79, green: 0.66, blue: 0.43)
            ])

            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }
    }
}

// MARK: - Scripture Reference Parser (for tap-to-navigate)

enum ScriptureParser {
    /// Parses "Romans 8:28" -> ("Romans", 8, 28) or "1 John 4:8" -> ("1 John", 4, 8).
    static func parseReference(_ reference: String) -> (String, Int, Int)? {
        let pattern = #"^((?:\d\s+)?[A-Z][a-z]+(?:\s+(?:of\s+)?[A-Z][a-z]+)*)\s+(\d{1,3}):(\d{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reference, range: NSRange(location: 0, length: (reference as NSString).length))
        else { return nil }

        guard let bookRange = Range(match.range(at: 1), in: reference),
              let chapterRange = Range(match.range(at: 2), in: reference),
              let chapter = Int(reference[chapterRange])
        else { return nil }

        let bookName = String(reference[bookRange])

        var verse = 0
        if match.range(at: 3).location != NSNotFound,
           let verseRange = Range(match.range(at: 3), in: reference),
           let v = Int(reference[verseRange]) {
            verse = v
        }

        guard let book = BibleData.allBooks.first(where: { $0.name == bookName }),
              chapter >= 1, chapter <= book.chapterCount
        else { return nil }

        return (bookName, chapter, verse)
    }
}

// MARK: - Segment Reveal Transitions
//
// Custom transitions used by the assistant chat bubble so that rich cards
// (story / scripture / prayer / reflection / image) visibly *develop* into
// the conversation rather than snapping in. The reveal blends opacity, a
// soft scale, an upward slide, and a clearing blur over the parent's
// segment-count animation (~1 second). Text segments use a lighter fade so
// the live word-by-word stream stays calm.

private struct CardRevealModifier: ViewModifier, Animatable {
    /// 0 = fully concealed (blurred, offset, dimmed, slightly scaled down).
    /// 1 = identity (sharp, in-place, fully opaque).
    var progress: Double

    /// Required so SwiftUI interpolates `progress` continuously between the
    /// transition's `active` and `identity` instances. Without this, the
    /// modifier would jump 0 → 1 in one frame (no visible animation).
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.92 + (0.08 * progress), anchor: .top)
            .blur(radius: (1 - progress) * 10)
            .offset(y: (1 - progress) * 28)
    }
}

private struct TextSegmentRevealModifier: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .offset(y: (1 - progress) * 6)
    }
}

extension AnyTransition {
    /// Slow, deliberate reveal for rich cards. Pairs with the parent VStack's
    /// `~0.95s` spring so cards take ~1s to fully resolve.
    static var cardReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CardRevealModifier(progress: 0),
                identity: CardRevealModifier(progress: 1)
            ),
            removal: .opacity
        )
    }

    /// Light fade-up for plain text segments — never blurred (would distract
    /// from the typewriter feel).
    static var textSegmentReveal: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: TextSegmentRevealModifier(progress: 0),
                identity: TextSegmentRevealModifier(progress: 1)
            ),
            removal: .opacity
        )
    }
}
