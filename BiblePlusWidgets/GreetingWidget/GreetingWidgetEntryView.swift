import SwiftUI
import WidgetKit

struct GreetingWidgetEntryView: View {
    let entry: GreetingWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Row 1: Time icon + greeting
            HStack(spacing: 4) {
                Image(systemName: entry.timeIcon)
                    .font(.system(size: 12, weight: .semibold))

                Text("\(entry.greeting), \(entry.firstName)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }

            // Row 2: Encouragement
            Text(entry.encouragement)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
