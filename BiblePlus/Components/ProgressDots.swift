import SwiftUI

struct ProgressDots: View {
    let totalSteps: Int
    let currentStep: Int
    @Environment(\.bpPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentStep
                            ? palette.accent
                            : palette.border
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
