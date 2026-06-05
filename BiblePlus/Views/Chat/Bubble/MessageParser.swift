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
        case passageCard(book: String, chapter: Int, startVerse: Int?, endVerse: Int?, focusVerse: Int?)
        case memorizeCard(book: String, chapter: Int, verse: Int)
        case quizCard(question: String, options: [String], answerIndex: Int, explanation: String)
        case compareCard(book: String, chapter: Int, verse: Int, translations: [String])
        case planCard(id: String, title: String, category: String, days: [PlanDay])
        case mapCard(place: String, journey: String, caption: String)
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
        "TOOLRESULT", "QUOTE", "APPLY", "ORIGINAL", "PASSAGE", "MEMORIZE", "QUIZ", "COMPARE", "PLAN", "MAP"
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

    private static let tagPattern = #"\[(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT|QUOTE|APPLY|ORIGINAL|PASSAGE|MEMORIZE|QUIZ|COMPARE|PLAN|MAP)(?:\s+[^\]]*?)?\](.*?)\[/\1\]"#

    private static func extractAttribute(_ name: String, from tag: String) -> String {
        let pattern = name + #"="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              let range = Range(match.range(at: 1), in: tag)
        else { return "" }
        return String(tag[range])
    }

    private static let strayTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\[/?(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT|QUOTE|APPLY|ORIGINAL|PASSAGE|MEMORIZE|QUIZ|COMPARE|PLAN|MAP)(?:\s+[^\]]*)?\]"#)
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
        let fullTagPattern = #"\[(VERSE|PRAYER|REFLECT|ACTION|SCRIPTURE|STORY|TIMELINE|INSIGHT|IMAGE|CROSSREFS|TOOLRESULT|QUOTE|APPLY|ORIGINAL|PASSAGE|MEMORIZE|QUIZ|COMPARE|PLAN|MAP)(\s+[^\]]*)?\](.*?)\[/\1\]"#
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
            case "PASSAGE":
                let bookAttr = extractAttribute("book", from: attrs)
                guard !bookAttr.isEmpty,
                      let chapter = Int(extractAttribute("chapter", from: attrs))
                else { break }
                let (startV, endV) = parsePassageRange(extractAttribute("range", from: attrs))
                let focus = Int(extractAttribute("focus", from: attrs))
                segments.append(.passageCard(
                    book: bookAttr,
                    chapter: chapter,
                    startVerse: startV,
                    endVerse: endV,
                    focusVerse: focus
                ))
            case "MEMORIZE":
                let bookAttr = extractAttribute("book", from: attrs)
                guard !bookAttr.isEmpty,
                      let chapter = Int(extractAttribute("chapter", from: attrs)),
                      let verse = Int(extractAttribute("verse", from: attrs))
                else { break }
                segments.append(.memorizeCard(book: bookAttr, chapter: chapter, verse: verse))
            case "QUIZ":
                // Body: "Question || Option || Option [|| Option] ~~ Explanation".
                // The explanation lives in the body (not an attribute) so it can
                // safely contain quotes/punctuation.
                let halves = trimmedBody.components(separatedBy: "~~")
                let explanation = halves.count > 1
                    ? halves[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let parts = halves[0].components(separatedBy: "||")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard parts.count >= 3 else { break }   // question + ≥2 options
                let question = parts[0]
                let options = Array(parts.dropFirst().prefix(4)).map { stripOptionLabel($0) }
                let answerIndex = quizAnswerIndex(extractAttribute("answer", from: attrs),
                                                  optionCount: options.count)
                segments.append(.quizCard(
                    question: question,
                    options: options,
                    answerIndex: answerIndex,
                    explanation: explanation
                ))
            case "COMPARE":
                let bookAttr = extractAttribute("book", from: attrs)
                guard !bookAttr.isEmpty,
                      let chapter = Int(extractAttribute("chapter", from: attrs)),
                      let verse = Int(extractAttribute("verse", from: attrs))
                else { break }
                let translations = extractAttribute("translations", from: attrs)
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                segments.append(.compareCard(
                    book: bookAttr, chapter: chapter, verse: verse, translations: translations
                ))
            case "PLAN":
                let title = extractAttribute("title", from: attrs)
                guard !title.isEmpty else { break }
                let category = extractAttribute("topic", from: attrs)
                let days = parsePlanDays(trimmedBody)
                guard days.count >= 2 else { break }
                let slug = title.lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                segments.append(.planCard(
                    id: "ai-\(slug)-d\(days.count)",
                    title: title,
                    category: category,
                    days: days
                ))
            case "MAP":
                let place = extractAttribute("place", from: attrs)
                let journey = extractAttribute("journey", from: attrs)
                guard !place.isEmpty || !journey.isEmpty else { break }
                segments.append(.mapCard(place: place, journey: journey, caption: trimmedBody))
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

    /// Parses a `range="1-21"` style attribute into start/end verse numbers.
    /// A single number ("16") collapses to start==end. Empty → (nil, nil),
    /// meaning "the whole chapter".
    private static func parsePassageRange(_ raw: String) -> (start: Int?, end: Int?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (nil, nil) }
        let nums = trimmed
            .split(whereSeparator: { $0 == "-" || $0 == "\u{2013}" || $0 == "\u{2014}" })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if nums.count >= 2 { return (min(nums[0], nums[1]), max(nums[0], nums[1])) }
        if nums.count == 1 { return (nums[0], nums[0]) }
        return (nil, nil)
    }

    /// Parses a [PLAN] body into days. Each non-empty line is one day:
    /// `Day Title | Reading; Reading | Optional reflection`. Readings are real
    /// references resolved to PlanReading so the persisted plan slots straight
    /// into the existing reading-plan views.
    private static func parsePlanDays(_ body: String) -> [PlanDay] {
        var days: [PlanDay] = []
        var dayNumber = 1
        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            let title = parts[0]
            let readings = parts[1].components(separatedBy: ";").compactMap { parsePlanReading($0) }
            guard !title.isEmpty, !readings.isEmpty else { continue }
            let reflection = parts.count >= 3 && !parts[2].isEmpty ? parts[2] : nil
            days.append(PlanDay(day: dayNumber, title: title, readings: readings, reflection: reflection))
            dayNumber += 1
            if days.count >= 14 { break }
        }
        return days
    }

    /// Resolves a single reference ("Psalm 46", "Philippians 4:6-7", "John 14:27")
    /// into a PlanReading with a USFM book id + optional verse range.
    private static func parsePlanReading(_ raw: String) -> PlanReading? {
        let pattern = #"^\s*((?:[1-3]\s+)?[A-Za-z][A-Za-z.\s]*?)\s+(\d{1,3})(?::(\d{1,3})(?:\s*[-–—]\s*(\d{1,3}))?)?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: raw, range: NSRange(location: 0, length: (raw as NSString).length))
        else { return nil }
        let ns = raw as NSString
        func group(_ i: Int) -> String {
            let r = match.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
        let bookName = group(1).trimmingCharacters(in: .whitespaces)
        guard let book = BibleData.resolveBook(bookName), let chapter = Int(group(2)) else { return nil }
        let verseStart = Int(group(3))
        let verseEnd = Int(group(4)) ?? verseStart
        return PlanReading(bookID: book.id, chapter: chapter, verseStart: verseStart, verseEnd: verseEnd)
    }

    /// Maps a quiz `answer` attribute to a 0-based option index. Accepts a
    /// letter ("A"–"D") or a 1-based number ("1"–"4"); clamps to range.
    private static func quizAnswerIndex(_ raw: String, optionCount: Int) -> Int {
        let t = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if let n = Int(t) { return min(max(n - 1, 0), optionCount - 1) }
        if let scalar = t.unicodeScalars.first, scalar.value >= 65, scalar.value <= 90 {
            return min(Int(scalar.value - 65), optionCount - 1)
        }
        return 0
    }

    /// Strips a leading option label the model may have written ("A) ", "B. ",
    /// "(C) ") so the card can render its own letter badges.
    private static func stripOptionLabel(_ s: String) -> String {
        s.replacingOccurrences(of: #"^\(?[A-Da-d]\)?[.\):\-]\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    /// Parses a loosely-written reference into (canonicalBookName, chapter, verse).
    /// `verse` is 0 for chapter-only refs like "Psalm 23". Handles abbreviations
    /// and variants ("Psalm"→Psalms, "1 Cor", "Songs", "Rev") and the verse part
    /// being optional — anything `BibleData.resolveBook` knows resolves and taps.
    ///
    ///   "Romans 8:28"   -> ("Romans", 8, 28)
    ///   "Psalm 23:1"    -> ("Psalms", 23, 1)
    ///   "1 Cor 13:4-7"  -> ("1 Corinthians", 13, 4)
    ///   "Jude 1:24"     -> ("Jude", 1, 24)
    ///   "Psalm 23"      -> ("Psalms", 23, 0)
    static func parseReference(_ reference: String) -> (String, Int, Int)? {
        // Book token (optional leading numeral / roman numeral, then letters,
        // spaces, periods), a chapter, and an optional ":verse".
        // The numeral prefix must be followed by whitespace, so "Isaiah" isn't
        // mistaken for roman-numeral "I" + "saiah".
        let pattern = #"^\s*((?:[1-3]|I{1,3})\s+)?([A-Za-z][A-Za-z.\s]*?)\s+(\d{1,3})(?::(\d{1,3}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reference, range: NSRange(location: 0, length: (reference as NSString).length))
        else { return nil }

        let ns = reference as NSString
        func group(_ i: Int) -> String {
            let r = match.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }

        let numeral = group(1).trimmingCharacters(in: .whitespaces)
        let bookWords = group(2).trimmingCharacters(in: .whitespaces)
        let rawBook = numeral.isEmpty ? bookWords : "\(numeral) \(bookWords)"

        guard let chapter = Int(group(3)) else { return nil }
        let verse = Int(group(4)) ?? 0

        guard let book = BibleData.resolveBook(rawBook),
              chapter >= 1, chapter <= book.chapterCount
        else { return nil }

        return (book.name, chapter, verse)
    }
}
