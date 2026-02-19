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
                        .font(.system(size: 11, weight: .bold, design: .rounded))
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
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3)

                        Text(reflection)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(palette.textSecondary)
                            .lineSpacing(6)
                            .italic()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(palette.surfaceElevated)
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(palette.border.opacity(0.12), lineWidth: 0.5)
                    )
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
                VStack(spacing: 0) {
                    ForEach(Array(day.readings.enumerated()), id: \.offset) { index, reading in
                        readingCard(reading)

                        if index < day.readings.count - 1 {
                            Rectangle()
                                .fill(palette.border.opacity(0.12))
                                .frame(height: 0.5)
                                .padding(.leading, 64)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surfaceElevated)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                )
                .padding(.horizontal, 24)

                // Reflect with AI
                Button {
                    let readings = day.readings.map(\.displayReference).joined(separator: ", ")
                    let reflection = day.reflection ?? ""
                    let context = "I'm reading \(plan.name) Day \(day.day). Today's readings: \(readings). The reflection is: \(reflection). Help me go deeper."
                    NotificationCenter.default.post(
                        name: .openAIWithContext,
                        object: nil,
                        userInfo: [
                            "context": context,
                            "title": "\(plan.name) \u{2014} Day \(day.day)",
                        ]
                    )
                    HapticService.lightImpact()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Reflect with AI")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
                    )
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
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.success.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.success.opacity(0.2), lineWidth: 0.5)
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
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
            HapticService.selection()
            guard let book = BibleData.book(id: reading.bookID) else { return }
            onReadChapter(book.name, reading.chapter)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.displayReference)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    if let book = BibleData.book(id: reading.bookID) {
                        Text(book.testament == .old ? "Old Testament" : "New Testament")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                }

                Spacer()

                Text("Read")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
