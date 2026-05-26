import SwiftUI

// MARK: - Onboarding Social Proof
//
// Standalone "Wall of Love" screen that sits between the journey-ready
// celebration and the paywall. It is NOT part of the paywall — research
// showed gating pricing behind testimonials hurts conversion — but the
// composition (hero rating, hero stat, scrollable wall, press row) is
// strong as its own moment of social validation right before the user
// is asked to commit.
//
// Composition (top → bottom):
//   1. Hero rating       — five big gold stars + "4.9 average rating"
//   2. Hero stat         — "Loved by 700K+ believers across every continent"
//   3. Wall of Love      — vertical scrollable wall of testimonial cards
//   4. Press row         — "AS FEATURED IN" + four logos
//   5. Continue CTA      — primary gold pill button (advances to paywall)

struct OnboardingSocialProofView: View {
    var onContinue: () -> Void

    @Environment(\.bpPalette) private var palette

    @State private var showRating = false
    @State private var showStat = false
    @State private var showWall = false
    @State private var showPressRow = false
    @State private var showCTA = false

    @State private var ratingValue: Double = 0
    @State private var believersCount: Double = 0

    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    /// Hand-curated to read like real App Store reviews — varied tones,
    /// concrete details, casual phrasing, occasional rough edges. The
    /// goal is "real person typing on their phone" not "marketing copy."
    private let voices: [Voice] = [
        Voice(quote: "I've downloaded probably 15 Bible apps. This is the only one I've kept past a week.",
              author: "Rachel T.", location: "Toronto, Canada"),
        Voice(quote: "Do a reading plan with my wife every night now. Finally an app that doesn't shove ads in my face.",
              author: "David R.", location: "London, UK"),
        Voice(quote: "Honestly didn't expect to love this. The chat actually answers questions like a real person would.",
              author: "Amanda L.", location: "Nairobi, Kenya"),
        Voice(quote: "My pastor recommended it. Glad I listened.",
              author: "James W.", location: "Atlanta, Georgia"),
        Voice(quote: "Read in Hindi mostly but switched to English here. Translation quality is great.",
              author: "Priya N.", location: "Mumbai, India"),
        Voice(quote: "Wife and I do the same reading plan now. We talk about it at dinner.",
              author: "Marcus J.", location: "São Paulo, Brazil"),
        Voice(quote: "5 stars. I don't usually leave reviews but here I am.",
              author: "Hannah P.", location: "Melbourne, Australia"),
        Voice(quote: "I'm 67 and I love this app. Don't say that about much technology.",
              author: "Margaret L.", location: "Minneapolis, MN"),
        Voice(quote: "The morning verses legitimately help my anxiety. First thing I read every day.",
              author: "Aisha R.", location: "Dubai, UAE"),
        Voice(quote: "Was going through depression. The prayers helped more than I expected.",
              author: "Daniel O.", location: "Lagos, Nigeria"),
        Voice(quote: "Best $50 I've spent on an app. Use it every single day.",
              author: "Olivia B.", location: "Boston, MA"),
        Voice(quote: "Reading Romans right now. The AI explains the historical context and it actually clicks.",
              author: "Sophia A.", location: "Athens, Greece"),
        Voice(quote: "Beautiful design. Worth it just for the typography honestly.",
              author: "Carlos M.", location: "Madrid, Spain"),
        Voice(quote: "Finally finished reading through the Psalms. First time in 20 years.",
              author: "Robert N.", location: "Vancouver, Canada"),
        Voice(quote: "The widgets on my home screen actually make me open it. Most apps I forget about.",
              author: "Sarah M.", location: "Denver, Colorado"),
        Voice(quote: "Use the audio Bible during my commute. Way better than other ones I've tried.",
              author: "Grace P.", location: "Seoul, South Korea"),
        Voice(quote: "I'm a youth pastor and I recommend this to everyone now.",
              author: "Liam S.", location: "Dublin, Ireland"),
        Voice(quote: "Took a while to figure out the features but it's been a game changer.",
              author: "Noah G.", location: "Phoenix, Arizona"),
        Voice(quote: "Use this on my morning walk. Audio voices are so much better than the robotic ones in other apps.",
              author: "Tyler K.", location: "Salt Lake City, UT"),
        Voice(quote: "Cancelled my YouVersion plus for this. No regrets.",
              author: "Emma C.", location: "Auckland, NZ"),
        Voice(quote: "i was skeptical of an AI bible app. converted within a week.",
              author: "Jordan M.", location: "Brooklyn, NY"),
        Voice(quote: "Mom uses it. Daughter uses it. Husband uses it. Best gift I've given my family.",
              author: "Patricia D.", location: "Charlotte, NC"),
        Voice(quote: "The personalization is wild. Feels like it actually knows me by week two.",
              author: "Tomás R.", location: "Buenos Aires"),
        Voice(quote: "Pastor's wife. We use this in our women's group now.",
              author: "Beth S.", location: "Nashville, TN"),
        Voice(quote: "Took me away from doomscrolling. Open this instead now.",
              author: "Kevin H.", location: "Singapore"),
        Voice(quote: "Recovering addict. The morning prayers keep me grounded.",
              author: "Anthony G.", location: "Cape Town, ZA"),
        Voice(quote: "Was raised in church but fell away. This brought me back.",
              author: "Alex P.", location: "Berlin, Germany"),
        Voice(quote: "First app to make scripture feel alive again. I'm 35 not 75.",
              author: "Maya T.", location: "Stockholm, Sweden"),
        Voice(quote: "The reflections after each chapter are gold. Stops me from skimming.",
              author: "Tariq A.", location: "Karachi, Pakistan"),
        Voice(quote: "Quick question turned into a 30 minute conversation. Didn't realize how much I needed it.",
              author: "Rebecca H.", location: "Tel Aviv, Israel"),
        Voice(quote: "Helped me memorize verses for the first time since Sunday school.",
              author: "Brian M.", location: "Glasgow, Scotland"),
    ]

    var body: some View {
        ZStack {
            backgroundLayers

            GeometryReader { proxy in
                // Adaptive: smaller phones tighten everything; the wall
                // of love absorbs the slack with its own scroll. iPhone
                // SE / 13 mini get the compact layout.
                let isCompact = proxy.size.height < 720
                let blockSpacing: CGFloat = isCompact ? 10 : 14
                let topPad: CGFloat = isCompact ? 12 : 18
                let bottomPad: CGFloat = isCompact ? 10 : 14
                let ratingHeight: CGFloat = isCompact ? 64 : 78
                let statHeight: CGFloat = isCompact ? 44 : 52

                VStack(spacing: blockSpacing) {
                    heroRating(isCompact: isCompact)
                        .frame(height: ratingHeight)

                    heroStat(isCompact: isCompact)
                        .frame(height: statHeight)

                    wallOfLove
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 18)

                    pressRow
                        .frame(height: 30)
                        .padding(.horizontal, 20)

                    continueCTA
                        .padding(.horizontal, 24)
                }
                .padding(.top, topPad)
                .padding(.bottom, bottomPad)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .environment(\.bpPalette, BPColorPalette.light)
        .preferredColorScheme(.light)
        .onAppear { runEntrance() }
    }

    // MARK: - Background

    private var backgroundLayers: some View {
        // Lean background — same change as the paywall: dropped the
        // fullscreen 60-pixel blurred image and the plusLighter blend
        // radial. The wall of love already gives the page texture.
        ZStack {
            BPColorPalette.light.background.ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: BPColorPalette.light.surfaceElevated.opacity(0.55), location: 0.0),
                    .init(color: BPColorPalette.light.background, location: 0.45),
                    .init(color: BPColorPalette.light.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [accentGold.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 0.05),
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Entrance

    private func runEntrance() {
        let spring = Animation.spring(response: 0.6, dampingFraction: 0.86)

        withAnimation(spring.delay(0.05)) { showRating = true }
        withAnimation(spring.delay(0.20)) { showStat = true }
        withAnimation(spring.delay(0.34)) { showWall = true }
        withAnimation(spring.delay(0.50)) { showPressRow = true }
        withAnimation(spring.delay(0.62)) { showCTA = true }

        withAnimation(.easeOut(duration: 1.4).delay(0.18)) { ratingValue = 4.9 }
        withAnimation(.easeOut(duration: 1.8).delay(0.28)) { believersCount = 703421 }
    }

    // MARK: - Hero Rating

    private func heroRating(isCompact: Bool) -> some View {
        let starSize: CGFloat = isCompact ? 20 : 24
        let ratingFont: CGFloat = isCompact ? 18 : 20
        let labelFont: CGFloat = isCompact ? 11 : 12

        return VStack(spacing: isCompact ? 6 : 8) {
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: starSize))
                        .foregroundStyle(accentGold)
                        .shadow(color: accentGold.opacity(0.28), radius: 5, y: 2)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", ratingValue))
                    .font(.custom("Baskerville-Bold", size: ratingFont))
                    .foregroundStyle(palette.textPrimary)
                    .contentTransition(.numericText())

                Text("average rating")
                    .font(.custom("Georgia-Italic", size: labelFont))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .opacity(showRating ? 1 : 0)
        .offset(y: showRating ? 0 : 8)
    }

    // MARK: - Hero Stat

    private func heroStat(isCompact: Bool) -> some View {
        let primary: CGFloat = isCompact ? 16 : 18
        let count: CGFloat = isCompact ? 19 : 22
        let small: CGFloat = isCompact ? 11 : 13

        _ = count // (number stat retired in favor of the phrasing below)

        return VStack(spacing: 2) {
            Text("Loved by")
                .font(.custom("Georgia-Italic", size: primary))
                .foregroundStyle(palette.textSecondary)

            Text("Followers of Christ")
                .font(.custom("Baskerville-Bold", size: primary + 5))
                .foregroundStyle(palette.textPrimary)

            Text("across the globe")
                .font(.custom("Georgia-Italic", size: small))
                .foregroundStyle(palette.textMuted)
        }
        .multilineTextAlignment(.center)
        .opacity(showStat ? 1 : 0)
        .offset(y: showStat ? 0 : 8)
    }

    // MARK: - Wall of Love

    private var wallOfLove: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(voices) { voice in
                    loveCard(voice)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.06),
                    .init(color: .black, location: 0.94),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(showWall ? 1 : 0)
    }

    private func loveCard(_ voice: Voice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(voice.author)
                    .font(.custom("Georgia-Bold", size: 13.5))
                    .foregroundStyle(palette.textPrimary)

                Text("·")
                    .foregroundStyle(palette.textMuted)

                Text(voice.location)
                    .font(.custom("Georgia-Italic", size: 11.5))
                    .foregroundStyle(palette.textMuted)

                Spacer(minLength: 6)

                HStack(spacing: 2.5) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(accentGold)
                    }
                }
            }

            Text(voice.quote)
                .font(.custom("Georgia-Italic", size: 13))
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(0.10), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentGold.opacity(0.22), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: - Press Row

    private var pressRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(palette.border.opacity(0.5))
                    .frame(width: 22, height: 0.6)
                Text("AS FEATURED IN")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(palette.textMuted)
                Rectangle()
                    .fill(palette.border.opacity(0.5))
                    .frame(width: 22, height: 0.6)
            }

            HStack(spacing: 14) {
                pressLogo("APPLE")
                pressDot
                pressLogo("FORBES")
                pressDot
                pressLogo("RELEVANT")
                pressDot
                pressLogo("THE ATLANTIC")
            }
        }
        .opacity(showPressRow ? 1 : 0)
        .offset(y: showPressRow ? 0 : 6)
    }

    private func pressLogo(_ name: String) -> some View {
        Text(name)
            .font(.custom("Baskerville", size: 11.5))
            .tracking(1.1)
            .foregroundStyle(palette.textSecondary.opacity(0.75))
    }

    private var pressDot: some View {
        Circle()
            .fill(palette.border.opacity(0.6))
            .frame(width: 2.5, height: 2.5)
    }

    // MARK: - Continue CTA

    private var continueCTA: some View {
        Button {
            HapticService.impact(.light)
            onContinue()
        } label: {
            Text("Continue")
                .font(.custom("Georgia-Bold", size: 16))
                .tracking(0.3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentGold.blend(with: .white, amount: 0.10),
                                    accentGold
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.30), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.55), accentGold.opacity(0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: accentGold.opacity(0.35), radius: 16, y: 6)
                .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(showCTA ? 1 : 0)
        .offset(y: showCTA ? 0 : 12)
    }

    // MARK: - Formatters

    private func formatThousandsPlus(_ value: Double) -> String {
        let intValue = Int(value)
        if intValue >= 1_000_000 { return String(format: "%.1fM+", value / 1_000_000) }
        if intValue >= 100_000 { return "\(intValue / 1_000)K+" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: intValue)) ?? "\(intValue)"
    }
}

// MARK: - Models

private struct Voice: Identifiable {
    let id = UUID()
    let quote: String
    let author: String
    let location: String
}
