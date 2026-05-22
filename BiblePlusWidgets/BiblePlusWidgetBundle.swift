import SwiftUI
import WidgetKit

@main
struct BiblePlusWidgetBundle: WidgetBundle {
    init() {
        // Widgets run in a separate process and don't pick up the main app's
        // LocalizationService swizzle. Mirror the same Bundle override here
        // so widget text renders in the user's chosen language. Reads the
        // same `UserDefaults` key the app writes to (via LocalizationService).
        // Falls back to English (the source language) when nothing's set or
        // when the target `.lproj` isn't shipped — no crash, no blank labels.
        let code = UserDefaults.standard.string(forKey: "io.bibleplus.selectedLanguageCode")
        Bundle.setLanguage(code)
    }

    var body: some Widget {
        BiblePlusHomeWidget()
        BiblePlusLockScreenWidget()
        StreakWidget()
        PlanProgressWidget()
        ActivityGridWidget()
        ChaptersWidget()
        QuickActionsWidget()
        DashboardWidget()
        StreakDotsWidget()
        GreetingWidget()
        BibleSessionLiveActivity()
        SanctuarySessionLiveActivity()
    }
}
