import SwiftUI
import SwiftData

struct ReadingPlansView: View {
    let isPro: Bool
    let onReadChapter: (String, Int) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReadingPlansViewModel?
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    plansContent(vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(palette.background)
            .navigationTitle("Reading Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(palette.textMuted)
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
        .sheet(isPresented: Binding(
            get: { vm.showPaywall },
            set: { vm.showPaywall = $0 }
        )) {
            SummaryPaywallView()
        }
    }

    // MARK: - Active Plans

    private func activePlansSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Active Plans")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(vm.activePlans.enumerated()), id: \.element.progress.id) { index, item in
                        NavigationLink {
                            PlanDetailView(
                                plan: item.plan,
                                viewModel: vm,
                                isPro: isPro,
                                onReadChapter: onReadChapter
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Recommended

    private func recommendedSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("For You")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(vm.recommendedPlans.enumerated()), id: \.element.id) { index, plan in
                        NavigationLink {
                            PlanDetailView(
                                plan: plan,
                                viewModel: vm,
                                isPro: isPro,
                                onReadChapter: onReadChapter
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - All Plans

    private func allPlansSection(_ vm: ReadingPlansViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("All Plans")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                ForEach(Array(vm.allPlans.enumerated()), id: \.element.id) { index, plan in
                    NavigationLink {
                        PlanDetailView(
                            plan: plan,
                            viewModel: vm,
                            isPro: isPro,
                            onReadChapter: onReadChapter
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
                    .buttonStyle(.plain)
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
                VStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.accent)
                    Text("\(proCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock All Plans")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text("Get \(proCount) premium guided journeys, unlimited concurrent plans, and deeper Bible study.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.accent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 20)
    }
}
