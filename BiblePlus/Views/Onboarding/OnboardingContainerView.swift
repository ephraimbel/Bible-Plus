import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bpPalette) private var palette
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ZStack {
                    OnboardingBackground()

                    VStack(spacing: 0) {
                        // Top bar: back button + progress dots
                        if vm.currentStep > 0 {
                            HStack {
                                Button {
                                    vm.goBack()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.title3)
                                        .foregroundStyle(palette.textSecondary)
                                        .padding(8)
                                }

                                Spacer()

                                ProgressDots(
                                    totalSteps: vm.totalSteps,
                                    currentStep: vm.currentStep
                                )

                                Spacer()

                                // Invisible spacer for symmetry
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .padding(8)
                                    .opacity(0)
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
                            case 7: AestheticView(viewModel: vm)
                            case 8: SummaryPaywallView(viewModel: vm)
                            case 9: WidgetSetupView(viewModel: vm)
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
                viewModel = OnboardingViewModel(modelContext: modelContext)
            }
        }
    }
}
