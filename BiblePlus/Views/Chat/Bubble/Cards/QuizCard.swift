import SwiftUI

// MARK: - Comprehension Quiz Card
//
// A gentle, optional "did it land?" check the AI can drop after a teaching.
// Active recall is how people actually learn — but the tone stays warm and
// never punitive: the correct answer blooms gold with a check, a wrong pick
// gets a quiet, muted treatment, and a one-line explanation slides in.
//
//   [QUIZ answer="B"]Which did Paul call the greatest? || Faith || Love || Hope ~~ \
//   1 Corinthians 13:13 — "the greatest of these is love."[/QUIZ]
struct QuizCard: View {
    let question: String
    let options: [String]
    let answerIndex: Int
    let explanation: String

    @Environment(\.bpPalette) private var palette

    @State private var selected: Int?
    @State private var answered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            eyebrow

            Text(question)
                .font(.system(size: 17, weight: .medium, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    optionRow(index)
                }
            }

            if answered {
                explanationView
            }
        }
        .padding(18)
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
    }

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 11, weight: .semibold))
            Text("QUICK CHECK")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(2.2)
        }
        .foregroundStyle(palette.accent.opacity(0.78))
    }

    // MARK: Option row

    private func optionRow(_ index: Int) -> some View {
        let isCorrect = index == answerIndex
        let showCorrect = answered && isCorrect
        let showWrong = answered && selected == index && !isCorrect
        let dimmed = answered && !isCorrect && selected != index

        return Button {
            guard !answered else { return }
            answer(index)
        } label: {
            HStack(spacing: 12) {
                badge(index: index, showCorrect: showCorrect, showWrong: showWrong)

                Text(options[index])
                    .font(.system(size: 15))
                    .foregroundStyle(dimmed ? palette.textMuted : palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showWrong {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowFill(showCorrect, showWrong))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(rowBorder(showCorrect, showWrong), lineWidth: 1)
            )
            .opacity(dimmed ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    private func badge(index: Int, showCorrect: Bool, showWrong: Bool) -> some View {
        ZStack {
            Circle().fill(showCorrect ? palette.accent : Color.clear)
            Circle().strokeBorder(
                showCorrect ? .clear : (showWrong ? palette.textMuted.opacity(0.5) : palette.accent.opacity(0.45)),
                lineWidth: 1.2
            )
            if showCorrect {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            } else {
                Text(letter(index))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(showWrong ? palette.textMuted : palette.accent)
            }
        }
        .frame(width: 24, height: 24)
    }

    // MARK: Explanation

    private var explanationView: some View {
        let gotItRight = selected == answerIndex
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: gotItRight ? "checkmark.seal.fill" : "sparkle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(gotItRight ? "That's it." : "Not quite — here's why:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                if !explanation.isEmpty {
                    Text(explanation)
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.accent.opacity(0.06)))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: Logic

    private func answer(_ index: Int) {
        selected = index
        if index == answerIndex {
            HapticService.success()
        } else {
            HapticService.lightImpact()
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            answered = true
        }
    }

    private func letter(_ index: Int) -> String {
        guard let scalar = UnicodeScalar(65 + index) else { return "" }
        return String(scalar)
    }

    private func rowFill(_ correct: Bool, _ wrong: Bool) -> Color {
        if correct { return palette.accent.opacity(0.13) }
        if wrong { return palette.textMuted.opacity(0.08) }
        return palette.surface
    }

    private func rowBorder(_ correct: Bool, _ wrong: Bool) -> Color {
        if correct { return palette.accent.opacity(0.5) }
        if wrong { return palette.textMuted.opacity(0.3) }
        return palette.border.opacity(0.4)
    }
}
