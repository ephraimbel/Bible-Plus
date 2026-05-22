import SwiftUI
import SwiftData

struct ReadingPlansView: View {
    let isPro: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReadingPlansViewModel?
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    plansContent(vm)
                } else {
                    // Loading state with layered rings
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(palette.accent.opacity(0.03))
                                .frame(width: 120, height: 120)
                            Circle()
                                .stroke(palette.accent.opacity(0.08), lineWidth: 1)
                                .frame(width: 90, height: 90)
                            Circle()
                                .fill(palette.surfaceElevated)
                                .frame(width: 60, height: 60)
                                .shadow(color: palette.accent.opacity(0.12), radius: 8, y: 2)
                            ProgressView()
                                .tint(palette.accent)
                        }
                        Text("Loading plans...")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(palette.background)
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Reading Plans")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(palette.surfaceElevated)
                                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(palette.border.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = ReadingPlansViewModel(modelContext: modelContext)
                    viewModel = vm
                }
                withAnimation(BPAnimation.spring.delay(0.15)) {
                    showContent = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAIWithContext)) { _ in
                dismiss()
            }
        }
        .overlay {
            if let vm = viewModel, vm.showCompletion {
                PlanCompletionView(
                    planName: vm.completedPlanName,
                    gradientHex: vm.completedPlanGradient,
                    imageKey: vm.completedPlanImageKey
                ) {
                    withAnimation { vm.showCompletion = false }
                }
            }
        }
    }

    // MARK: - Plans Content

    @ViewBuilder
    private func plansContent(_ vm: ReadingPlansViewModel) -> some View {
        Group {
            if vm.allPlans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Active plans
                        if !vm.activePlans.isEmpty {
                            activePlansSection(vm)
                        }

                        // For You
                        if !vm.recommendedPlans.isEmpty {
                            recommendedSection(vm)
                        }

                        // Pro upsell
                        if !isPro {
                            proUpsellCard(vm)
                        }

                        // All plans by category
                        allPlansSection(vm)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { vm.showPaywall },
            set: { vm.showPaywall = $0 }
        )) {
            PaywallContainerView()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "books.vertical")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(palette.accent)
            }

            Text("No plans available yet")
                .font(.custom("Georgia-Bold", size: 16))
                .foregroundStyle(palette.textPrimary)

            Text("Your reading plans will appear here\nonce content is loaded.")
                .font(BPFont.elegantSubtitle)
                .foregroundStyle(palette.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active Plans

    private func activePlansSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("YOUR ACTIVE PLANS", icon: "flame.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(vm.activePlans.enumerated()), id: \.element.progress.id) { index, item in
                        NavigationLink {
                            PlanDetailView(
                                plan: item.plan,
                                viewModel: vm,
                                isPro: isPro
                            )
                        } label: {
                            PlanCardView(
                                plan: item.plan,
                                progress: item.progress,
                                isCompleted: false,
                                isPro: isPro
                            )
                            .frame(width: 260)
                            .opacity(showContent ? 1 : 0)
                            .animation(BPAnimation.staggered(index: index), value: showContent)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Recommended

    private func recommendedSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("FOR YOU", icon: "sparkles")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(vm.recommendedPlans.enumerated()), id: \.element.id) { index, plan in
                        NavigationLink {
                            PlanDetailView(
                                plan: plan,
                                viewModel: vm,
                                isPro: isPro
                            )
                        } label: {
                            PlanCardView(
                                plan: plan,
                                progress: nil,
                                isCompleted: vm.isCompleted(plan.id),
                                isPro: isPro
                            )
                            .frame(width: 220)
                            .opacity(showContent ? 1 : 0)
                            .animation(BPAnimation.staggered(index: index), value: showContent)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - All Plans

    /// Category display order — groups plans by thematic arc so a user
    /// scrolling down the browse screen encounters content in a natural flow:
    /// foundational entry points first, then Jesus-focused content, biblical
    /// figures, epistles/doctrine, worship/prayer, and seasonal plans last.
    /// Unlisted categories fall to the end alphabetically via `groupedPlans`.
    private static let categoryOrder: [String] = [
        "Foundations",
        "Gospel",
        "Jesus' Teaching",
        "Character Study",
        "Theology",
        "Epistles",
        "Wisdom",
        "Comfort",
        "Purpose",
        "Discipleship",
        "Worship",
        "Prayer",
        "Advent",
        "Easter",
    ]

    private func allPlansSection(_ vm: ReadingPlansViewModel) -> some View {
        let groups = groupedPlans(vm.allPlans)
        return VStack(alignment: .leading, spacing: 20) {
            sectionHeader("ALL PLANS", icon: "books.vertical.fill")

            // Single flat grid when few plans, else group by category.
            if vm.allPlans.count <= 8 || groups.count == 1 {
                planGrid(vm.allPlans, vm: vm, staggerStart: 0)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(groups.enumerated()), id: \.element.category) { groupIndex, group in
                        VStack(alignment: .leading, spacing: 14) {
                            categorySubheader(group.category, count: group.plans.count)
                            planGrid(group.plans, vm: vm, staggerStart: groupIndex * 6)
                        }
                    }
                }
            }
        }
    }

    private func planGrid(_ plans: [ReadingPlan], vm: ReadingPlansViewModel, staggerStart: Int) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16, alignment: .top),
            GridItem(.flexible(), spacing: 16, alignment: .top)
        ], spacing: 20) {
            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                NavigationLink {
                    PlanDetailView(
                        plan: plan,
                        viewModel: vm,
                        isPro: isPro
                    )
                } label: {
                    PlanCardView(
                        plan: plan,
                        progress: vm.progressForPlan(plan.id),
                        isCompleted: vm.isCompleted(plan.id),
                        isPro: isPro
                    )
                    .opacity(showContent ? 1 : 0)
                    .animation(
                        BPAnimation.staggered(index: staggerStart + index, base: 0.03),
                        value: showContent
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    /// Subheader used inside the All Plans section to label category groupings.
    /// Less prominent than the main section header so it reads as a sub-level.
    private func categorySubheader(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(palette.accent.opacity(0.85))

            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textMuted.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(palette.accent.opacity(0.08))
                )

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    /// Groups plans by category, ordering known categories per `categoryOrder`
    /// and appending unknown categories at the end in alphabetical order.
    private func groupedPlans(_ plans: [ReadingPlan]) -> [(category: String, plans: [ReadingPlan])] {
        let grouped = Dictionary(grouping: plans) { plan in
            plan.category.isEmpty ? "Other" : plan.category
        }
        let knownOrder = Self.categoryOrder
        var ordered: [(category: String, plans: [ReadingPlan])] = []

        // Known categories first, in specified order.
        for cat in knownOrder {
            if let items = grouped[cat], !items.isEmpty {
                ordered.append((cat, items))
            }
        }

        // Any remaining categories alphabetical.
        let unknown = grouped.keys
            .filter { !knownOrder.contains($0) }
            .sorted()
        for cat in unknown {
            if let items = grouped[cat], !items.isEmpty {
                ordered.append((cat, items))
            }
        }
        return ordered
    }

    // MARK: - Pro Upsell Card

    private func proUpsellCard(_ vm: ReadingPlansViewModel) -> some View {
        let proCount = vm.allPlans.filter { $0.isProOnly }.count
        return Button {
            HapticService.lightImpact()
            vm.showPaywall = true
        } label: {
            HStack(spacing: 16) {
                // Crown in gradient circle
                Image(systemName: "crown.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: palette.accent.opacity(0.3), radius: 4, y: 2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock All \(proCount) Plans")
                        .font(.custom("Georgia-Bold", size: 16))
                        .foregroundStyle(palette.textPrimary)

                    Text("Premium guided journeys, unlimited concurrent plans, and deeper study.")
                        .font(BPFont.elegantSubtitle)
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textMuted.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String = "book.fill") -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(palette.accent.opacity(0.1))
                )

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(palette.textMuted)

            VStack { Divider() }
                .padding(.leading, 4)
        }
        .padding(.horizontal, 20)
    }
}
