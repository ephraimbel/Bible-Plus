import ActivityKit
import Foundation

struct BibleSessionAttributes: ActivityAttributes {
    let bookName: String
    let chapter: Int
    let translationName: String
    let totalVerses: Int

    struct ContentState: Codable, Hashable {
        let currentVerse: Int
        let isPlaying: Bool
    }
}
