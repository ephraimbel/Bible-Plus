import SwiftUI
import WidgetKit

struct ChaptersWidgetEntryView: View {
    let entry: ChaptersWidgetEntry

    var body: some View {
        let fraction = entry.weeklyGoal > 0
            ? min(Double(entry.chaptersThisWeek) / Double(entry.weeklyGoal), 1.0)
            : 0

        Gauge(value: fraction) {
            Image(systemName: "book.fill")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text("\(entry.chaptersThisWeek)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(URL(string: "bibleplus://progress"))
    }
}
