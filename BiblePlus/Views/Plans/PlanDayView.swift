import SwiftUI

struct PlanDayView: View {
    let plan: ReadingPlan
    @Bindable var viewModel: ReadingPlansViewModel
    let isPro: Bool

    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    // Day shown is mutable so the "Continue" action in the Up Next sheet can
    // advance the view in place without forcing a navigation push/pop dance.
    @State private var currentDay: PlanDay
    @State private var isEditingReflection = false
    @State private var reflectionDraft = ""
    @FocusState private var reflectionFocused: Bool
    @State private var showUpNext = false
    /// Plan days decoded once at init so `nextDayData` and any future
    /// day lookups never re-run the JSON decoder on each body eval.
    @State private var days: [PlanDay]

    init(plan: ReadingPlan, day: PlanDay, viewModel: ReadingPlansViewModel, isPro: Bool) {
        self.plan = plan
        self.viewModel = viewModel
        self.isPro = isPro
        self._currentDay = State(wrappedValue: day)
        self._days = State(wrappedValue: plan.days)
    }

    private var progress: UserPlanProgress? {
        viewModel.latestProgressForPlan(plan.id)
    }

    private var isDayCompleted: Bool {
        progress?.completedDays.contains(currentDay.day) ?? false
    }

    private var savedReflection: String? {
        progress?.reflection(for: currentDay.day)
    }

    /// The day the user would move to after marking `currentDay` complete.
    /// Nil when `currentDay` is the plan's final day (plan completion handles it).
    private var nextDayData: PlanDay? {
        guard currentDay.day < plan.totalDays else { return nil }
        return days.first(where: { $0.day == currentDay.day + 1 })
    }

    var body: some View {
        let _ = viewModel.refreshToken
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dayHeader
                        .id("top")

                    if let reflection = currentDay.reflection, !reflection.isEmpty {
                        reflectionPromptCard(reflection)
                    }

                    reflectionSection

                    readingsHeader

                    readingsList

                    reflectWithAIButton

                    completionSection
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .onChange(of: currentDay.day) { _, _ in
                // When the Up Next sheet advances us to the next day, reset
                // scroll so the new day reads from the top, not wherever the
                // user left off on the completed day.
                withAnimation(BPAnimation.spring) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .background(palette.background)
        .navigationTitle("Day \(currentDay.day)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { reflectionFocused = false }
                    .foregroundStyle(palette.accent)
            }
        }
        .sheet(isPresented: $showUpNext) {
            upNextSheet
                .presentationDetents([.fraction(0.65), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .animation(BPAnimation.spring, value: currentDay.day)
        .animation(BPAnimation.spring, value: isEditingReflection)
    }

    // MARK: - Day Header

    /// Colors derived from the plan's gradientColors. Falls back to the palette
    /// accent when a plan doesn't ship gradient hex. Used to tint the day-view
    /// header so each plan carries its identity through to the reading surface.
    private var planGradient: LinearGradient {
        let colors = plan.gradientColors.isEmpty
            ? [palette.accent, palette.accent.opacity(0.85)]
            : plan.gradientColors.map { Color(hex: $0) }
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                // Plan-gradient chip carries plan identity into the day view —
                // every plan reads the same, but *looks* unmistakably its own.
                Text("DAY \(currentDay.day) · OF \(plan.totalDays)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(planGradient)
                            .shadow(
                                color: (plan.gradientColors.first.map(Color.init(hex:)) ?? palette.accent).opacity(0.28),
                                radius: 5, y: 2
                            )
                    )
                    .overlay(
                        Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5)
                    )

                if isDayCompleted {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("COMPLETE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                    }
                    .foregroundStyle(palette.success)
                }

                Spacer()

                if isMilestoneDay(currentDay.day) {
                    milestoneChip
                }
            }

            // Plan-name breadcrumb — lightweight, serif, ties the day to the
            // plan it came from. Helps when the user deep-links in from
            // a widget or reopens mid-plan and forgets which plan this is.
            Text(plan.name.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(palette.textMuted.opacity(0.8))
                .lineLimit(1)

            Text(currentDay.title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var milestoneChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 8, weight: .bold))
            Text("MILESTONE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(palette.accent.opacity(0.12))
        )
    }

    // MARK: - Reflection Prompt

    private func reflectionPromptCard(_ reflection: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 8, weight: .bold))
                    Text("REFLECTION PROMPT")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(palette.accent.opacity(0.7))

                Text(reflection)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textSecondary)
                    .lineSpacing(6)
                    .italic()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Reflection Section (inline editor / saved view)

    @ViewBuilder
    private var reflectionSection: some View {
        // Skip entirely when there is no prompt — the plan author didn't intend
        // journaling on this day. Also skip when the plan hasn't been started,
        // since journaling requires a progress row to persist against; showing
        // the editor without one would let the user type and tap Save to no
        // effect.
        if let promptText = currentDay.reflection,
           !promptText.isEmpty,
           progress != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle().fill(palette.accent.opacity(0.1))
                        )

                    Text("YOUR REFLECTION")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(palette.textMuted)

                    if savedReflection != nil, !isEditingReflection {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.success.opacity(0.7))
                    }

                    VStack { Divider() }
                        .padding(.leading, 4)
                }

                if isEditingReflection {
                    editorCard
                } else if let saved = savedReflection {
                    savedCard(saved)
                } else {
                    emptyStatePill
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var emptyStatePill: some View {
        Button {
            beginEditing(with: "")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
                Text("Write your reflection")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.4)
            }
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        palette.accent.opacity(0.18),
                        style: StrokeStyle(lineWidth: 0.8, dash: [4, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var editorCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if reflectionDraft.isEmpty {
                    Text("Let the Spirit lead your thoughts…")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(palette.textMuted.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $reflectionDraft)
                    .focused($reflectionFocused)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 140)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.25), lineWidth: 0.8)
            )

            HStack(spacing: 10) {
                Button {
                    cancelEditing()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(palette.surface)
                        )
                }

                Button {
                    saveReflection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Save")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 2)
                }
                .disabled(reflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(reflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
        }
    }

    private func savedCard(_ text: String) -> some View {
        Button {
            beginEditing(with: text)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(palette.surface))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func beginEditing(with text: String) {
        reflectionDraft = text
        isEditingReflection = true
        HapticService.lightImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            reflectionFocused = true
        }
    }

    private func cancelEditing() {
        reflectionFocused = false
        isEditingReflection = false
        reflectionDraft = ""
    }

    private func saveReflection() {
        guard let progress else { return }
        viewModel.saveReflection(reflectionDraft, for: currentDay.day, progress: progress)
        reflectionFocused = false
        isEditingReflection = false
        reflectionDraft = ""
        HapticService.success()
    }

    // MARK: - Readings

    private var readingsHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(palette.accent.opacity(0.1)))

            Text("TODAY'S READINGS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            VStack { Divider() }
                .padding(.leading, 4)
        }
        .padding(.horizontal, 24)
    }

    private var readingsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(currentDay.readings.enumerated()), id: \.offset) { index, reading in
                readingCard(reading)

                if index < currentDay.readings.count - 1 {
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
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
    }

    private func readingCard(_ reading: PlanReading) -> some View {
        NavigationLink {
            PlanChapterReaderView(reading: reading)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.05))
                        .frame(width: 42, height: 42)
                    Circle()
                        .fill(palette.accent.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.accent)
                }

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

    // MARK: - Reflect with AI

    private var reflectWithAIButton: some View {
        Button {
            let readings = currentDay.readings.map(\.displayReference).joined(separator: ", ")
            let promptText = currentDay.reflection ?? ""
            let userReflection = savedReflection.map { " I wrote: \"\($0)\"." } ?? ""
            let context = "I'm reading \(plan.name) Day \(currentDay.day). Today's readings: \(readings). The reflection prompt is: \(promptText).\(userReflection) Help me go deeper."
            NotificationCenter.default.post(
                name: .openAIWithContext,
                object: nil,
                userInfo: [
                    "context": context,
                    "title": "\(plan.name) \u{2014} Day \(currentDay.day)",
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
    }

    // MARK: - Completion Section

    @ViewBuilder
    private var completionSection: some View {
        if isDayCompleted {
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
            GoldButton(title: "Mark Day \(currentDay.day) Complete", showGlow: true) {
                let wasLastDay = currentDay.day >= plan.totalDays
                viewModel.completeDay(
                    progress: progress,
                    day: currentDay.day,
                    totalDays: plan.totalDays
                )
                // Plan-level completion is handled by the parent — just
                // dismiss back to detail so the parent's overlay fires.
                if wasLastDay {
                    dismiss()
                } else if nextDayData != nil {
                    showUpNext = true
                }
            }
        } else {
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

    // MARK: - Up Next Sheet

    @ViewBuilder
    private var upNextSheet: some View {
        if let next = nextDayData {
            UpNextSheetView(
                plan: plan,
                completedDay: currentDay.day,
                nextDay: next,
                milestonePercent: viewModel.consumePendingMilestone(planID: plan.id),
                onContinue: {
                    showUpNext = false
                    withAnimation(BPAnimation.spring) {
                        currentDay = next
                    }
                },
                onBackToPlan: {
                    showUpNext = false
                    dismiss()
                }
            )
        }
    }

    // MARK: - Helpers

    private func isMilestoneDay(_ day: Int) -> Bool {
        let total = plan.totalDays
        guard total >= 8 else { return false }
        for pct in [25, 50, 75] {
            let target = Int(((Double(pct) / 100.0) * Double(total)).rounded())
            if target == day { return true }
        }
        return false
    }
}

// MARK: - Up Next Sheet View

private struct UpNextSheetView: View {
    let plan: ReadingPlan
    let completedDay: Int
    let nextDay: PlanDay
    let milestonePercent: Int?
    let onContinue: () -> Void
    let onBackToPlan: () -> Void

    @Environment(\.bpPalette) private var palette
    @State private var showHero = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 12)

                // Hero — checkmark ring
                ZStack {
                    Circle()
                        .stroke(palette.success.opacity(0.12), lineWidth: 1)
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(palette.success.opacity(0.08))
                        .frame(width: 92, height: 92)
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(palette.success)
                        .shadow(color: palette.success.opacity(0.35), radius: 12)
                }
                .scaleEffect(showHero ? 1 : 0.3)
                .opacity(showHero ? 1 : 0)

                VStack(spacing: 10) {
                    Text("DAY \(completedDay) COMPLETE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(palette.textMuted)

                    progressTrail

                    if let pct = milestonePercent {
                        milestoneRibbon(pct)
                            .padding(.top, 2)
                    }
                }
                .opacity(showHero ? 1 : 0)

                Divider()
                    .padding(.horizontal, 40)

                // Up Next teaser
                VStack(spacing: 10) {
                    Text("UP NEXT · DAY \(nextDay.day)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(palette.accent)

                    Text(nextDay.title)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let firstReading = nextDay.readings.first {
                        Text(firstReading.displayReference)
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .opacity(showHero ? 1 : 0)
                .offset(y: showHero ? 0 : 12)

                // CTAs
                VStack(spacing: 10) {
                    GoldButton(title: "Continue to Day \(nextDay.day)", showGlow: true) {
                        onContinue()
                    }

                    Button {
                        onBackToPlan()
                    } label: {
                        Text("Back to Plan")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .opacity(showHero ? 1 : 0)

                Spacer(minLength: 8)
            }
            .padding(.bottom, 20)
        }
        .background(palette.background)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05)) {
                showHero = true
            }
        }
    }

    /// Compact dot trail for plans with ≤14 days; a slim progress bar for
    /// longer plans. Filled segments up through `completedDay`, outlined
    /// thereafter — reads as a momentum cue ("you're here").
    private var progressTrail: some View {
        Group {
            if plan.totalDays <= 14 {
                HStack(spacing: 6) {
                    ForEach(1...plan.totalDays, id: \.self) { n in
                        Circle()
                            .fill(n <= completedDay ? palette.accent : Color.clear)
                            .overlay(
                                Circle()
                                    .stroke(
                                        n <= completedDay
                                            ? palette.accent
                                            : palette.textMuted.opacity(0.3),
                                        lineWidth: 0.8
                                    )
                            )
                            .frame(width: 7, height: 7)
                    }
                }
            } else {
                let frac = Double(completedDay) / Double(max(1, plan.totalDays))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.textMuted.opacity(0.18))
                            .frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * frac), height: 3)
                    }
                }
                .frame(width: 160, height: 3)
            }
        }
    }

    private func milestoneRibbon(_ pct: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
            Text(milestoneLabel(pct))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
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
                .shadow(color: palette.accent.opacity(0.35), radius: 6, y: 2)
        )
    }

    private func milestoneLabel(_ pct: Int) -> String {
        switch pct {
        case 25: return "A quarter of the way!"
        case 50: return "Halfway there — keep going."
        case 75: return "Three quarters done. Almost home."
        default: return "\(pct)% complete"
        }
    }
}
