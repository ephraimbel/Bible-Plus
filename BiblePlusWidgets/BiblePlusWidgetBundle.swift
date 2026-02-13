import SwiftUI
import WidgetKit

@main
struct BiblePlusWidgetBundle: WidgetBundle {
    var body: some Widget {
        BiblePlusHomeWidget()
        BiblePlusLockScreenWidget()
        BibleSessionLiveActivity()
        SanctuarySessionLiveActivity()
    }
}
