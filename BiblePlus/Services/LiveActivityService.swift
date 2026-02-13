import ActivityKit
import Foundation

enum LiveActivityService {
    // MARK: - Bible Audio Session

    @discardableResult
    static func startBibleSession(
        bookName: String,
        chapter: Int,
        translationName: String,
        totalVerses: Int,
        currentVerse: Int
    ) -> Activity<BibleSessionAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let attributes = BibleSessionAttributes(
            bookName: bookName,
            chapter: chapter,
            translationName: translationName,
            totalVerses: totalVerses
        )
        let state = BibleSessionAttributes.ContentState(
            currentVerse: currentVerse,
            isPlaying: true
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            return try Activity.request(attributes: attributes, content: content)
        } catch {
            return nil
        }
    }

    static func updateBibleSession(
        _ activity: Activity<BibleSessionAttributes>,
        currentVerse: Int,
        isPlaying: Bool
    ) {
        let state = BibleSessionAttributes.ContentState(
            currentVerse: currentVerse,
            isPlaying: isPlaying
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    static func endBibleSession(_ activity: Activity<BibleSessionAttributes>) {
        let state = BibleSessionAttributes.ContentState(
            currentVerse: 0,
            isPlaying: false
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Sanctuary Session

    @discardableResult
    static func startSanctuarySession(
        soundscapeName: String,
        timerDuration: TimeInterval?
    ) -> Activity<SanctuarySessionAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let attributes = SanctuarySessionAttributes(soundscapeName: soundscapeName)
        let timerEndDate = timerDuration.map { Date().addingTimeInterval($0) }
        let state = SanctuarySessionAttributes.ContentState(
            isPlaying: true,
            timerEndDate: timerEndDate
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            return try Activity.request(attributes: attributes, content: content)
        } catch {
            return nil
        }
    }

    static func updateSanctuarySession(
        _ activity: Activity<SanctuarySessionAttributes>,
        isPlaying: Bool,
        timerEndDate: Date?
    ) {
        let state = SanctuarySessionAttributes.ContentState(
            isPlaying: isPlaying,
            timerEndDate: timerEndDate
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    static func endSanctuarySession(_ activity: Activity<SanctuarySessionAttributes>) {
        let state = SanctuarySessionAttributes.ContentState(
            isPlaying: false,
            timerEndDate: nil
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }
}
