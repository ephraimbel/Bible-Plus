import ActivityKit
import SwiftUI
import WidgetKit

struct SanctuarySessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SanctuarySessionAttributes.self) { context in
            // Lock Screen banner
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("Sanctuary")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(context.attributes.soundscapeName)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let endDate = context.state.timerEndDate {
                        Text(endDate, style: .timer)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 44)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.timerEndDate != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("Sleep timer active")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
            } compactTrailing: {
                if let endDate = context.state.timerEndDate {
                    Text(endDate, style: .timer)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minWidth: 36)
                } else {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<SanctuarySessionAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.43))

            VStack(alignment: .leading, spacing: 2) {
                Text("Sanctuary")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text(context.attributes.soundscapeName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Spacer()

            if let endDate = context.state.timerEndDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(endDate, style: .timer)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.12, green: 0.10, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
