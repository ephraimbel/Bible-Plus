import SwiftUI

// MARK: - Feed Scene
//
// A live recreation of the Bible+ swipe feed — a verse set over a full-bleed
// biblical painting with the floating action bar. Faithful to `FeedCardView`
// and `ActionBarView`: centered white serif verse, ornamental divider,
// reference, a content-type badge, and the right-edge action rail.
//
// This is where the biblical artwork gets its moment (the AI hook uses a
// compact inline verse card; the feed is full-bleed by design). Calm, premium
// motion: the painting drifts almost imperceptibly (a slow Ken Burns), the
// content settles in, and a subtle "swipe" hint breathes at the base.
struct FeedScene: View {
    var verse: String = "Be still, and know that I am God."
    var reference: String = "Psalm 46:10"
    var badge: String = "VERSE"
    var category: String = "Peace"
    /// A biblical painting matched to the verse — stillness → Christ calming the storm.
    var artKey: String = "biblical_jesus_calms_storm"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var kenBurns = false
    @State private var hearted = false
    @State private var hintBob = false

    private let gold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        ZStack {
            artLayer
            scrim
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            actionRail
                .opacity(appeared ? 1 : 0)
            swipeHint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear { begin() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A preview of the Bible Plus verse feed: \(verse), \(reference)")
    }

    // MARK: - Painting

    private var artLayer: some View {
        // Sizing layer is a definite Rectangle; the painting rides as a clipped
        // overlay so it can't skew the ZStack's width (which would over-widen
        // the centered verse and clip it). Mirrors FeedCardView's approach.
        Rectangle()
            .fill(Color.black)
            .overlay {
                Image(artKey)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(reduceMotion ? 1.0 : (kenBurns ? 1.07 : 1.0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    // MARK: - Legibility scrim

    private var scrim: some View {
        ZStack {
            // Even tint so any painting keeps white text readable.
            Color.black.opacity(0.18)
            // Top + bottom darkening — protects status area and the reference.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0.0),
                    .init(color: .clear, location: 0.28),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.55), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(badge)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.14)))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .padding(.bottom, 18)

            Text(verse)
                .font(.system(size: 21, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.4), radius: 5, y: 2)
                .padding(.horizontal, 26)

            ornamentalDivider
                .padding(.vertical, 14)

            Text("— \(reference)")
                .font(.system(size: 13, weight: .light, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

            Text(category)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.09)))
                .padding(.top, 10)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var ornamentalDivider: some View {
        HStack(spacing: 7) {
            Circle().fill(.white.opacity(0.3)).frame(width: 3, height: 3)
            Rectangle().fill(.white.opacity(0.25)).frame(width: 26, height: 0.6)
            Image(systemName: "diamond.fill")
                .font(.system(size: 4))
                .foregroundStyle(.white.opacity(0.4))
            Rectangle().fill(.white.opacity(0.25)).frame(width: 26, height: 0.6)
            Circle().fill(.white.opacity(0.3)).frame(width: 3, height: 3)
        }
    }

    // MARK: - Action rail (mirrors ActionBarView)

    private var actionRail: some View {
        HStack {
            Spacer()
            VStack(spacing: 20) {
                railIcon(hearted ? "heart.fill" : "heart", tint: hearted ? gold : .white)
                railIcon("square.and.arrow.up")
                railIcon("pin")
                railIcon("bubble.left.and.bubble.right")
                railIcon("paintpalette")
                railIcon("speaker.slash")
            }
            .padding(.trailing, 12)
        }
    }

    private func railIcon(_ name: String, tint: Color = .white) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(tint)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
    }

    // MARK: - Swipe hint

    private var swipeHint: some View {
        VStack {
            Spacer()
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .offset(y: reduceMotion ? 0 : (hintBob ? -4 : 2))
                .padding(.bottom, 14)
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Choreography

    private func begin() {
        withAnimation(.easeOut(duration: 0.7)) { appeared = true }

        guard !reduceMotion else { return }

        // Slow, almost-imperceptible drift on the painting — life, not sway.
        withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
            kenBurns = true
        }
        // Gentle swipe-hint breathing.
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            hintBob = true
        }
        // A single, delayed "like" — shows the feed is interactive.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                hearted = true
            }
        }
    }
}

#Preview("Feed Scene") {
    ZStack {
        BPColorPalette.light.background.ignoresSafeArea()
        DeviceFrame(width: 264) {
            FeedScene()
        }
    }
}
