import AppIntents
import WidgetKit

struct NextContentIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Content"
    static var description = IntentDescription("Show the next piece of content")

    func perform() async throws -> some IntentResult {
        let current = WidgetBackgroundService.loadContentOffset()
        WidgetBackgroundService.saveContentOffset(current + 1)
        WidgetCenter.shared.reloadTimelines(ofKind: "BiblePlusHomeWidget")
        return .result()
    }
}

struct PreviousContentIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Content"
    static var description = IntentDescription("Show the previous piece of content")

    func perform() async throws -> some IntentResult {
        let current = WidgetBackgroundService.loadContentOffset()
        WidgetBackgroundService.saveContentOffset(max(0, current - 1))
        WidgetCenter.shared.reloadTimelines(ofKind: "BiblePlusHomeWidget")
        return .result()
    }
}
