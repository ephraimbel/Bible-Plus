import ActivityKit
import SwiftUI
import WidgetKit

struct BibleSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BibleSessionAttributes.self) { context in
            // Lock Screen banner
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(context.attributes.bookName) \(context.attributes.chapter)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Verse \(context.state.currentVerse) of \(context.attributes.totalVerses)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.translationName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: Double(context.state.currentVerse),
                        total: Double(context.attributes.totalVerses)
                    )
                    .tint(Color(red: 0.79, green: 0.66, blue: 0.43)) // #C9A96E
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPlaying ? "book.fill" : "pause.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
            } compactTrailing: {
                Text("\(context.state.currentVerse)/\(context.attributes.totalVerses)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(
                            from: 0,
                            to: Double(context.state.currentVerse) / Double(max(context.attributes.totalVerses, 1))
                        )
                        .stroke(
                            Color(red: 0.79, green: 0.66, blue: 0.43),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "book.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                }
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<BibleSessionAttributes>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                Text("\(context.attributes.bookName) \(context.attributes.chapter)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(context.attributes.translationName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.15)))
            }

            HStack {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text("Verse \(context.state.currentVerse) of \(context.attributes.totalVerses)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }

            ProgressView(
                value: Double(context.state.currentVerse),
                total: Double(context.attributes.totalVerses)
            )
            .tint(Color(red: 0.79, green: 0.66, blue: 0.43))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.10),
                    Color(red: 0.14, green: 0.14, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
