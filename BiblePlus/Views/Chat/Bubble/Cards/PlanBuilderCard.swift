import SwiftUI
import SwiftData

// MARK: - Custom Plan Builder Card
//
// Turns a conversation into a real, savable reading plan. The AI composes the
// plan in markup; the parser resolves it into actual PlanDay/PlanReading data;
// this card previews it and, on "Start", persists a ReadingPlan +
// UserPlanProgress — so it slots straight into the existing Plans tab, detail
// view, day view and reader deep-links with no special-casing.
//
//   [PLAN title="Steadied" topic="Anxiety"]
//   A Refuge to Run To | Psalm 46 | Where do you run when fear rises?
//   The Peace That Guards | Philippians 4:6-7 | What worry can you hand over?
//   [/PLAN]
struct PlanBuilderCard: View {
    let planId: String
    let title: String
    let category: String
    let days: [PlanDay]

    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    @State private var started = false

    private let maxVisibleDays = 4
    private let gradientHex = ["#B8923C", "#6B4F1E"]

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline
            dayList
            footer
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.12), lineWidth: 0.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [palette.accent.opacity(0.34), palette.accent.opacity(0.12)],
                                     startPoint: .top, endPoint: .bottom))
                .blur(radius: 18)
                .offset(y: 7)
        )
        .padding(.vertical, 10)
        .onAppear(perform: syncStartedState)
    }

    // MARK: Header

    // Clean, minimal header on the same surface as the rest of the card — a
    // quiet gold eyebrow, a bold serif title, and a subtle subheader. No
    // colored band.
    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 10, weight: .semibold))
                Text("CRAFTED FOR YOU").font(.system(size: 9.5, weight: .semibold)).tracking(2.2)
            }
            .foregroundStyle(palette.accent.opacity(0.78))

            Text(title)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    private var hairline: some View {
        Rectangle().fill(palette.border.opacity(0.14)).frame(height: 0.5)
    }

    private var subtitle: String {
        let dayLabel = "\(days.count)-day plan"
        return category.isEmpty ? dayLabel : "\(dayLabel) · \(category)"
    }

    // MARK: Day list

    private var dayList: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.prefix(maxVisibleDays))) { day in
                dayRow(day)
                if day.day != min(days.count, maxVisibleDays) {
                    Rectangle().fill(palette.border.opacity(0.12)).frame(height: 0.5)
                        .padding(.leading, 58)
                }
            }
            if days.count > maxVisibleDays {
                Text("+ \(days.count - maxVisibleDays) more day\(days.count - maxVisibleDays == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
            }
        }
        .padding(.vertical, 4)
    }

    private func dayRow(_ day: PlanDay) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.1))
                Text("\(day.day)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.title)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(day.readings.map { $0.displayReference }.joined(separator: "  ·  "))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    // MARK: Footer

    private var footer: some View {
        Button(action: start) {
            HStack(spacing: 6) {
                Image(systemName: started ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(started ? "Added to your plans" : "Start this plan")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(started ? palette.accent : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(started ? palette.accent.opacity(0.12) : palette.accent)
            )
        }
        .buttonStyle(.plain)
        .disabled(started)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    // MARK: Persistence

    private func syncStartedState() {
        let pid = planId
        let descriptor = FetchDescriptor<UserPlanProgress>(predicate: #Predicate { $0.planID == pid })
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            started = true
        }
    }

    private func start() {
        guard !started else { return }
        HapticService.success()

        let pid = planId
        let planDescriptor = FetchDescriptor<ReadingPlan>(predicate: #Predicate { $0.id == pid })
        if (try? modelContext.fetch(planDescriptor))?.isEmpty ?? true {
            modelContext.insert(makeReadingPlan())
        }
        modelContext.insert(UserPlanProgress(planID: pid))
        try? modelContext.save()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { started = true }
    }

    private func makeReadingPlan() -> ReadingPlan {
        ReadingPlan(
            id: planId,
            name: title,
            planDescription: "A reading plan crafted for you in conversation.",
            totalDays: days.count,
            category: category.isEmpty ? "For You" : category,
            gradientColors: gradientHex,
            iconName: "sparkles",
            imageKey: "",
            days: days,
            applicableSeasons: [],
            applicableBurdens: [],
            faithLevelMin: "justCurious",
            isProOnly: false,
            seedVersion: 1
        )
    }
}
