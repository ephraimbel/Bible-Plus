import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool
    var onSave: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onScriptureTap: ((String, Int) -> Void)? = nil

    @Environment(\.bpPalette) private var palette

    private var isTypingPlaceholder: Bool {
        isStreaming && message.role == .assistant && message.content.isEmpty
    }

    private var isActivelyStreaming: Bool {
        isStreaming && message.role == .assistant && !message.content.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Image(systemName: "sparkles")
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
                } else if message.role == .user {
                    Text(message.content)
                        .font(BPFont.chat)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(bubbleColor)
                        )
                        .textSelection(.enabled)
                } else {
                    // AI message: segmented rendering (text + verse cards)
                    assistantBubble
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

    // MARK: - Assistant Bubble (Segmented)

    private var assistantBubble: some View {
        let segments = MessageParser.parse(message.content)

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        textBubble(text)
                    }
                case .verseCard(let quote, let reference):
                    verseCardView(quote: quote, reference: reference)
                }
            }

            // Streaming cursor
            if isActivelyStreaming {
                streamingCursor
            }
        }
        .contextMenu {
            if !isStreaming {
                if let onSave {
                    Button {
                        onSave()
                    } label: {
                        Label("Save Response", systemImage: "bookmark")
                    }
                }
                if let onShare {
                    Button {
                        onShare()
                    } label: {
                        Label("Share Response", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    UIPasteboard.general.string = message.content
                    HapticService.success()
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
            }
        }
    }

    // MARK: - Text Bubble (Markdown + Scripture Highlighting)

    private func textBubble(_ text: String) -> some View {
        highlightedMarkdownText(text)
            .font(BPFont.chat)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "bibleplus",
                   url.host == "bible",
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let bookName = components.queryItems?.first(where: { $0.name == "book" })?.value,
                   let chapterStr = components.queryItems?.first(where: { $0.name == "ch" })?.value,
                   let chapter = Int(chapterStr) {
                    onScriptureTap?(bookName, chapter)
                    HapticService.lightImpact()
                    return .handled
                }
                return .systemAction
            })
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(bubbleColor)
            )
            .textSelection(.enabled)
    }

    // MARK: - Verse Card

    private func verseCardView(quote: String, reference: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(quote)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(palette.accent)
                .lineSpacing(4)
                .italic()

            HStack(spacing: 0) {
                Text("— ")
                    .foregroundStyle(palette.textMuted)
                referenceButton(reference)
            }
            .font(.system(size: 13, weight: .regular, design: .serif))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(palette.accent)
                .frame(width: 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.accent.opacity(0.08))
        )
    }

    // MARK: - Streaming Cursor

    private var streamingCursor: some View {
        BlinkingCursor(color: palette.accent)
            .padding(.leading, 14)
            .transition(.opacity)
    }

    // MARK: - Tappable Reference

    private func referenceButton(_ reference: String) -> some View {
        Group {
            if let (bookName, chapter) = ScriptureParser.parseReference(reference) {
                Button {
                    onScriptureTap?(bookName, chapter)
                    HapticService.lightImpact()
                } label: {
                    Text(reference)
                        .foregroundStyle(palette.accent)
                        .underline(color: palette.accent.opacity(0.4))
                }
            } else {
                Text(reference)
                    .foregroundStyle(palette.accent)
            }
        }
    }

    // MARK: - Markdown + Scripture Highlighting

    private func highlightedMarkdownText(_ content: String) -> Text {
        // Step 1: Parse markdown into AttributedString
        var attributed: AttributedString
        do {
            attributed = try AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            attributed = AttributedString(content)
        }

        // Step 2: Set base foreground color
        attributed.foregroundColor = palette.textPrimary

        // Step 3: Find scripture ranges in the plain text and apply gold + tappable links
        let plainText = String(attributed.characters)
        let highlights = scriptureRanges(in: plainText)

        for highlight in highlights {
            let startOffset = plainText.distance(from: plainText.startIndex, to: highlight.lowerBound)
            let endOffset = plainText.distance(from: plainText.startIndex, to: highlight.upperBound)
            let attrStart = attributed.characters.index(attributed.startIndex, offsetBy: startOffset)
            let attrEnd = attributed.characters.index(attributed.startIndex, offsetBy: endOffset)

            let segment = String(plainText[highlight])

            // If it's a parseable scripture reference, make it tappable
            if let (bookName, chapter) = ScriptureParser.parseReference(segment),
               let encoded = bookName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "bibleplus://bible?book=\(encoded)&ch=\(chapter)") {
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

        // Quoted scripture (straight and curly quotes, 4+ chars inside)
        let quotePatterns = [
            #"\"[^\"]{4,}\""#,
            #"\u201C[^\u201D]{4,}\u201D"#
        ]

        // Scripture references: John 3:16, 1 Corinthians 13:4-7, etc.
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

    private var bubbleColor: Color {
        message.role == .user
            ? palette.accent
            : palette.surface
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

    /// Splits AI message content into text segments and verse card segments.
    /// A verse card is detected when quoted text (20+ chars) is followed by a scripture reference.
    static func parse(_ content: String) -> [Segment] {
        // Pattern: quoted text (straight or curly quotes) followed by a reference in parens, dash, or em-dash
        let pattern = #"(?:\"([^\"]{20,})\"|(?:\u201C)([^\u201D]{20,})(?:\u201D))\s*[-–—(]\s*((?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?(?:,\s*\d{1,3}(?:\s*[-–]\s*\d{1,3})?)*)\)?"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
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
            guard let matchRange = Range(match.range, in: content) else { continue }

            // Add text before this verse card
            if cursor < matchRange.lowerBound {
                let textBefore = String(content[cursor..<matchRange.lowerBound])
                if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(textBefore))
                }
            }

            // Extract quote (group 1 for straight quotes, group 2 for curly)
            var quote = ""
            if match.range(at: 1).location != NSNotFound,
               let r = Range(match.range(at: 1), in: content) {
                quote = String(content[r])
            } else if match.range(at: 2).location != NSNotFound,
                      let r = Range(match.range(at: 2), in: content) {
                quote = String(content[r])
            }

            // Extract reference (group 3)
            var reference = ""
            if match.range(at: 3).location != NSNotFound,
               let r = Range(match.range(at: 3), in: content) {
                reference = String(content[r])
            }

            if !quote.isEmpty && !reference.isEmpty {
                segments.append(.verseCard(quote: quote, reference: reference))
            } else {
                segments.append(.text(String(content[matchRange])))
            }

            cursor = matchRange.upperBound
        }

        // Add remaining text
        if cursor < content.endIndex {
            let remaining = String(content[cursor...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(remaining))
            }
        }

        return segments
    }
}

// MARK: - Scripture Reference Parser (for tap-to-navigate)

enum ScriptureParser {
    /// Parses a reference like "Romans 8:28" or "1 John 4:8" into (bookName, chapter).
    /// Returns nil if the reference can't be resolved to a known BibleBook.
    static func parseReference(_ reference: String) -> (String, Int)? {
        let pattern = #"^((?:\d\s+)?[A-Z][a-z]+(?:\s+(?:of\s+)?[A-Z][a-z]+)*)\s+(\d{1,3}):\d"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reference, range: NSRange(location: 0, length: (reference as NSString).length))
        else { return nil }

        guard let bookRange = Range(match.range(at: 1), in: reference),
              let chapterRange = Range(match.range(at: 2), in: reference),
              let chapter = Int(reference[chapterRange])
        else { return nil }

        let bookName = String(reference[bookRange])

        // Verify it's a real Bible book with a valid chapter
        guard let book = BibleData.allBooks.first(where: { $0.name == bookName }),
              chapter >= 1, chapter <= book.chapterCount
        else { return nil }

        return (bookName, chapter)
    }
}
