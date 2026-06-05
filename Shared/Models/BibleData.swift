import Foundation

struct BibleBook: Identifiable, Hashable {
    let id: String // abbreviation e.g. "GEN"
    let name: String
    let chapterCount: Int
    let testament: Testament

    var apiBookNumber: Int {
        BibleData.apiBookNumber(for: id) ?? 1
    }

    enum Testament: String {
        case old, new

        var displayName: String {
            switch self {
            case .old: String(localized: "Old Testament")
            case .new: String(localized: "New Testament")
            }
        }
    }
}

enum BibleData {
    static let oldTestament: [BibleBook] = [
        BibleBook(id: "GEN", name: "Genesis", chapterCount: 50, testament: .old),
        BibleBook(id: "EXO", name: "Exodus", chapterCount: 40, testament: .old),
        BibleBook(id: "LEV", name: "Leviticus", chapterCount: 27, testament: .old),
        BibleBook(id: "NUM", name: "Numbers", chapterCount: 36, testament: .old),
        BibleBook(id: "DEU", name: "Deuteronomy", chapterCount: 34, testament: .old),
        BibleBook(id: "JOS", name: "Joshua", chapterCount: 24, testament: .old),
        BibleBook(id: "JDG", name: "Judges", chapterCount: 21, testament: .old),
        BibleBook(id: "RUT", name: "Ruth", chapterCount: 4, testament: .old),
        BibleBook(id: "1SA", name: "1 Samuel", chapterCount: 31, testament: .old),
        BibleBook(id: "2SA", name: "2 Samuel", chapterCount: 24, testament: .old),
        BibleBook(id: "1KI", name: "1 Kings", chapterCount: 22, testament: .old),
        BibleBook(id: "2KI", name: "2 Kings", chapterCount: 25, testament: .old),
        BibleBook(id: "1CH", name: "1 Chronicles", chapterCount: 29, testament: .old),
        BibleBook(id: "2CH", name: "2 Chronicles", chapterCount: 36, testament: .old),
        BibleBook(id: "EZR", name: "Ezra", chapterCount: 10, testament: .old),
        BibleBook(id: "NEH", name: "Nehemiah", chapterCount: 13, testament: .old),
        BibleBook(id: "EST", name: "Esther", chapterCount: 10, testament: .old),
        BibleBook(id: "JOB", name: "Job", chapterCount: 42, testament: .old),
        BibleBook(id: "PSA", name: "Psalms", chapterCount: 150, testament: .old),
        BibleBook(id: "PRO", name: "Proverbs", chapterCount: 31, testament: .old),
        BibleBook(id: "ECC", name: "Ecclesiastes", chapterCount: 12, testament: .old),
        BibleBook(id: "SNG", name: "Song of Solomon", chapterCount: 8, testament: .old),
        BibleBook(id: "ISA", name: "Isaiah", chapterCount: 66, testament: .old),
        BibleBook(id: "JER", name: "Jeremiah", chapterCount: 52, testament: .old),
        BibleBook(id: "LAM", name: "Lamentations", chapterCount: 5, testament: .old),
        BibleBook(id: "EZK", name: "Ezekiel", chapterCount: 48, testament: .old),
        BibleBook(id: "DAN", name: "Daniel", chapterCount: 12, testament: .old),
        BibleBook(id: "HOS", name: "Hosea", chapterCount: 14, testament: .old),
        BibleBook(id: "JOL", name: "Joel", chapterCount: 3, testament: .old),
        BibleBook(id: "AMO", name: "Amos", chapterCount: 9, testament: .old),
        BibleBook(id: "OBA", name: "Obadiah", chapterCount: 1, testament: .old),
        BibleBook(id: "JON", name: "Jonah", chapterCount: 4, testament: .old),
        BibleBook(id: "MIC", name: "Micah", chapterCount: 7, testament: .old),
        BibleBook(id: "NAM", name: "Nahum", chapterCount: 3, testament: .old),
        BibleBook(id: "HAB", name: "Habakkuk", chapterCount: 3, testament: .old),
        BibleBook(id: "ZEP", name: "Zephaniah", chapterCount: 3, testament: .old),
        BibleBook(id: "HAG", name: "Haggai", chapterCount: 2, testament: .old),
        BibleBook(id: "ZEC", name: "Zechariah", chapterCount: 14, testament: .old),
        BibleBook(id: "MAL", name: "Malachi", chapterCount: 4, testament: .old),
    ]

    static let newTestament: [BibleBook] = [
        BibleBook(id: "MAT", name: "Matthew", chapterCount: 28, testament: .new),
        BibleBook(id: "MRK", name: "Mark", chapterCount: 16, testament: .new),
        BibleBook(id: "LUK", name: "Luke", chapterCount: 24, testament: .new),
        BibleBook(id: "JHN", name: "John", chapterCount: 21, testament: .new),
        BibleBook(id: "ACT", name: "Acts", chapterCount: 28, testament: .new),
        BibleBook(id: "ROM", name: "Romans", chapterCount: 16, testament: .new),
        BibleBook(id: "1CO", name: "1 Corinthians", chapterCount: 16, testament: .new),
        BibleBook(id: "2CO", name: "2 Corinthians", chapterCount: 13, testament: .new),
        BibleBook(id: "GAL", name: "Galatians", chapterCount: 6, testament: .new),
        BibleBook(id: "EPH", name: "Ephesians", chapterCount: 6, testament: .new),
        BibleBook(id: "PHP", name: "Philippians", chapterCount: 4, testament: .new),
        BibleBook(id: "COL", name: "Colossians", chapterCount: 4, testament: .new),
        BibleBook(id: "1TH", name: "1 Thessalonians", chapterCount: 5, testament: .new),
        BibleBook(id: "2TH", name: "2 Thessalonians", chapterCount: 3, testament: .new),
        BibleBook(id: "1TI", name: "1 Timothy", chapterCount: 6, testament: .new),
        BibleBook(id: "2TI", name: "2 Timothy", chapterCount: 4, testament: .new),
        BibleBook(id: "TIT", name: "Titus", chapterCount: 3, testament: .new),
        BibleBook(id: "PHM", name: "Philemon", chapterCount: 1, testament: .new),
        BibleBook(id: "HEB", name: "Hebrews", chapterCount: 13, testament: .new),
        BibleBook(id: "JAS", name: "James", chapterCount: 5, testament: .new),
        BibleBook(id: "1PE", name: "1 Peter", chapterCount: 5, testament: .new),
        BibleBook(id: "2PE", name: "2 Peter", chapterCount: 3, testament: .new),
        BibleBook(id: "1JN", name: "1 John", chapterCount: 5, testament: .new),
        BibleBook(id: "2JN", name: "2 John", chapterCount: 1, testament: .new),
        BibleBook(id: "3JN", name: "3 John", chapterCount: 1, testament: .new),
        BibleBook(id: "JUD", name: "Jude", chapterCount: 1, testament: .new),
        BibleBook(id: "REV", name: "Revelation", chapterCount: 22, testament: .new),
    ]

    static let allBooks: [BibleBook] = oldTestament + newTestament

    static func book(id: String) -> BibleBook? {
        allBooks.first { $0.id == id }
    }

    static func apiBookNumber(for bookID: String) -> Int? {
        guard let index = allBooks.firstIndex(where: { $0.id == bookID }) else { return nil }
        return index + 1
    }

    // MARK: - Robust Book Resolution
    //
    // Maps a loosely-written book name to a canonical `BibleBook`. Handles the
    // exact name, common abbreviations, and frequent variants the AI (or a
    // cross-reference) produces — e.g. "Psalm" → Psalms, "Songs"/"Song of Songs"
    // → Song of Solomon, "Rom"/"1 Cor"/"Rev". Numeral prefixes are normalized
    // ("I John", "First John", "1st John" → "1 John") before lookup.

    /// alias (lowercased, no periods, single-spaced) → canonical book id.
    private static let bookAliases: [String: String] = {
        var map: [String: String] = [:]
        // Every canonical name resolves to itself.
        for b in allBooks { map[b.name.lowercased()] = b.id }
        // Curated abbreviations & variants, keyed by the EXACT canonical name
        // (lowercased) so each always resolves to a real book regardless of id.
        let extra: [String: [String]] = [
            "genesis": ["gen", "gn"], "exodus": ["exod", "exo", "ex"], "leviticus": ["lev", "lv"],
            "numbers": ["num", "nm", "nb"], "deuteronomy": ["deut", "deu", "dt"], "joshua": ["josh", "jos", "jsh"],
            "judges": ["judg", "jdg", "jg"], "ruth": ["rth", "ru"],
            "1 samuel": ["1 sam", "1 sm"], "2 samuel": ["2 sam", "2 sm"],
            "1 kings": ["1 kgs", "1 ki"], "2 kings": ["2 kgs", "2 ki"],
            "1 chronicles": ["1 chron", "1 chr", "1 ch"], "2 chronicles": ["2 chron", "2 chr", "2 ch"],
            "ezra": ["ezr"], "nehemiah": ["neh", "ne"], "esther": ["esth", "est"], "job": ["jb"],
            "psalms": ["psalm", "ps", "psa", "pss", "pslm"], "proverbs": ["prov", "prv", "pro", "pr"],
            "ecclesiastes": ["eccl", "eccles", "ecc", "qoh"],
            "song of solomon": ["song of songs", "song", "songs", "sos", "canticles", "sng"],
            "isaiah": ["isa", "is"], "jeremiah": ["jer", "je"], "lamentations": ["lam", "la"],
            "ezekiel": ["ezek", "eze", "ezk"], "daniel": ["dan", "dn"], "hosea": ["hos", "ho"],
            "joel": ["jl", "joe"], "amos": ["am"], "obadiah": ["obad", "oba", "ob"],
            "jonah": ["jon", "jnh"], "micah": ["mic", "mc"], "nahum": ["nah", "na"], "habakkuk": ["hab"],
            "zephaniah": ["zeph", "zep", "zp"], "haggai": ["hag", "hg"], "zechariah": ["zech", "zec", "zc"],
            "malachi": ["mal", "ml"], "matthew": ["matt", "mat", "mt"], "mark": ["mrk", "mk", "mr"],
            "luke": ["luk", "lk"], "john": ["jhn", "jn"], "acts": ["act", "ac"], "romans": ["rom", "rm", "ro"],
            "1 corinthians": ["1 cor", "1 co"], "2 corinthians": ["2 cor", "2 co"],
            "galatians": ["gal", "ga"], "ephesians": ["eph", "ephes"], "philippians": ["phil", "php", "pp"],
            "colossians": ["col"], "1 thessalonians": ["1 thess", "1 thes", "1 th"],
            "2 thessalonians": ["2 thess", "2 thes", "2 th"], "1 timothy": ["1 tim", "1 ti"],
            "2 timothy": ["2 tim", "2 ti"], "titus": ["tit"], "philemon": ["philem", "phlm", "phm"],
            "hebrews": ["heb"], "james": ["jas", "jm", "jms"], "1 peter": ["1 pet", "1 pt", "1 pe"],
            "2 peter": ["2 pet", "2 pt", "2 pe"], "1 john": ["1 jn", "1 jhn", "1 jo"],
            "2 john": ["2 jn", "2 jhn"], "3 john": ["3 jn", "3 jhn"], "jude": ["jud", "jd"],
            "revelation": ["revelations", "rev", "rv", "re"],
        ]
        for (canonical, aliases) in extra {
            guard let book = allBooks.first(where: { $0.name.lowercased() == canonical }) else { continue }
            for a in aliases { map[a] = book.id }
        }
        return map
    }()

    /// Resolve a loosely-written book name (e.g. "Psalm", "1 Cor", "Songs").
    static func resolveBook(_ rawName: String) -> BibleBook? {
        var s = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: ".", with: "")
        s = s.split(whereSeparator: { $0 == " " }).joined(separator: " ")
        // Normalize numeral prefixes: "i/ii/iii", "first/second/third", "1st/2nd/3rd".
        let prefixes: [(String, String)] = [
            ("first ", "1 "), ("second ", "2 "), ("third ", "3 "),
            ("1st ", "1 "), ("2nd ", "2 "), ("3rd ", "3 "),
            ("iii ", "3 "), ("ii ", "2 "), ("i ", "1 "),
        ]
        for (k, v) in prefixes where s.hasPrefix(k) {
            s = v + String(s.dropFirst(k.count))
            break
        }
        guard let id = bookAliases[s] else { return nil }
        return allBooks.first { $0.id == id }
    }
}
