import Foundation

struct BibleBook: Identifiable, Hashable {
    let id: String // abbreviation e.g. "GEN"
    let name: String
    let chapterCount: Int
    let testament: Testament

    enum Testament: String {
        case old, new

        var displayName: String {
            switch self {
            case .old: "Old Testament"
            case .new: "New Testament"
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
}
