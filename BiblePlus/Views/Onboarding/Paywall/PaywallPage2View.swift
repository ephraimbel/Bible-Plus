import SwiftUI

// MARK: - Page 2: Social Proof + Feature Showcase

struct PaywallPage2View: View {
    @Bindable var vm: PaywallViewModel
    private let palette = BPColorPalette.dark

    @State private var showCarousel = false
    @State private var showSocial = false
    @State private var showTestimonials = false
    @State private var showFeatures = false
    @State private var hasAnimated = false

    private let testimonials: [(quote: String, name: String, stars: Int)] = [
        ("I was skeptical about a Bible app with AI but this genuinely helps me understand difficult passages. Asked about Romans 8 and got the clearest explanation I've ever read.", "Daniel K.", 5),
        ("As a new believer I didn't know where to start reading. The personalized plans made it so easy. I'm on a 45 day streak now!", "Aisha T.", 5),
        ("The prayer soundscapes are beautiful. I play them every morning during my quiet time. Worth every penny.", "Rebecca H.", 5),
        ("My small group uses this for our weekly study. The AI helps us prep discussion questions. Game changer.", "Marcus W.", 5),
        ("I've tried maybe 10 Bible apps over the years. This is the first one that actually kept me coming back daily.", "Jennifer P.", 5),
        ("Love that I can ask questions at 2am when I can't sleep and something's weighing on me. Like having a pastor on call.", "Thomas R.", 4),
        ("The reading plans got me through a really hard season. Psalms of Peace was exactly what I needed after my dad passed.", "Grace L.", 5),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: - Carousel
                PaywallCarousel()
                    .frame(height: 340)
                    .padding(.top, 12)
                    .opacity(showCarousel ? 1 : 0)
                    .offset(y: showCarousel ? 0 : 20)

                // MARK: - Pro Wordmark
                // Editorial serif lockup. The flanking diamond ornaments
                // replace the giant glowing sparkle so the wordmark reads
                // like a printed-page chapter title rather than a logo.
                HStack(spacing: 14) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(palette.accent.opacity(0.7))

                    HStack(spacing: 4) {
                        Text("Bible")
                            .foregroundStyle(PaywallColors.goldGradient)
                        Image(systemName: "sparkle")
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.3))
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 4)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3), radius: 10)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.9), radius: 20)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.6), radius: 40)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.3).opacity(0.3), radius: 60)
                        Text(" Pro")
                            .foregroundStyle(PaywallColors.goldGradient)
                    }
                    .font(.custom("NewYorkLarge-Regular", size: 28, relativeTo: .title))

                    Image(systemName: "diamond.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(palette.accent.opacity(0.7))
                }
                .padding(.top, 10)
                .opacity(showCarousel ? 1 : 0)

                // MARK: - Social Proof Strip
                VStack(spacing: 10) {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.accent)
                        }
                        Text("4.9")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(palette.textPrimary)
                            .padding(.leading, 6)
                    }

                    Text("TRUSTED BY 700,000\u{2009}+ BELIEVERS")
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .tracking(2.5)
                        .foregroundStyle(palette.textSecondary.opacity(0.85))
                }
                .padding(.top, 18)
                .opacity(showSocial ? 1 : 0)
                .offset(y: showSocial ? 0 : 10)

                // MARK: - Testimonial Cards (auto-scrolling)
                TestimonialCarousel(testimonials: testimonials, palette: palette)
                    .frame(height: 155)
                    .padding(.top, 20)
                    .opacity(showTestimonials ? 1 : 0)
                    .offset(y: showTestimonials ? 0 : 12)

                // MARK: - Feature Comparison Table
                featureComparisonTable
                    .padding(.top, 24)
                    .opacity(showFeatures ? 1 : 0)
                    .offset(y: showFeatures ? 0 : 16)

                Spacer(minLength: 16)
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            triggerEntranceAnimations()
        }
    }


    // MARK: - Feature Comparison Table

    private var featureComparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feature")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .frame(width: 60)
                Text("Pro")
                    .frame(width: 72)
                    .foregroundStyle(palette.accent)
            }
            .font(.system(size: 10, weight: .regular, design: .serif))
            .foregroundStyle(palette.textMuted)
            .textCase(.uppercase)
            .tracking(2)
            .padding(.bottom, 12)

            Rectangle().fill(palette.border.opacity(0.5)).frame(height: 0.5)

            comparisonRow("AI Messages", free: "3 total", pro: "Unlimited")
            comparisonRow("Reading Plans", free: "—", pro: "All 9")
            comparisonRow("Translations", free: "2", pro: "7 + Audio")
            comparisonRow("Soundscapes", free: "1", pro: "30+")
            comparisonRow("Backgrounds", free: "12", pro: "239")
            comparisonRow("Daily Content", free: "Limited", pro: "1500+")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
    }

    private func comparisonRow(_ feature: String, free: String, pro: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(palette.textPrimary.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(free)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 60)

                Text(pro)
                    .font(.system(size: 12.5, weight: .regular, design: .serif))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 72)
            }
            .padding(.vertical, 11)

            Rectangle().fill(palette.border.opacity(0.3)).frame(height: 0.5)
        }
    }

    // MARK: - Entrance Animations

    private func triggerEntranceAnimations() {
        let spring = Animation.spring(response: 0.6, dampingFraction: 0.82)
        withAnimation(spring.delay(0.1)) { showCarousel = true }
        withAnimation(spring.delay(0.4)) { showSocial = true }
        withAnimation(spring.delay(0.6)) { showTestimonials = true }
        withAnimation(spring.delay(0.8)) { showFeatures = true }
    }
}

// MARK: - Auto-Scrolling Testimonial Carousel

private struct TestimonialCarousel: View {
    let testimonials: [(quote: String, name: String, stars: Int)]
    let palette: BPColorPalette

    @State private var offset: CGFloat = 0
    @State private var timer: Timer?

    private let cardWidth: CGFloat = 270
    private let cardSpacing: CGFloat = 14
    private let speed: CGFloat = 0.4 // points per frame tick

    private var totalCardWidth: CGFloat { cardWidth + cardSpacing }
    private var setWidth: CGFloat { totalCardWidth * CGFloat(testimonials.count) }

    var body: some View {
        GeometryReader { geo in
            let visibleWidth = geo.size.width
            // Render 3 copies for seamless loop
            HStack(spacing: cardSpacing) {
                ForEach(0..<3, id: \.self) { setIndex in
                    ForEach(Array(testimonials.enumerated()), id: \.offset) { index, t in
                        testimonialCard(quote: t.quote, name: t.name, stars: t.stars)
                            .frame(width: cardWidth)
                    }
                }
            }
            .offset(x: offset)
            .onAppear {
                offset = -setWidth // start from second set
                startScrolling()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
        .clipped()
    }

    private func startScrolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            offset -= speed
            // When we've scrolled past the second set, jump back seamlessly
            if offset <= -(setWidth * 2) {
                offset += setWidth
            }
        }
    }

    private func testimonialCard(quote: String, name: String, stars: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Star rating
            HStack(spacing: 2) {
                ForEach(0..<stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.accent)
                }
                if stars < 5 {
                    ForEach(0..<(5 - stars), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(palette.border)
                    }
                }
            }

            Text("\u{201C}\(quote)\u{201D}")
                .font(.system(size: 13.5, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(palette.textPrimary.opacity(0.88))
                .lineSpacing(3)
                .lineLimit(4)

            Text("— \(name)")
                .font(.system(size: 11, weight: .regular, design: .serif))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(palette.textMuted.opacity(0.8))
        }
        .padding(16)
        .frame(width: cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surfaceElevated)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}
