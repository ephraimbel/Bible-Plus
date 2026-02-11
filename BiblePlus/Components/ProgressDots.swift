import SwiftUI

struct ProgressDots: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentStep
                            ? BPColorPalette.light.accent
                            : BPColorPalette.light.border
                    )
                    .frame(
                        width: index == currentStep ? 10 : 6,
                        height: index == currentStep ? 10 : 6
                    )
            }
        }
        .animation(BPAnimation.spring, value: currentStep)
    }
}
