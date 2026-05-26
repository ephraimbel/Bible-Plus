import SwiftUI

// MARK: - Device Frame
//
// An elegant, minimal iPhone frame used to showcase live recreations of the
// app inside onboarding. Deliberately NOT a photoreal mockup — a refined
// graphite/titanium bezel with a Dynamic-Island pill, a soft glass highlight
// sweep, and a floating drop shadow. Tuned to read as "premium hardware"
// against both the Warm Paper (light) and Midnight (dark) palettes.
//
// The screen content is clipped to the inner display shape, so any scene
// dropped in behaves exactly like it would on a real device edge.
//
// Proportions are derived from a modern iPhone (≈19.5:9 with a large display
// corner radius). Everything scales from a single `width`, so the same frame
// looks correct from an iPhone SE preview thumbnail up to a full-screen hero.
struct DeviceFrame<Screen: View>: View {
    /// Outer width of the device in points. Height + radii derive from this.
    var width: CGFloat = 260
    /// Canvas shown behind the screen content (the app's background color).
    var screenBackground: Color = Color(hex: "FBF8F3")
    @ViewBuilder var screen: () -> Screen

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var height: CGFloat { width * 2.16 }
    private var outerRadius: CGFloat { width * 0.165 }
    private var bezel: CGFloat { max(6, width * 0.032) }
    private var innerRadius: CGFloat { max(2, outerRadius - bezel) }
    private var islandWidth: CGFloat { width * 0.30 }
    private var islandHeight: CGFloat { width * 0.085 }

    var body: some View {
        ZStack {
            titaniumBezel
            screenLayer
                .frame(width: width - bezel * 2, height: height - bezel * 2)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Bezel

    private var titaniumBezel: some View {
        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "3A3A3C"),
                        Color(hex: "1C1C1E"),
                        Color(hex: "2C2C2E")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Specular rim — a brushed-metal catch of light along the top
                // edge fading to a faint underside reflection.
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.38), .clear, .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.28), radius: width * 0.11, y: width * 0.055)
    }

    // MARK: - Screen

    private var screenLayer: some View {
        ZStack {
            screenBackground

            screen()
                .frame(
                    width: width - bezel * 2,
                    height: height - bezel * 2,
                    alignment: .top
                )

            // Glass highlight — a single soft diagonal sweep across the top-left
            // so the display reads as glass, not a flat fill. Static under
            // reduce-motion (it never animates anyway, but keep it subtle).
            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(reduceMotion ? 0.05 : 0.10), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)

            // Faint inner edge darkening for depth against the bezel.
            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                .blur(radius: 1.5)
                .allowsHitTesting(false)

            // Dynamic Island.
            VStack {
                Capsule()
                    .fill(Color.black)
                    .frame(width: islandWidth, height: islandHeight)
                    .padding(.top, bezel * 0.7)
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview("Device Frame") {
    ZStack {
        BPColorPalette.light.background.ignoresSafeArea()
        DeviceFrame(width: 240) {
            AICompanionScene()
                .environment(\.bpPalette, .light)
        }
    }
}
