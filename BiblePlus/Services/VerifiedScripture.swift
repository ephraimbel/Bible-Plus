import Foundation

/// Scripture cards use local source text, never model-generated verse wording.
/// WEB is the AI companion's quotation edition; Compare loads other licensed
/// editions directly from their bundles.
enum VerifiedScripture {
    static func quote(reference: String) -> (text: String, reference: String)? {
        let pattern = #"^\s*(.+?)\s+(\d+):(\d+)(?:\s*[-–]\s*(\d+))?(?:\s*\([^)]*\))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reference, range: NSRange(reference.startIndex..., in: reference))
        else { return nil }
        let ns = reference as NSString
        guard let book = BibleData.resolveBook(ns.substring(with: match.range(at: 1))),
              let chapter = Int(ns.substring(with: match.range(at: 2))),
              let start = Int(ns.substring(with: match.range(at: 3))) else { return nil }
        let end = match.range(at: 4).location == NSNotFound ? start : Int(ns.substring(with: match.range(at: 4))) ?? start
        guard start > 0, end >= start, end - start < 30 else { return nil }
        let verses = BibleRepository.shared.versesSync(book: book.id, chapter: chapter, translation: .web)
            .filter { $0.number >= start && $0.number <= end }
        guard verses.count == end - start + 1 else { return nil }
        let range = start == end ? "\(start)" : "\(start)-\(end)"
        return (verses.map(\.text).joined(separator: " "), "\(book.name) \(chapter):\(range) (WEB)")
    }

    /// Also canonicalize persisted/copied/shared cards after streaming finishes.
    static func replacingGeneratedCards(in content: String) -> String {
        let pattern = #"\[(SCRIPTURE|VERSE|CROSSREFS)([^\]]*)\](.*?)\[/\1\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return content }
        var result = content
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches.reversed() {
            let ns = content as NSString
            let body = ns.substring(with: match.range(at: 3))
            let tag = ns.substring(with: match.range(at: 1))
            if tag == "CROSSREFS" {
                let rows = body.components(separatedBy: .newlines).compactMap { line -> String? in
                    guard let reference = line.components(separatedBy: "|").first,
                          let verified = quote(reference: reference.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
                    return "\(verified.reference) || \(verified.text)"
                }.prefix(4)
                if let range = Range(match.range, in: result) {
                    result.replaceSubrange(range, with: rows.isEmpty ? "" : "[CROSSREFS]\n" + rows.joined(separator: "\n") + "\n[/CROSSREFS]")
                }
                continue
            }
            let refRegex = try? NSRegularExpression(pattern: #"[—–-]\s*((?:[1-3]\s+)?[A-Za-z][^—]*)$"#)
            let refMatch = refRegex?.firstMatch(in: body, range: NSRange(body.startIndex..., in: body))
            let reference = refMatch.map { (body as NSString).substring(with: $0.range(at: 1)) } ?? ""
            guard let range = Range(match.range, in: result) else { continue }
            if let verified = quote(reference: reference.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let attrs = ns.substring(with: match.range(at: 2))
                result.replaceSubrange(range, with: "[\(tag)\(attrs)]\"\(verified.text)\" — \(verified.reference)[/\(tag)]")
            } else {
                // Do not present generated wording as a Bible quotation when
                // its reference cannot be verified.
                result.replaceSubrange(range, with: "")
            }
        }
        return result
    }
}
