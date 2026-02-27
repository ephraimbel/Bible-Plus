import SwiftUI

struct ProgressDots: View {
    let totalSteps: Int
    let currentStep: Int
    @Environment(\.bpPalette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentStep
                            ? palette.accent
                            : index < currentStep
                                ? palette.accent.opacity(0.4)
                                : palette.border.opacity(0.3)
                    )
                    .frame(
                        width: index == currentStep ? 20 : 6,
                        height: 4
                    )
                    .shadow(
                        color: index == currentStep ? palette.accent.opacity(0.3) : .clear,
                        radius: 4, y: 0
                    )
            }
        }
        .animation(BPAnimation.spring, value: currentStep)
    }
}
