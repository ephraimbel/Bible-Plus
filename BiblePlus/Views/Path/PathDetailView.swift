import SwiftUI
import SwiftData

struct PathDetailView: View {
    let path: DailyPath
    @Bindable var homeVM: DailyPathHomeViewModel
    let isPro: Bool

    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDayNumber: Int?
    @State private var showPaywall: Bool = false
    @State private var showIntro: Bool = false
    @State private var showLibrary: Bool = false
    @State private var days: [PathDay] = []
    @State private var chapters: [PathChapter] = []
    /// Total devotional days a free user has finished across every path. Cached
    /// here and refreshed on appear + after each completion so the global free
    /// trial doesn't re-fetch on every row render.
    @State private var freeDaysUsed: Int = 0

    /// Free users get this many devotional days across the whole app, ever.
    /// After that, every further day — the next day of this path or day 1 of
    /// any other path — is behind the paywall.
    private let freeTrialLimit = 3

    private func isDayLocked(_ dayNumber: Int) -> Bool {
        if isPro { return false }
        if path.isProOnly { return true }
        // Global free trial. Already-completed days are caught as `.completed`
        // in `dayGate` before this runs, so re-reads always stay free; this
        // only gates brand-new days once the 3-day trial is spent.
        return freeDaysUsed >= freeTrialLimit
    }

    private func refreshFreeDaysUsed() {
        guard !isPro else { freeDaysUsed = 0; return }
        let all = (try? modelContext.fetch(FetchDescriptor<UserPathProgress>())) ?? []
        freeDaysUsed = all.reduce(0) { $0 + $1.completedDays.count }
    }

    // One-day-per-day pacing. A day is openable if it's already done (re-read)
    // or it's today's next day and no new day was finished yet today. The next
    // day after you've done one today, and any day beyond it, stay visible as a
    // roadmap but don't open until tomorrow.
    private enum DayGate {
        case completed          // finished — re-readable anytime
        case availableToday     // today's day, ready now
        case lockedUntilTomorrow // next day, but a new day was already done today
        case future             // beyond the next day
        case proLocked          // behind the paywall
    }

    private var completedNewDayToday: Bool {
        homeVM.progress?.completedNewDayToday() ?? false
    }

    private func dayGate(_ dayNumber: Int) -> DayGate {
        if completedSet.contains(dayNumber) { return .completed }
        if isDayLocked(dayNumber) { return .proLocked }
        if dayNumber == nextDayNumber {
            return completedNewDayToday ? .lockedUntilTomorrow : .availableToday
        }
        return .future
    }

    private func openDay(_ dayNumber: Int) {
        switch dayGate(dayNumber) {
        case .completed, .availableToday:
            Analytics.track(.pathDayOpened, properties: [
                "path_id": path.id,
                "day": "\(dayNumber)"
            ])
            selectedDayNumber = dayNumber
        case .proLocked:
            HapticService.lightImpact()
            Analytics.track(.pathPaywallShown, properties: [
                "path_id": path.id,
                "trigger": path.isProOnly ? "pro_only_path" : "free_trial_exhausted",
                "day": "\(dayNumber)"
            ])
            showPaywall = true
        case .lockedUntilTomorrow, .future:
            // Held by the daily pace — a gentle nudge, no open.
            HapticService.invalid()
        }
    }

    private var nextDayNumber: Int {
        homeVM.progress?.nextDay(totalDays: path.totalDays) ?? 1
    }

    private var completedSet: Set<Int> {
        Set(homeVM.completedDayNumbers)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroHeader
                    ctaButton
                    dayList
                }
                .padding(.bottom, 40)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticService.lightImpact()
                        showLibrary = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .accessibilityLabel("Browse all journeys")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
            .onAppear {
                days = path.days
                chapters = path.chapters
                refreshFreeDaysUsed()
                // Show the intro the first time a user opens this specific
                // path AND they haven't started it yet. Once they've started
                // (or explicitly dismissed the intro), it won't show again
                // for this path. Per-path tracking means each new path the
                // user discovers gets its own intro moment.
                if !homeVM.hasStarted && !PathIntroState.hasSeenIntro(for: path.id) {
                    showIntro = true
                }
            }
            .sheet(item: $selectedDayNumber.boxed) { boxed in
                if let progress = homeVM.ensureProgress(modelContext: modelContext) {
                    PathDaySessionView(
                        path: path,
                        dayNumber: boxed.value,
                        progress: progress,
                        onComplete: {
                            homeVM.refresh(modelContext: modelContext, profile: nil)
                            refreshFreeDaysUsed()
                            selectedDayNumber = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallContainerView()
            }
            .sheet(isPresented: $showLibrary) {
                PathLibraryView(isPro: isPro)
            }
            .fullScreenCover(isPresented: $showIntro) {
                PathIntroOverlay(
                    path: path,
                    onBegin: {
                        PathIntroState.markIntroSeen(for: path.id)
                        showIntro = false
                        // Slight delay so the cover dismissal animation
                        // finishes cleanly before presenting the day sheet.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            openDay(nextDayNumber)
                        }
                    },
                    onDismiss: {
                        PathIntroState.markIntroSeen(for: path.id)
                        showIntro = false
                    }
                )
            }
        }
    }

    // MARK: - Hero
    //
    // No gradient block — the header sits directly on the warm-paper canvas
    // and blends with the scroll background. A quiet accent eyebrow, the path
    // name in serif, the description, and a thin meta line. Minimal by intent:
    // the day list below is the substance; the header just names the journey.

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: path.iconName.isEmpty ? "leaf.fill" : path.iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text("DAILY PATH")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.8)
            }
            .foregroundStyle(palette.accent)

            Text(path.name)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.85)
                .lineLimit(2)

            Text(path.pathDescription)
                .font(.system(size: 16, design: .serif))
                .italic()
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Text("\(path.totalDays) days")
                Text("·")
                Text("about 5 minutes a day")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.textMuted)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        let gate = dayGate(nextDayNumber)
        let enabled = gate != .lockedUntilTomorrow
        return VStack(spacing: 10) {
            Button {
                HapticService.lightImpact()
                openDay(gate == .completed ? 1 : nextDayNumber)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: ctaIcon(gate))
                    Text(ctaLabel(gate))
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.accent.opacity(enabled ? 1 : 0.4))
                )
            }
            .buttonStyle(.plain)
            .disabled(!enabled)

            if gate == .lockedUntilTomorrow {
                Text("You've done today's reading. The next day opens tomorrow.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }

    private func ctaIcon(_ gate: DayGate) -> String {
        switch gate {
        case .proLocked: return "lock.fill"
        case .lockedUntilTomorrow: return "checkmark.circle.fill"
        case .completed: return "arrow.counterclockwise"
        case .availableToday: return homeVM.hasStarted ? "arrow.right.circle.fill" : "play.circle.fill"
        case .future: return "arrow.right.circle.fill"
        }
    }

    private func ctaLabel(_ gate: DayGate) -> String {
        switch gate {
        case .proLocked: return "Continue with Pro"
        case .lockedUntilTomorrow: return "Come back tomorrow"
        case .completed: return "Revisit this path"
        case .availableToday: return homeVM.hasStarted ? "Resume Day \(nextDayNumber)" : "Begin Day 1"
        case .future: return "Resume Day \(nextDayNumber)"
        }
    }

    // MARK: - Day List
    //
    // When the path defines chapters, the day list is grouped by chapter with
    // section headers. The grouping makes a 14-day arc legible as a journey
    // (e.g. "Days 1-3 · Naming the anxiety" → "Days 4-7 · Receiving peace")
    // rather than a 14-row flat scroll. When no chapters are defined the
    // header collapses to a single "Your Path" label and days render flat.

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 18) {
            if chapters.isEmpty {
                flatDayList
            } else {
                groupedDayList
            }
        }
    }

    private var flatDayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Path")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(days) { day in
                    dayRow(day)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var groupedDayList: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                chapterSection(index: index, chapter: chapter)
            }
        }
    }

    private func chapterSection(index: Int, chapter: PathChapter) -> some View {
        let chapterDays = days.filter { chapter.contains($0.day) }
        let allDone = chapterDays.allSatisfy { completedSet.contains($0.day) }
        let containsCurrent = chapterDays.contains { $0.day == nextDayNumber }
        let isUntouched = !allDone && !containsCurrent

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(palette.accent.opacity(allDone ? 0.55 : (containsCurrent ? 1.0 : 0.55)))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(palette.accent.opacity(containsCurrent ? 0.15 : 0.06))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(isUntouched ? palette.textSecondary : palette.textPrimary)

                    Text(chapter.dayRangeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(palette.textMuted)
                }

                Spacer(minLength: 0)

                if allDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(chapterDays) { day in
                    dayRow(day)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func dayRow(_ day: PathDay) -> some View {
        let gate = dayGate(day.day)
        let isCompleted = gate == .completed
        let isCurrent = gate == .availableToday
        let proLocked = gate == .proLocked
        let heldTomorrow = gate == .lockedUntilTomorrow
        let dimmed = gate == .future || heldTomorrow || proLocked
        let savedReflection = isCompleted
            && (homeVM.progress?.reflection(for: day.day)?.isEmpty == false)

        let a11yLabel: String = {
            let stateWord: String
            switch gate {
            case .completed: stateWord = "completed"
            case .proLocked: stateWord = "locked, requires Pro"
            case .availableToday: stateWord = "today"
            case .lockedUntilTomorrow: stateWord = "available tomorrow"
            case .future: stateWord = "upcoming"
            }
            let themePart = day.themeLabel.map { ". \($0)" } ?? ""
            let reflectionPart = savedReflection ? ". Reflection saved" : ""
            return "Day \(day.day), \(stateWord)\(themePart)\(reflectionPart)"
        }()

        return Button {
            openDay(day.day)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? palette.accent : (isCurrent ? palette.accent.opacity(0.15) : Color.clear))
                        .frame(width: 32, height: 32)
                    Circle()
                        .strokeBorder(palette.border.opacity(isCurrent ? 0.9 : 0.4), lineWidth: 1)
                        .frame(width: 32, height: 32)
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else if proLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.textMuted)
                    } else {
                        Text("\(day.day)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isCurrent ? palette.accent : palette.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(day.day)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(dimmed ? palette.textMuted : palette.textPrimary)
                    if let label = day.themeLabel {
                        Text(label)
                            .font(.system(size: 13))
                            .foregroundStyle(dimmed ? palette.textMuted.opacity(0.7) : palette.textSecondary)
                            .lineLimit(1)
                    }

                    if savedReflection {
                        HStack(spacing: 4) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Reflection saved")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(palette.textMuted)
                        .padding(.top, 1)
                    }
                }

                Spacer(minLength: 0)

                trailingAccessory(gate: gate)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(palette.border.opacity(isCurrent ? 0.7 : 0.3), lineWidth: isCurrent ? 1.2 : 0.5)
                    )
            )
            .opacity(dimmed ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(accessibilityHint(for: gate))
    }

    @ViewBuilder
    private func trailingAccessory(gate: DayGate) -> some View {
        switch gate {
        case .proLocked:
            pill("PRO")
        case .lockedUntilTomorrow:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                Text("TOMORROW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
            }
            .foregroundStyle(palette.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(palette.surface))
        case .future:
            EmptyView()
        case .completed, .availableToday:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(palette.accent.opacity(0.12)))
    }

    private func accessibilityHint(for gate: DayGate) -> String {
        switch gate {
        case .proLocked: return "Opens paywall"
        case .lockedUntilTomorrow: return "Opens tomorrow"
        case .future: return "Not yet available"
        case .completed, .availableToday: return "Opens day session"
        }
    }
}

// MARK: - Int Identifiable Wrapper for sheet(item:)

private struct BoxedInt: Identifiable {
    let value: Int
    var id: Int { value }
}

private extension Optional where Wrapped == Int {
    var boxed: Binding<BoxedInt?> { fatalError("use the static helper instead") }
}

// Two-way binding helper: Int? → BoxedInt? so `.sheet(item:)` can drive
// off an Int day-number without a separate state object.
private extension Binding where Value == Int? {
    var boxed: Binding<BoxedInt?> {
        Binding<BoxedInt?>(
            get: { wrappedValue.map { BoxedInt(value: $0) } },
            set: { wrappedValue = $0?.value }
        )
    }
}
