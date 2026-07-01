import SwiftUI

struct GoldButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var showGlow: Bool = false
    let action: () -> Void

    @Environment(\.bpPalette) private var palette

    var body: some View {
        Button(action: {
            HapticService.impact(.light)
            action()
        }) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(isEnabled ? .white : palette.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled
                              ? AnyShapeStyle(palette.accent)
                              : AnyShapeStyle(palette.textPrimary.opacity(0.08)))
                )
                .shadow(
                    color: isEnabled ? palette.accent.opacity(showGlow ? 0.38 : 0.26) : .clear,
                    radius: 16,
                    y: 6
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
    }
}
