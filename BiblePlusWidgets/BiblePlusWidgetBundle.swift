import SwiftUI
import WidgetKit

@main
struct BiblePlusWidgetBundle: WidgetBundle {
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
