import SwiftUI

struct PlanDayView: View {
    let plan: ReadingPlan
    let day: PlanDay
    let isDayCompleted: Bool
    @Bindable var viewModel: ReadingPlansViewModel
    let isPro: Bool
    let onReadChapter: (String, Int) -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    private var progress: UserPlanProgress? {
        viewModel.progressForPlan(plan.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Day header
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAY \(day.day)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(palette.accent)

                    Text(day.title)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Reflection prompt
                if let reflection = day.reflection, !reflection.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(palette.accent)
                            .frame(width: 3)

                        Text(reflection)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(palette.textSecondary)
                            .lineSpacing(6)
                            .italic()
                    }
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
                }

                // Readings header
                Text("TODAY'S READINGS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 24)

                // Reading cards
                VStack(spacing: 12) {
                    ForEach(Array(day.readings.enumerated()), id: \.offset) { _, reading in
                        readingCard(reading)
                    }
                }
                .padding(.horizontal, 24)

                // Mark complete / status
                completionSection
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationTitle("Day \(day.day)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Completion Section

    @ViewBuilder
    private var completionSection: some View {
        if isDayCompleted {
            // Already completed
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(palette.success)
                Text("Day Completed")
                    .font(BPFont.button)
                    .foregroundStyle(palette.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.success.opacity(0.12))
            )
        } else if let progress {
            // Plan started — can mark complete
            GoldButton(title: "Mark Day \(day.day) Complete", showGlow: true) {
                viewModel.completeDay(progress: progress, day: day.day, totalDays: plan.totalDays)
                dismiss()
            }
        } else {
            // Plan not started yet — prompt to start
            VStack(spacing: 12) {
                Text("Start this plan to track your progress")
                    .font(BPFont.caption)
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)

                GoldButton(title: "Start Plan") {
                    viewModel.startPlan(plan, isPro: isPro)
                }
            }
        }
    }

    // MARK: - Reading Card

    private func readingCard(_ reading: PlanReading) -> some View {
        Button {
            guard let book = BibleData.book(id: reading.bookID) else { return }
            onReadChapter(book.name, reading.chapter)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(palette.accentSoft)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.displayReference)
                        .font(BPFont.button)
                        .foregroundStyle(palette.textPrimary)

                    if let book = BibleData.book(id: reading.bookID) {
                        Text(book.testament == .old ? "Old Testament" : "New Testament")
                            .font(BPFont.caption)
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer()

                Text("Read")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(palette.accent.opacity(0.12))
                    )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
