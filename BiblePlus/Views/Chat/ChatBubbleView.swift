import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool
    var onSave: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onScriptureTap: ((String, Int, Int) -> Void)? = nil
    var onSavePrayerToJournal: (() -> Void)? = nil
    var isPrayerMessage: Bool = false
    var isSavedToJournal: Bool = false
    var isFailedMessage: Bool = false
    var previousMessageRole: MessageRole? = nil

    @Environment(\.bpPalette) private var palette

    private var isTypingPlaceholder: Bool {
        isStreaming && message.role == .assistant && message.content.isEmpty
    }

    private var isActivelyStreaming: Bool {
        isStreaming && message.role == .assistant && !message.content.isEmpty
    }

    private var showRoleGap: Bool {
        guard let prev = previousMessageRole else { return false }
        return prev != message.role
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI avatar — gold gradient circle with sparkle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: palette.accent.opacity(0.2), radius: 6, y: 2)

                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if isTypingPlaceholder {
                    TypingDotsView()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(palette.surfaceElevated)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else if message.role == .user {
                    Text(message.content)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            userBubbleShape
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: palette.accent.opacity(0.15), radius: 6, y: 3)
                        )
                        .textSelection(.enabled)

                    // Failed message indicator
                    if isFailedMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Failed to send")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(palette.error)
                        .padding(.top, 2)
                    }
                } else {
                    // AI message: segmented rendering
                    assistantBubble

                    // Save to Journal button
                    if isPrayerMessage {
                        saveToJournalButton
                    }
                }
            }
            .animation(BPAnimation.spring, value: isTypingPlaceholder)

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, showRoleGap ? 10 : 2)
        .padding(.bottom, 2)
    }

    // MARK: - Bubble Shapes

    private var userBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 6
        )
    }

    private var aiBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 6,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18
        )
    }

    // MARK: - Save to Journal Button

    private var saveToJournalButton: some View {
        Button {
            onSavePrayerToJournal?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSavedToJournal ? "checkmark.circle.fill" : "book.closed.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(isSavedToJournal ? "Saved to Journal" : "Save to Journal")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSavedToJournal ? Color.green : palette.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSavedToJournal ? Color.green.opacity(0.1) : palette.accent.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSavedToJournal ? Color.green.opacity(0.2) : palette.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(isSavedToJournal)
        .padding(.top, 4)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(BPAnimation.spring, value: isSavedToJournal)
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
            .font(.system(size: 15, weight: .regular, design: .rounded))
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
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                aiBubbleShape
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            )
            .overlay(
                aiBubbleShape
                    .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
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
                Text("\u{2014} ")
                    .foregroundStyle(palette.textMuted)
                referenceButton(reference)
            }
            .font(.system(size: 13, weight: .regular, design: .serif))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(
                LinearGradient(
                    colors: [palette.accent, palette.accent.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
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
            if let (bookName, chapter, verse) = ScriptureParser.parseReference(reference) {
                Button {
                    onScriptureTap?(bookName, chapter, verse)
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

    static func parse(_ content: String) -> [Segment] {
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

            if cursor < matchRange.lowerBound {
                let textBefore = String(content[cursor..<matchRange.lowerBound])
                if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(textBefore))
                }
            }

            var quote = ""
            if match.range(at: 1).location != NSNotFound,
               let r = Range(match.range(at: 1), in: content) {
                quote = String(content[r])
            } else if match.range(at: 2).location != NSNotFound,
                      let r = Range(match.range(at: 2), in: content) {
                quote = String(content[r])
            }

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
    /// Parses "Romans 8:28" → ("Romans", 8, 28) or "1 John 4:8" → ("1 John", 4, 8).
    /// Returns (bookName, chapter, verse). Verse is 0 if not parseable.
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

        // Extract verse number (group 3)
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
