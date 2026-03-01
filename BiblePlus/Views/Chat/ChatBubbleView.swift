import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool
    var onSave: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onShareAsCard: (() -> Void)? = nil
    var onScriptureTap: ((String, Int, Int) -> Void)? = nil
    var isFailedMessage: Bool = false
    var previousMessageRole: MessageRole? = nil
    var typingContextLabel: String? = nil
    var isFirstInAssistantSequence: Bool = true
    var isLastInAssistantSequence: Bool = true
    var appearDelay: Double = 0

    @Environment(\.bpPalette) private var palette
    @State private var appeared: Bool = false

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
            } else {
                // AI indicator — only on first in sequence
                if isFirstInAssistantSequence {
                    aiIndicator
                } else {
                    Spacer()
                        .frame(width: 28)
                }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if isTypingPlaceholder {
                    TypingDotsView(contextLabel: typingContextLabel)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
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
                .fill(palette.accent.opacity(0.06))
                .frame(width: 34, height: 34)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.18), palette.accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)

            Text("+")
                .font(.system(size: 18, weight: .medium, design: .serif))
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
                .font(.system(size: 15.5, weight: .regular, design: .rounded))
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
        VStack(alignment: .leading, spacing: 8) {
            if isActivelyStreaming {
                Text(message.content)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(5)
                    .textSelection(.enabled)

                BlinkingCursor(color: palette.accent)
                    .padding(.leading, 2)
                    .transition(.opacity)
            } else {
                let segments = MessageParser.parse(message.content)
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let text):
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            textView(text)
                        }
                    case .verseCard(let quote, let reference):
                        verseCardView(quote: quote, reference: reference)
                    }
                }
            }
        }
        .animation(.none, value: message.content)
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 4) {
            actionButton(icon: "doc.on.doc", label: "Copy") {
                UIPasteboard.general.string = message.content
                HapticService.success()
            }

            if let onSave {
                actionButton(icon: "bookmark", label: "Save") {
                    onSave()
                }
            }

            if let onShare {
                actionButton(icon: "square.and.arrow.up", label: "Share") {
                    onShare()
                }
            }
        }
        .padding(.top, 6)
    }

    private func actionButton(icon: String, label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.04))
                    )
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(palette.textMuted.opacity(disabled ? 0.3 : 0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
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

    private func textView(_ text: String) -> some View {
        highlightedMarkdownText(text)
            .font(.system(size: 16, weight: .regular, design: .serif))
            .lineSpacing(5)
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

    // MARK: - Verse Card

    private func verseCardView(quote: String, reference: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(quote)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(5)
                .italic()

            referenceButton(reference)
                .font(.system(size: 13, weight: .medium, design: .serif))
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.surfaceElevated.opacity(0.5))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(palette.accent.opacity(0.5))
                .frame(width: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.border.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
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
                attributed[attrStart..<attrEnd].link = url
                attributed[attrStart..<attrEnd].foregroundColor = palette.accent
            } else {
                attributed[attrStart..<attrEnd].foregroundColor = palette.accent
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
    }

    /// Reference pattern shared across verse detection regexes.
    private static let refPattern = #"(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?(?:,\s*\d{1,3}(?:\s*[-–]\s*\d{1,3})?)*"#

    /// Quote patterns (straight or curly quotes, min 20 chars).
    private static let quoteGroup = #"(?:\"([^\"]{20,})\"|(?:\u201C)([^\u201D]{20,})(?:\u201D))"#

    static func parse(_ content: String) -> [Segment] {
        // Pattern 1: "quote" — Reference  or  "quote" (Reference)  (with optional **)
        let quoteFirstPattern = quoteGroup + #"\s*[-–—(]\s*\*{0,2}("# + refPattern + #")\*{0,2}\)?"#

        // Pattern 2: **Reference** says/writes, "quote"  (reference before quote)
        let refFirstPattern = #"\*{0,2}("# + refPattern + #")\*{0,2}\s+(?:says|writes|reads|tells\s+us)[,:]\s*"# + quoteGroup

        let nsString = content as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Collect all verse matches from both patterns
        var verseMatches: [(range: Range<String.Index>, quote: String, reference: String)] = []

        // Try pattern 1 (quote first)
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

        // Try pattern 2 (reference first)
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
                    // Avoid duplicates from pattern 1
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

        // Sort by position and build segments
        verseMatches.sort { $0.range.lowerBound < $1.range.lowerBound }

        var segments: [Segment] = []
        var cursor = content.startIndex

        // Pattern to strip redundant "Reference says," intro right before a verse card
        let introPattern = #"[\s,.;:—–-]*\*{0,2}(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?\*{0,2}\s+(?:says|writes|reads|tells\s+us)[,:]*\s*$"#
        let introRegex = try? NSRegularExpression(pattern: introPattern)

        for vm in verseMatches {
            if cursor < vm.range.lowerBound {
                var textBefore = String(content[cursor..<vm.range.lowerBound])
                // Remove trailing "Ephesians 2:8 says," before the verse card
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
            // Strip stray leading punctuation left after verse card extraction
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
