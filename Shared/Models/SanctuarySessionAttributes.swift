import ActivityKit
import Foundation

struct SanctuarySessionAttributes: ActivityAttributes {
    let soundscapeName: String

    struct ContentState: Codable, Hashable {
        let isPlaying: Bool
        let timerEndDate: Date?
    }
}
