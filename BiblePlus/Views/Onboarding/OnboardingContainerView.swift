import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @Environment(StoreKitService.self) private var storeKitService
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ZStack {
                    // Hide container background for full-screen views
                    if vm.currentStep != 0 && vm.currentStep != 9 {
                        OnboardingBackground()
                    }

                    VStack(spacing: 0) {
                        // Top bar: back button + progress dots
                        // Hidden on welcome (0) and paywall (9) for clean full-screen
                        if vm.currentStep > 0 && vm.currentStep != 9 {
                            HStack {
                                Button {
                                    vm.goBack()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(palette.textSecondary)
                                        .frame(width: 36, height: 36)
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

                                Spacer()

                                ProgressDots(
                                    totalSteps: vm.totalSteps,
                                    currentStep: vm.currentStep
                                )

                                Spacer()

                                // Invisible spacer for symmetry
                                Color.clear
                                    .frame(width: 36, height: 36)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity)
                        }

                        // Screen content
                        Group {
                            switch vm.currentStep {
                            case 0: WelcomeView(viewModel: vm)
                            case 1: NameInputView(viewModel: vm)
                            case 2: FaithLevelView(viewModel: vm)
                            case 3: LifeSeasonView(viewModel: vm)
                            case 4: HeartBurdensView(viewModel: vm)
                            case 5: TranslationPickerView(viewModel: vm)
                            case 6: DailyRhythmView(viewModel: vm)
                            case 7: NotificationPermissionView(viewModel: vm)
                            case 8: AestheticView(viewModel: vm)
                            case 9: SummaryPaywallView(viewModel: vm)
                            case 10: WidgetSetupView(viewModel: vm)
                            default: EmptyView()
                            }
                        }
                        .id(vm.currentStep)
                        .transition(
                            vm.navigationDirection == .forward
                                ? .onboardingForward
                                : .onboardingBackward
                        )
                    }
                }
                .animation(BPAnimation.pageTransition, value: vm.currentStep)
            } else {
                OnboardingBackground()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(modelContext: modelContext, storeKitService: storeKitService)
            }
        }
    }
}
