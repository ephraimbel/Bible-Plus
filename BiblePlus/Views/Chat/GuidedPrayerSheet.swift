import SwiftUI

struct GuidedPrayerSheet: View {
    let onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.bpPalette) private var palette
    @State private var step = 1
    @State private var selectedWho: String?
    @State private var selectedWhat: String?
    @State private var includeScripture = true

    private let whoOptions = [
        ("person.fill", "For myself"),
        ("figure.2", "For my family"),
        ("person.2.fill", "For a friend"),
        ("building.columns.fill", "For my church"),
        ("globe.americas.fill", "For the world"),
    ]

    private let whatOptions = [
        ("heart.fill", "Healing"),
        ("arrow.triangle.branch", "Guidance"),
        ("leaf.fill", "Peace"),
        ("bolt.fill", "Strength"),
        ("sun.max.fill", "Gratitude"),
        ("shield.fill", "Protection"),
        ("hands.sparkles.fill", "Forgiveness"),
        ("basket.fill", "Provision"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress dots
                progressDots

                // Step content
                switch step {
                case 1:
                    stepOneWho
                case 2:
                    stepTwoWhat
                default:
                    stepThreeScripture
                }

                Spacer()
            }
            .padding(.top, 24)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Guided Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step > 1 {
                        Button {
                            withAnimation(BPAnimation.spring) {
                                step -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                    } else {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(palette.accent)
                    }
                }
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .fill(i <= step ? palette.accent : palette.accent.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .animation(BPAnimation.spring, value: step)
            }
        }
    }

    // MARK: - Step 1: Who

    private var stepOneWho: some View {
        VStack(spacing: 20) {
            Text("Who is this prayer for?")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)

            VStack(spacing: 10) {
                ForEach(whoOptions, id: \.1) { icon, label in
                    Button {
                        selectedWho = label
                        HapticService.selection()
                        withAnimation(BPAnimation.spring) {
                            step = 2
                        }
                    } label: {
                        optionCard(icon: icon, label: label, isSelected: selectedWho == label)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Step 2: What

    private var stepTwoWhat: some View {
        VStack(spacing: 20) {
            Text("What do you need prayer for?")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(whatOptions, id: \.1) { icon, label in
                    Button {
                        selectedWhat = label
                        HapticService.selection()
                        withAnimation(BPAnimation.spring) {
                            step = 3
                        }
                    } label: {
                        gridOptionCard(icon: icon, label: label, isSelected: selectedWhat == label)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Step 3: Scripture Toggle

    private var stepThreeScripture: some View {
        VStack(spacing: 28) {
            Text("Include Scripture?")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(palette.textPrimary)

            Toggle(isOn: $includeScripture) {
                HStack(spacing: 10) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.accent)
                    Text("Include a Scripture verse")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .tint(palette.accent)
            .padding(.horizontal, 24)

            // Summary
            VStack(alignment: .leading, spacing: 8) {
                if let who = selectedWho {
                    summaryRow(icon: "person.fill", text: who)
                }
                if let what = selectedWhat {
                    summaryRow(icon: "heart.fill", text: what)
                }
                summaryRow(
                    icon: "book.fill",
                    text: includeScripture ? "With Scripture" : "Without Scripture"
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.border.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)

            GoldButton(title: "Compose Prayer", showGlow: true) {
                composePrayer()
            }
            .padding(.horizontal, 32)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Helpers

    private func gridOptionCard(icon: String, label: String, isSelected: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? .white : palette.accent)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? palette.accent : palette.accent.opacity(0.1))
                )

            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? palette.accent.opacity(0.08) : palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? palette.accent.opacity(0.3) : palette.border.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func optionCard(icon: String, label: String, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? .white : palette.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? palette.accent : palette.accent.opacity(0.1))
                )

            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? palette.accent.opacity(0.08) : palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? palette.accent.opacity(0.3) : palette.border.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.accent)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func composePrayer() {
        guard let who = selectedWho, let what = selectedWhat else { return }
        let scriptureClause = includeScripture
            ? " Include a relevant Scripture verse woven into the prayer."
            : ""
        let prompt = "Write a heartfelt prayer \(who.lowercased()) about \(what.lowercased()).\(scriptureClause)"
        dismiss()
        onComplete(prompt)
    }
}
