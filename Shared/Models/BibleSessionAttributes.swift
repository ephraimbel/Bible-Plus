import ActivityKit
import Foundation

struct BibleSessionAttributes: ActivityAttributes {
    // All fields live in ContentState (dynamic) so a single Live Activity can
    // be UPDATED as audio auto-advances from chapter to chapter — instead of
    // being ended and recreated each chapter, which made a dismissed activity
    // keep reappearing.
    struct ContentState: Codable, Hashable {
        var bookName: String
        var chapter: Int
        var translationName: String
        var totalVerses: Int
        var currentVerse: Int
        var isPlaying: Bool
    }
}
