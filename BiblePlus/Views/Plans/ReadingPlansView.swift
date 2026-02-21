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
                    // Loading state with concentric circles
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(palette.accent.opacity(0.04))
                                .frame(width: 100, height: 100)
                            Circle()
                                .fill(palette.accent.opacity(0.06))
                                .frame(width: 72, height: 72)
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
        }
        .overlay {
            if let vm = viewModel, vm.showCompletion {
                PlanCompletionView(planName: vm.completedPlanName) {
                    withAnimation { vm.showCompletion = false }
                }
            }
        }
    }

    // MARK: - Plans Content

    @ViewBuilder
    private func plansContent(_ vm: ReadingPlansViewModel) -> some View {
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
            .padding(.bottom, 40)
        }
        .fullScreenCover(isPresented: Binding(
            get: { vm.showPaywall },
            set: { vm.showPaywall = $0 }
        )) {
            SummaryPaywallView()
        }
    }

    // MARK: - Active Plans

    private func activePlansSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("YOUR ACTIVE PLANS")

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
            sectionHeader("FOR YOU")

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

    private func allPlansSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("ALL PLANS")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                ForEach(Array(vm.allPlans.enumerated()), id: \.element.id) { index, plan in
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
                        .animation(BPAnimation.staggered(index: index, base: 0.03), value: showContent)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
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
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text("Premium guided journeys, unlimited concurrent plans, and deeper study.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surfaceElevated)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(palette.textMuted)
            .padding(.horizontal, 20)
    }
}
