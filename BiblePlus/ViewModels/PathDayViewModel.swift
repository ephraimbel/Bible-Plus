import Foundation
import SwiftData

@MainActor
@Observable
final class PathDayViewModel {
    let path: DailyPath
    let dayNumber: Int
    var reflectionText: String = ""
    var selectedQuizOptionIndex: Int? = nil
    var quizRevealed: Bool = false

    private let modelContext: ModelContext
    private let progress: UserPathProgress

    var day: PathDay? {
        path.day(dayNumber)
    }

    var isAlreadyCompleted: Bool {
        progress.completedDays.contains(dayNumber)
    }

    /// True after `markDayComplete()` finishes a day that fills the path —
    /// i.e. the user just finished the whole journey. Drives whether the
    /// session shows the day celebration or the larger path celebration.
    var progressIsCompleted: Bool {
        progress.completedDate != nil
    }

    var quizCorrect: Bool? {
        guard let selected = selectedQuizOptionIndex,
              let day else { return nil }
        return selected == day.quiz.correctIndex
    }

    init(path: DailyPath, dayNumber: Int, progress: UserPathProgress, modelContext: ModelContext) {
        self.path = path
        self.dayNumber = dayNumber
        self.progress = progress
        self.modelContext = modelContext
        self.reflectionText = progress.reflection(for: dayNumber) ?? ""
    }

    func saveReflection() {
        progress.setReflection(reflectionText, for: dayNumber)
        try? modelContext.save()
    }

    func selectQuizOption(_ index: Int) {
        guard !quizRevealed else { return }
        selectedQuizOptionIndex = index
        quizRevealed = true
        if let correct = quizCorrect {
            progress.recordQuizResult(correct, for: dayNumber)
            try? modelContext.save()
            Analytics.track(.pathQuizAnswered, properties: [
                "path_id": path.id,
                "day": "\(dayNumber)",
                "correct": "\(correct)"
            ])
        }
    }

    func markDayComplete() {
        saveReflection()
        let wasAlreadyComplete = progress.completedDays.contains(dayNumber)
        if !wasAlreadyComplete {
            progress.completedDays.append(dayNumber)
            progress.completedDays.sort()
            // Stamp the daily-gate clock only on a genuinely new completion so
            // re-reading a finished day never consumes today's allowance.
            progress.lastNewDayCompletedDate = Date()
        }
        progress.lastActiveDate = Date()
        progress.setPartialDay(nil)

        let justFinishedPath = progress.completedDays.count >= path.totalDays
            && progress.completedDate == nil
        if justFinishedPath {
            progress.completedDate = Date()
            progress.isActive = false
        }

        ActivityService.log(
            .planDayCompleted,
            detail: "\(path.name) — Day \(dayNumber)",
            in: modelContext
        )
        try? modelContext.save()

        // Analytics — fire after save so the funnel events reflect persisted
        // state. Skip pathDayCompleted on re-completes (revisiting an already
        // finished day shouldn't double-count).
        if !wasAlreadyComplete {
            Analytics.track(.pathDayCompleted, properties: [
                "path_id": path.id,
                "day": "\(dayNumber)",
                "total_days": "\(path.totalDays)"
            ])
        }
        if justFinishedPath {
            Analytics.track(.pathCompleted, properties: [
                "path_id": path.id,
                "path_name": path.name,
                "total_days": "\(path.totalDays)"
            ])
        }
        // Path-complete → cancel the reminder until a new path starts.
        // Day-complete (not whole path) → re-schedule so tomorrow's
        // reminder reflects the same path that's still in progress.
        NotificationService.shared.refreshDailyPathReminder(modelContext: modelContext)
    }
}
