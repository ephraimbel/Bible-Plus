import SwiftUI
import SwiftData

// MARK: - Personalized For You (Reveal Act 2)
//
// The refined payoff after "Crafting your plan." A restrained, enterprise-grade
// summary of how Bible+ has been shaped around this person, drawn from every
// answer they gave. A seal whose ring draws closed signals "ready"; a clean
// profile card lists each facet, its values rendered as understated chips; a
// single sheen sweeps the card once. Motion is purposeful and low-bounce, gold
// is used sparingly as an accent. Warm Paper / light, flowing into the review ask.
struct OnboardingPersonalizationView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void = {}

    @Environment(\.bpPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ringProgress: CGFloat = 0
    @State private var sealIn = false
    @State private var appeared = false
    @State private var sheen = false

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    private var name: String {
        viewModel.firstName.trimmingCharacters(in: .whitespaces)
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? ""
    }

    // MARK: - Facets (drawn from every answer)

    private struct Chip: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
    }

    private struct Facet: Identifiable {
        let id = UUID()
        let badge: String
        let label: String
        let chips: [Chip]
    }

    private var facets: [Facet] {
        var result: [Facet] = []

        if let faith = viewModel.selectedFaithLevel {
            result.append(Facet(
                badge: "figure.walk.motion",
                label: "Where you are",
                chips: [Chip(icon: faith.icon, label: faith.displayName)]
            ))
        }

        let burdens = viewModel.selectedBurdens.filter { $0 != .none }
        if !burdens.isEmpty {
            result.append(Facet(
                badge: "heart.text.square",
                label: "What's on your heart",
                chips: burdens.map { Chip(icon: $0.icon, label: $0.displayName) }
            ))
        }

        if !viewModel.selectedLifeSeasons.isEmpty {
            result.append(Facet(
                badge: "leaf",
                label: "The season you're in",
                chips: viewModel.selectedLifeSeasons.map { Chip(icon: $0.icon, label: $0.displayName) }
            ))
        }

        if !viewModel.selectedGrowthBlockers.isEmpty {
            result.append(Facet(
                badge: "shield.lefthalf.filled",
                label: "What we'll help with",
                chips: viewModel.selectedGrowthBlockers.map { Chip(icon: "checkmark", label: $0.displayName) }
            ))
        }

        let minutes = viewModel.selectedTimeCommitment?.minutesLabel ?? "5"
        result.append(Facet(
            badge: "clock",
            label: "Your daily rhythm",
            chips: [Chip(icon: "timer", label: "\(minutes) minutes a day")]
        ))

        if !viewModel.selectedPrayerTimes.isEmpty {
            let slots = viewModel.selectedPrayerTimes.sorted { $0.rawValue < $1.rawValue }
            result.append(Facet(
                badge: "bell",
                label: "Reminders",
                chips: slots.map { Chip(icon: $0.icon, label: $0.displayName) }
            ))
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        seal
                            .padding(.top, 16)

                        header
                            .padding(.horizontal, 36)
                            .padding(.top, 22)

                        profileCard
                            .padding(.horizontal, 22)
                            .padding(.top, 30)

                        Text("You can fine-tune any of this anytime in Settings.")
                            .font(.system(size: 12.5, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(palette.textMuted)
                            .padding(.horizontal, 40)
                            .padding(.top, 18)
                            .opacity(appeared ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(footerDelay), value: appeared)
                    }
                    .padding(.bottom, 12)
                }

                GoldButton(title: "Start my journey", showGlow: true) { onContinue() }
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(footerDelay + 0.1), value: appeared)
            }
            .padding(.vertical, 18)
        }
        .onAppear(perform: begin)
    }

    // MARK: - Seal (drawing ring + monogram)

    private var seal: some View {
        ZStack {
            Circle()
                .fill(accentGold.opacity(0.06))
                .frame(width: 92, height: 92)

            Circle()
                .fill(palette.surfaceElevated)
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(accentGold, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))

            Group {
                if initial.isEmpty {
                    Image(systemName: "sparkle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(accentGold)
                } else {
                    Text(initial)
                        .font(.custom("Baskerville", size: 30))
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .opacity(sealIn ? 1 : 0)
            .scaleEffect(sealIn ? 1 : 0.7)
        }
        .frame(width: 92, height: 92)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 11) {
            Text("PERSONALIZED FOR YOU")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(2.8)
                .foregroundStyle(accentGold)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.2), value: appeared)

            Text(name.isEmpty ? "You're all set." : "You're all set, \(name).")
                .font(.custom("Baskerville", size: 29))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.55).delay(0.27), value: appeared)

            Text("Everything below was tailored from what you shared.")
                .font(.system(size: 14.5, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.55).delay(0.34), value: appeared)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(facets.enumerated()), id: \.element.id) { index, facet in
                if index > 0 {
                    Rectangle()
                        .fill(palette.textPrimary.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 58)
                        .opacity(appeared ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(facetDelay(index)), value: appeared)
                }
                facetRow(facet, index: index)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(palette.textPrimary.opacity(0.07), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.07), radius: 20, y: 10)
        )
        .overlay(sheenOverlay)
        .scaleEffect(appeared ? 1 : 0.98)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.42), value: appeared)
    }

    // A single, subtle highlight that sweeps across the card once — the premium
    // "polished surface" cue. Masked to the card and non-interactive.
    private var sheenOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                colors: [.clear, .white.opacity(0.22), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: w * 0.45)
            .rotationEffect(.degrees(18))
            .offset(x: sheen ? w * 1.1 : -w * 0.6)
            .blendMode(.plusLighter)
        }
        .mask(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .allowsHitTesting(false)
    }

    private func facetRow(_ facet: Facet, index: Int) -> some View {
        let base = facetDelay(index)

        return HStack(alignment: .top, spacing: 16) {
            Image(systemName: facet.badge)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(accentGold)
                .frame(width: 26, height: 26)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 9) {
                Text(facet.label.uppercased())
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(palette.textSecondary)

                FlowLayout(spacing: 7, lineSpacing: 7) {
                    ForEach(Array(facet.chips.enumerated()), id: \.element.id) { chipIndex, chip in
                        chipView(chip)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 6)
                            .animation(
                                reduceMotion ? nil
                                : .easeOut(duration: 0.45).delay(base + 0.1 + Double(chipIndex) * 0.04),
                                value: appeared
                            )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 15)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(base), value: appeared)
    }

    private func chipView(_ chip: Chip) -> some View {
        HStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text(chip.label)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(palette.textPrimary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(palette.background)
                .overlay(Capsule(style: .continuous).stroke(palette.textPrimary.opacity(0.08), lineWidth: 0.7))
        )
    }

    // MARK: - Choreography

    private func begin() {
        if reduceMotion {
            ringProgress = 1
            sealIn = true
            appeared = true
            return
        }

        withAnimation(.easeInOut(duration: 0.7)) { ringProgress = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.55)) { sealIn = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.12)) { appeared = true }
        withAnimation(.easeInOut(duration: 1.1).delay(0.95)) { sheen = true }
    }

    // MARK: - Timing

    private func facetDelay(_ index: Int) -> Double {
        0.56 + Double(index) * 0.11
    }

    private var footerDelay: Double {
        facetDelay(facets.count) + 0.04
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            RadialGradient(colors: [accentGold.opacity(0.10), .clear],
                           center: .init(x: 0.5, y: 0.20), startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Flow Layout
//
// A lightweight wrapping layout so personalization chips flow onto as many
// lines as they need without manual row-chunking. Uses each subview's natural
// size, so render-only transforms never disturb the line breaks.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        let width = maxWidth == .infinity ? x - spacing : maxWidth
        return CGSize(width: max(0, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Personalization") {
    let vm = OnboardingViewModel(
        modelContext: try! ModelContainer(for: UserProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext,
        storeKitService: StoreKitService()
    )
    vm.firstName = "Sarah"
    vm.selectedFaithLevel = .growing
    vm.selectedBurdens = [.anxiety, .loneliness]
    vm.selectedLifeSeasons = [.workingProfessional, .single]
    vm.selectedGrowthBlockers = [.consistency]
    vm.selectedTimeCommitment = .fiveMin
    vm.selectedPrayerTimes = [.morning, .evening]
    return OnboardingPersonalizationView(viewModel: vm)
        .environment(\.bpPalette, .light)
}
