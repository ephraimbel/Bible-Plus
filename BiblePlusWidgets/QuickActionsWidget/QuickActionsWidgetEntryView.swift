import SwiftUI
import WidgetKit

struct QuickActionsWidgetEntryView: View {
    let entry: QuickActionsEntry

    private let actions: [(icon: String, label: String, url: String)] = [
        ("book.fill", "Read", "bibleplus://bible"),
        ("calendar", "Plan", "bibleplus://plans"),
        ("bubble.left.fill", "Ask", "bibleplus://ask"),
        ("moon.stars", "Sanctuary", "bibleplus://sanctuary"),
    ]

    var body: some View {
        ZStack {
            WidgetBackgroundView(gradientColors: entry.backgroundGradient)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    actionCell(actions[0])
                    divider(vertical: true)
                    actionCell(actions[1])
                }

                divider(vertical: false)

                HStack(spacing: 0) {
                    actionCell(actions[2])
                    divider(vertical: true)
                    actionCell(actions[3])
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func actionCell(_ action: (icon: String, label: String, url: String)) -> some View {
        Link(destination: URL(string: action.url) ?? URL(string: "bibleplus://")!) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)

                Text(action.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    @ViewBuilder
    private func divider(vertical: Bool) -> some View {
        if vertical {
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(width: 0.5)
        } else {
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}
