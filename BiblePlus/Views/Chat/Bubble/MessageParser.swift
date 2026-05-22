import Foundation

enum MessageParser {
    enum Segment {
        case text(String)
        case verseCard(quote: String, reference: String)
        case prayerCard(text: String)
        case reflectionCard(question: String)
        case actionCard(label: String, link: String, description: String)
        case scriptureCard(quote: String, reference: String, imageKey: String?)
        case storyCard(title: String, summary: String, imageKey: String?)
        case timelineCard(events: [(label: String, reference: String, period: String)])
        case insightCard(text: String)
        case imageCard(key: String, caption: String)
        case crossRefsCard(refs: [(reference: String, quote: String)])
        case toolResultCard(name: String, summary: String, isError: Bool)
        case quoteCard(text: String, attribution: String)
        case applyCard(title: String, items: [String])
        case originalWordCard(word: String, language: String, transliteration: String, meaning: String)
    }

    private static var cache: [String: [Segment]] = [:]
    private static let cacheLimit = 50

    static func parseCached(_ content: String) -> [Segment] {
        if let cached = cache[content] { return cached }
        let result = parse(content)
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[content] = result
        return result
    }

    /// Streaming-aware parse. Completed cards render immediately while
    /// in-progress content stays as plain text. Strips trailing follow-ups
    /// marker, extracts every CLOSED `[TAG]...[/TAG]` block, hides unclosed
    /// openers from the trailing text. Not cached — content changes per word.
    static func parseStreaming(_ content: String) -> [Segment] {
        var working = content
        if let pipeRange = working.range(of: "|||") {
            working = String(working[..<pipeRange.lowerBound])
        }

        var segments = parseWithTags(working)

        if let lastIndex = segments.indices.last,
           case .text(let tailText) = segments[lastIndex] {
            let cleaned = stripUnclosedOpener(tailText)
            let final = stripStrayTags(cleaned)
            if final.isEmpty {
                segments.removeLast()
            } else {
                segments[lastIndex] = .text(final)
            }
        }

        return segments
    }

    private static let knownTagNames = [
        "VERSE", "PRAYER", "REFLECT", "ACTION",
        "SCRIPTURE", "STORY", "TIMELINE", "INSIGHT", "IMAGE", "CROSSREFS",
        "TOOLRESULT", "QUOTE", "APPLY", "ORIGINAL"
    ]

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

    private static let tagPattern = #"\[(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT|QUOTE|APPLY|ORIGINAL)(?:\s+[^\]]*?)?\](.*?)\[/\1\]"#

    private static func extractAttribute(_ name: String, from tag: String) -> String {
        let pattern = name + #"="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              let range = Range(match.range(at: 1), in: tag)
        else { return "" }
        return String(tag[range])
    }

    private static let strayTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\[/?(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT|QUOTE|APPLY|ORIGINAL)(?:\s+[^\]]*)?\]"#)
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
        let tagSegments = parseWithTags(content)
        if tagSegments.contains(where: { !isTextSegment($0) }) {
            return tagSegments.compactMap { segment in
                if case .text(let text) = segment {
                    let cleaned = stripStrayTags(text)
                    return cleaned.isEmpty ? nil : .text(cleaned)
                }
                return segment
            }
        }
        return parseLegacy(content)
    }

    private static func isTextSegment(_ segment: Segment) -> Bool {
        if case .text = segment { return true }
        return false
    }

    private static func parseWithTags(_ content: String) -> [Segment] {
        let fullTagPattern = #"\[(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT|QUOTE|APPLY|ORIGINAL)(\s+[^\]]*)?\](.*?)\[/\1\]"#
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

            if cursor < matchRange.lowerBound {
                let text = String(content[cursor..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    segments.append(.text(text))
                }
            }

            let tag = String(content[tagRange])
            let body = String(content[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            let attrs: String
            if match.range(at: 2).location != NSNotFound, let attrRange = Range(match.range(at: 2), in: content) {
                attrs = String(content[attrRange])
            } else {
                attrs = ""
            }

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
                guard !quote.isEmpty else { break }
                segments.append(.scriptureCard(
                    quote: quote,
                    reference: parsed.reference,
                    imageKey: imgKey.isEmpty ? nil : imgKey
                ))
            case "STORY":
                let title = extractAttribute("title", from: attrs)
                let imgKey = extractAttribute("img", from: attrs)
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
                guard !key.isEmpty else { break }
                segments.append(.imageCard(key: key, caption: trimmedBody))
            case "CROSSREFS":
                let refs = parseCrossRefsBody(body)
                guard !refs.isEmpty else { break }
                segments.append(.crossRefsCard(refs: refs))
            case "TOOLRESULT":
                let name = extractAttribute("name", from: attrs)
                let status = extractAttribute("status", from: attrs)
                guard !trimmedBody.isEmpty else { break }
                segments.append(.toolResultCard(
                    name: name,
                    summary: trimmedBody,
                    isError: status == "error"
                ))
            case "QUOTE":
                let parsed = parseQuoteBody(trimmedBody, attrs: attrs)
                guard !parsed.text.isEmpty else { break }
                segments.append(.quoteCard(text: parsed.text, attribution: parsed.attribution))
            case "APPLY":
                let title = extractAttribute("title", from: attrs)
                let items = parseApplyBody(trimmedBody)
                guard !items.isEmpty else { break }
                segments.append(.applyCard(title: title, items: items))
            case "ORIGINAL":
                let word = extractAttribute("word", from: attrs)
                let language = extractAttribute("lang", from: attrs)
                let translit = extractAttribute("translit", from: attrs)
                guard !word.isEmpty, !trimmedBody.isEmpty else { break }
                segments.append(.originalWordCard(
                    word: word,
                    language: language,
                    transliteration: translit,
                    meaning: trimmedBody
                ))
            default:
                if !trimmedBody.isEmpty {
                    segments.append(.text(trimmedBody))
                }
            }

            cursor = matchRange.upperBound
        }

        if cursor < content.endIndex {
            let text = String(content[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(.text(text))
            }
        }

        return segments
    }

    private static func parseQuoteBody(_ body: String, attrs: String) -> (text: String, attribution: String) {
        let attrAttribution = extractAttribute("by", from: attrs)
        if body.contains("—") || body.contains("--") {
            let separator = body.contains("—") ? "—" : "--"
            let parts = body.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if parts.count >= 2 {
                var quote = parts[0]
                quote = quote.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
                let attribution = parts.dropFirst().joined(separator: " — ")
                return (quote, attribution)
            }
        }
        let cleaned = body.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))
        return (cleaned, attrAttribution)
    }

    private static func parseApplyBody(_ body: String) -> [String] {
        let lines = body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let stripped = lines.map { line -> String in
            var s = line
            let bulletPrefixes = ["- ", "• ", "* "]
            for prefix in bulletPrefixes {
                if s.hasPrefix(prefix) {
                    s = String(s.dropFirst(prefix.count))
                    break
                }
            }
            if let dotIndex = s.firstIndex(of: "."),
               let num = Int(s[..<dotIndex]),
               num >= 1, num <= 9 {
                s = String(s[s.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
            }
            return s
        }
        .filter { !$0.isEmpty }

        if stripped.count >= 2 { return Array(stripped.prefix(4)) }
        return body.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .map { $0 }
    }

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

    private static func parseVerseBody(_ body: String) -> (quote: String, reference: String) {
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
        return (body, "")
    }

    private static let refPattern = #"(?:\d\s+)?[A-Z][a-z]{2,}(?:\s+(?:of\s+)?[A-Z][a-z]+)*\s+\d{1,3}:\d{1,3}(?:\s*[-–]\s*\d{1,3})?(?:,\s*\d{1,3}(?:\s*[-–]\s*\d{1,3})?)*"#

    private static let quoteGroup = #"(?:\"([^\"]{20,})\"|(?:“)([^”]{20,})(?:”))"#

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
