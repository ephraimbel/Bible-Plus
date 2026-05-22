import SwiftUI

struct TimelineCard: View {
    let events: [(label: String, reference: String, period: String)]

    @Environment(\.bpPalette) private var palette
    @State private var lineDrawn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("A TIMELINE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(palette.accent.opacity(0.7))
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 14)

            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                row(index: index, event: event)
            }

            Spacer().frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                lineDrawn = true
            }
        }
    }

    private func row(index: Int, event: (label: String, reference: String, period: String)) -> some View {
        let progress = events.count > 1 ? Double(index) / Double(events.count - 1) : 0
        let dotColor = Color(
            red: 0.79 - progress * 0.15,
            green: 0.66 - progress * 0.15,
            blue: 0.43 - progress * 0.1
        )

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(dotColor.opacity(0.2))
                            .frame(width: 16, height: 16)
                    )

                if index < events.count - 1 {
                    Rectangle()
                        .fill(palette.accent.opacity(0.2))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(y: lineDrawn ? 1 : 0, anchor: .top)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.15),
                            value: lineDrawn
                        )
                }
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.label)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(palette.textPrimary)

                HStack(spacing: 8) {
                    if !event.reference.isEmpty {
                        Text(event.reference)
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(palette.accent)
                    }
                    if !event.period.isEmpty {
                        Text(event.period)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(palette.accent.opacity(0.06))
                            )
                    }
                }
            }
            .padding(.bottom, index < events.count - 1 ? 16 : 0)
        }
        .padding(.horizontal, 16)
    }
}
