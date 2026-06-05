import SwiftUI
import SwiftData

struct PathDaySessionView: View {
    let path: DailyPath
    let dayNumber: Int
    let progress: UserPathProgress
    let onComplete: () -> Void

    @Environment(\.bpPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: PathDayViewModel?
    @State private var currentStep: Int = 0
    @State private var actionCommitted: Bool = false
    @State private var showDayCelebration: Bool = false
    @State private var showPathCelebration: Bool = false

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()

                if let vm {
                    sessionBody(vm: vm)
                } else {
                    ProgressView()
                }

                if showDayCelebration, let vm {
                    DayCelebrationOverlay(
                        dayNumber: dayNumber,
                        pathName: path.name,
                        tomorrow: path.day(dayNumber + 1),
                        palette: palette,
                        onContinue: {
                            finishDismiss(vm: vm)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if showPathCelebration, let vm {
                    PlanCompletionView(
                        planName: path.name,
                        gradientHex: path.gradientColors,
                        imageKey: path.imageKey,
                        onDismiss: {
                            finishDismiss(vm: vm)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
                ToolbarItem(placement: .principal) {
                    Text("Day \(dayNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .onAppear { setupOnFirstAppear() }
    }

    // MARK: - Setup

    private func setupOnFirstAppear() {
        guard vm == nil else { return }
        let model = PathDayViewModel(
            path: path,
            dayNumber: dayNumber,
            progress: progress,
            modelContext: modelContext
        )
        vm = model

        // Resume to the first undone step if there's a partial-day state for
        // this specific day. Days already completed open at step 0 so users
        // can re-read from the top.
        let resumeStep: Int
        if let partial = progress.partialDay, partial.day == dayNumber {
            resumeStep = firstUndoneStep(completed: partial.completedSteps)
        } else {
            resumeStep = 0
        }
        currentStep = resumeStep

        Analytics.track(.pathDayOpened, properties: [
            "path_id": path.id,
            "day": "\(dayNumber)",
            "resumed": "\(resumeStep > 0)",
            "resume_step": "\(resumeStep)"
        ])
    }

    private func firstUndoneStep(completed: [PathStep]) -> Int {
        let order: [PathStep] = [.openingPrayer, .scripture, .smallAction, .reflection, .quiz]
        for (index, step) in order.enumerated() {
            if !completed.contains(step) { return index }
        }
        return 0
    }

    // MARK: - Session Body

    @ViewBuilder
    private func sessionBody(vm: PathDayViewModel) -> some View {
        if let day = vm.day {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                TabView(selection: $currentStep) {
                    openingPrayerStep(day).tag(0)
                    scriptureStep(day).tag(1)
                    actionStep(day).tag(2)
                    reflectionStep(vm: vm, day: day).tag(3)
                    quizStep(vm: vm, day: day).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                footerButton(vm: vm, day: day)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
        } else {
            Text("Day content unavailable")
                .foregroundStyle(palette.textMuted)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        // Five calm segments — one per step. The filled count is an instant
        // read of "where am I in today's five minutes." No gradient, no glow:
        // the stillness is what makes it feel considered.
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? palette.accent : palette.border)
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
        .frame(height: 3)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
    }

    // MARK: - Steps

    private func openingPrayerStep(_ day: PathDay) -> some View {
        // Centered, breathable, no scroll — the prayer is a *moment*, not a
        // wall of text. The step is short by design (1-2 sentences); putting
        // it inside a ScrollView made it feel like content to skim past.
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: path.iconName.isEmpty ? "leaf.fill" : path.iconName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(palette.accent)

            if let theme = day.themeLabel {
                Text(theme.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(palette.accent)
            }

            Text(day.openingPrayer)
                .font(.system(size: 22, design: .serif))
                .italic()
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scriptureStep(_ day: PathDay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepEyebrow("SCRIPTURE", "open.book")

                VStack(alignment: .leading, spacing: 14) {
                    Text("\u{201C}\(day.scripture.verseText)\u{201D}")
                        .font(.system(size: 20, design: .serif))
                        .italic()
                        .lineSpacing(7)
                        .foregroundStyle(palette.textPrimary)

                    Text(day.scripture.displayReference)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(palette.border, lineWidth: 0.8)
                        )
                )

                Text("What this means")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(palette.textMuted)
                    .padding(.top, 8)

                Text(day.practicalMeaning)
                    .font(.system(size: 17, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func actionStep(_ day: PathDay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepEyebrow("TODAY'S ACTION", "hand.raised.fill")

                Text(day.smallAction)
                    .font(.system(size: 21, design: .serif))
                    .lineSpacing(8)
                    .foregroundStyle(palette.textPrimary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(palette.surfaceElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(palette.border.opacity(0.4), lineWidth: 0.6)
                            )
                    )

                Button {
                    HapticService.lightImpact()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        actionCommitted.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: actionCommitted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolEffect(.bounce, value: actionCommitted)
                        Text(actionCommitted ? "Committed" : "I'll do this today")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.accent.opacity(actionCommitted ? 0.16 : 0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(palette.accent.opacity(actionCommitted ? 0.55 : 0.25), lineWidth: 0.8)
                            )
                    )
                }
                .buttonStyle(.plain)

                Text("This is a commitment, not a contract. The point is to notice — not to perform.")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    @FocusState private var reflectionFocused: Bool

    private func reflectionStep(vm: PathDayViewModel, day: PathDay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepEyebrow("REFLECTION", "text.bubble.fill")

                Text(day.reflectionPrompt)
                    .font(.system(size: 18, design: .serif))
                    .italic()
                    .lineSpacing(6)
                    .foregroundStyle(palette.textSecondary)

                TextEditor(text: Binding(
                    get: { vm.reflectionText },
                    set: { vm.reflectionText = $0 }
                ))
                .font(.system(size: 16))
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .focused($reflectionFocused)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(palette.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    palette.border.opacity(reflectionFocused ? 0.7 : 0.4),
                                    lineWidth: reflectionFocused ? 0.9 : 0.5
                                )
                        )
                )
                .animation(.easeOut(duration: 0.2), value: reflectionFocused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            reflectionFocused = false
                            vm.saveReflection()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func quizStep(vm: PathDayViewModel, day: PathDay) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepEyebrow("RECALL", "checkmark.seal.fill")

                Text(day.quiz.question)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(palette.textPrimary)
                    .padding(.bottom, 4)

                VStack(spacing: 10) {
                    ForEach(Array(day.quiz.options.enumerated()), id: \.offset) { index, option in
                        quizOption(vm: vm, quiz: day.quiz, index: index, text: option)
                    }
                }

                if vm.quizRevealed {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.accent)
                            .padding(.top, 2)
                        Text(day.quiz.explanation)
                            .font(.system(size: 15))
                            .italic()
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(palette.accent.opacity(0.06))
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: vm.quizRevealed)
        }
    }

    // MARK: - Footer Button

    private func footerButton(vm: PathDayViewModel, day: PathDay) -> some View {
        let isLastStep = currentStep == totalSteps - 1
        let quizNeeded = isLastStep && !vm.quizRevealed
        let buttonLabel: String = {
            if isLastStep {
                return vm.isAlreadyCompleted ? "Mark Day Complete" : "Complete Day \(dayNumber)"
            }
            return "Continue"
        }()

        return Button {
            handleFooterTap(vm: vm)
        } label: {
            HStack(spacing: 8) {
                Text(buttonLabel)
                    .font(.system(size: 17, weight: .semibold))
                if !isLastStep {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.accent.opacity(quizNeeded ? 0.4 : 1.0))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: quizNeeded)
        .disabled(quizNeeded)
    }

    // MARK: - Actions

    private func handleFooterTap(vm: PathDayViewModel) {
        HapticService.lightImpact()

        // Dismiss keyboard if the reflection field is focused — otherwise the
        // first tap on Continue from inside reflection only dismisses the
        // keyboard, swallowing the advance.
        reflectionFocused = false

        // Persist the step just completed into PartialDayState.
        let stepJustFinished = stepEnum(at: currentStep)
        updatePartial(append: stepJustFinished)
        Analytics.track(.pathStepAdvanced, properties: [
            "path_id": path.id,
            "day": "\(dayNumber)",
            "step": stepJustFinished.rawValue
        ])

        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                currentStep += 1
            }
            return
        }

        // Final step → mark day complete.
        HapticService.notification(.success)
        vm.markDayComplete()

        let wholePathDone = vm.progressIsCompleted
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            if wholePathDone {
                showPathCelebration = true
            } else {
                showDayCelebration = true
            }
        }

        // Day celebration with a Tomorrow preview waits for an explicit tap
        // (the "I'll be back" button or background tap) so the user can read
        // the preview. If there's no tomorrow (e.g. seed data missing day N+1
        // for some reason but path isn't actually complete), fall back to a
        // generous auto-dismiss so the user isn't trapped. Path-completion
        // (whole path done) uses PlanCompletionView and always waits for tap.
        if !wholePathDone && path.day(dayNumber + 1) == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                finishDismiss(vm: vm)
            }
        }
    }

    private func finishDismiss(vm: PathDayViewModel) {
        onComplete()
        dismiss()
    }

    private func updatePartial(append step: PathStep) {
        var current = progress.partialDay
        if current?.day != dayNumber {
            current = PartialDayState(day: dayNumber, completedSteps: [], updatedAt: Date())
        }
        if var state = current {
            if !state.completedSteps.contains(step) {
                state.completedSteps.append(step)
            }
            state.updatedAt = Date()
            progress.setPartialDay(state)
            try? modelContext.save()
        }
    }

    private func stepEnum(at index: Int) -> PathStep {
        let order: [PathStep] = [.openingPrayer, .scripture, .smallAction, .reflection, .quiz]
        return order[min(max(index, 0), order.count - 1)]
    }

    // MARK: - Reusable Pieces

    private func stepEyebrow(_ label: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(palette.textMuted)
        }
    }

    // Quiz feedback colors. Editorial palette instead of system green/red so
    // the moment lands as warm-correct vs gentle-not-quite rather than the
    // pass/fail energy of a kids' app.
    private static let quizCorrectColor = Color(red: 0.42, green: 0.62, blue: 0.43)
    private static let quizGentleColor = Color(red: 0.78, green: 0.45, blue: 0.40)

    private func quizOption(vm: PathDayViewModel, quiz: PathQuiz, index: Int, text: String) -> some View {
        let selected = vm.selectedQuizOptionIndex == index
        let revealed = vm.quizRevealed
        let isCorrect = index == quiz.correctIndex

        let borderColor: Color = {
            guard revealed else { return selected ? palette.accent : palette.border.opacity(0.4) }
            if isCorrect { return Self.quizCorrectColor }
            if selected { return Self.quizGentleColor.opacity(0.7) }
            return palette.border.opacity(0.3)
        }()

        let backgroundFill: Color = {
            guard revealed else { return palette.surfaceElevated }
            if isCorrect { return Self.quizCorrectColor.opacity(0.08) }
            if selected { return Self.quizGentleColor.opacity(0.06) }
            return palette.surfaceElevated
        }()

        let a11yLabel: String = {
            if revealed && isCorrect { return "\(text). Correct answer." }
            if revealed && selected { return "\(text). Not quite." }
            return text
        }()

        return Button {
            HapticService.lightImpact()
            vm.selectQuizOption(index)
        } label: {
            HStack(spacing: 12) {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Self.quizCorrectColor)
                } else if revealed && selected {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(Self.quizGentleColor.opacity(0.8))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(borderColor, lineWidth: revealed && (isCorrect || selected) ? 1.4 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(revealed)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(revealed ? "" : "Tap to answer")
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.quizRevealed)
    }

    private var closeButton: some View {
        Button {
            vm?.saveReflection()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
    }

}

// MARK: - Day Celebration Overlay
//
// Moment after completing a single day. Two phases:
//   1. Brief icon+title animation (0.6s into view).
//   2. Tomorrow's preview card slides in (delay 0.5s) showing day N+1's
//      theme + scripture as a hook back into the habit.
// Tap the backdrop or the "I'll be back" button to dismiss. The session
// view also auto-dismisses after the celebration timeout so users who
// finish in low-attention contexts (commute, etc.) aren't stranded.

private struct DayCelebrationOverlay: View {
    let dayNumber: Int
    let pathName: String
    let tomorrow: PathDay?
    let palette: BPColorPalette
    let onContinue: () -> Void

    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var previewOpacity: Double = 0
    @State private var previewOffset: CGFloat = 18

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture { onContinue() }

            RadialGradient(
                colors: [palette.accent.opacity(glowOpacity), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                medallion

                titleBlock

                if let tomorrow {
                    tomorrowCard(tomorrow)
                        .opacity(previewOpacity)
                        .offset(y: previewOffset)
                        .padding(.horizontal, 32)
                }

                Spacer(minLength: 0)

                if tomorrow != nil {
                    Button {
                        HapticService.lightImpact()
                        onContinue()
                    } label: {
                        Text("I\u{2019}ll be back")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 28)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.25), lineWidth: 0.6)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(previewOpacity)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
                glowOpacity = 0.4
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                textOpacity = 1.0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.5)) {
                previewOpacity = 1.0
                previewOffset = 0
            }
        }
    }

    // MARK: - Pieces

    private var medallion: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.20))
                .frame(width: 100, height: 100)
                .blur(radius: 14)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 76, height: 76)
                .shadow(color: palette.accent.opacity(0.5), radius: 18)

            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(iconScale)
        .opacity(iconOpacity)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Day \(dayNumber) Complete")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            Text(pathName)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .opacity(textOpacity)
    }

    private func tomorrowCard(_ day: PathDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("TOMORROW")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.8)
            }
            .foregroundStyle(.white.opacity(0.75))

            if let theme = day.themeLabel {
                Text(theme)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Day \(day.day)")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }

            Text(day.scripture.displayReference)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.accent.opacity(0.95))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.18), lineWidth: 0.6)
                )
        )
    }
}
