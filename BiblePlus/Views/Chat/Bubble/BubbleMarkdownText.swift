import SwiftUI

/// Renders assistant prose with markdown + highlighted scripture references.
/// Scripture refs become tappable `bibleplus://` links; free-quoted scripture
/// gets italic accent styling without a link pill.
struct BubbleMarkdownText: View {
    let text: String
    let onScriptureTap: ((String, Int, Int) -> Void)?

    @Environment(\.bpPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parseTextBlocks(text).enumerated()), id: \.offset) { _, block in
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
            .font(.system(size: 18, weight: .regular, design: .serif))
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
                // A tappable reference: clean gold serif in our voice with a
                // soft gold underline — interactive but editorial, no blocky
                // background highlight (Claude-style).
                attributed[attrStart..<attrEnd].link = url
                attributed[attrStart..<attrEnd].foregroundColor = palette.accent
                attributed[attrStart..<attrEnd].font = .system(size: 17, weight: .semibold, design: .serif)
                attributed[attrStart..<attrEnd].underlineStyle = Text.LineStyle(
                    pattern: .solid,
                    color: palette.accent.opacity(0.35)
                )
            } else {
                attributed[attrStart..<attrEnd].foregroundColor = palette.accent
                attributed[attrStart..<attrEnd].font = .system(size: 17, weight: .medium, design: .serif).italic()
            }
        }

        return Text(attributed)
    }

    private func scriptureRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let nsString = text as NSString
        let full = NSRange(location: 0, length: nsString.length)

        let quotePatterns = [
            #"\"[^\"]{4,}\""#,
            #"“[^”]{4,}”"#
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
