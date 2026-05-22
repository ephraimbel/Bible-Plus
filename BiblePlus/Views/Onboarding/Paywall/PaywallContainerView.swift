import SwiftData
import SwiftUI

// MARK: - Paywall (Single Page, Enterprise Layout)
//
// One screen, no scroll. Comparison table is the visual centerpiece —
// the same way enterprise SaaS pricing pages anchor on a Free vs. Pro
// matrix. Two stacked plan cards with the yearly card visually dominant
// (gold border + glow + "Best Value" badge), a compact inline trial
// timeline above the sticky CTA, and footer links living inside the
// CTA inset so every actionable element is reachable without scrolling.
//
// Locked to the LIGHT palette so the paywall reads identically across
// system theme settings and conversion stays predictable.
struct PaywallContainerView: View {
    var onboardingViewModel: OnboardingViewModel? = nil
    var isOnboarding: Bool = true

    @Environment(StoreKitService.self) private var storeKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var profiles: [UserProfile]

    @State private var vm: PaywallViewModel?
    @State private var showCTA = false
    @State private var showExitSurvey = false
    @State private var ctaPulse = false

    private let palette = BPColorPalette.light
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)
    private let saveGreen = Color(red: 0.20, green: 0.58, blue: 0.25)

    init() {
        self.onboardingViewModel = nil
        self.isOnboarding = false
    }

    init(viewModel: OnboardingViewModel) {
        self.onboardingViewModel = viewModel
        self.isOnboarding = true
    }

    var body: some View {
        ZStack {
            backgroundLayers

            if let vm {
                content(vm: vm)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        stickyCTA(vm: vm)
                    }
            }

            // Floating dismiss / skip — top-right, only when paywall is
            // dismissible (in-app gates) or when onboarding (so the user
            // can opt for the free plan without a downsell sheet).
            VStack {
                HStack {
                    Spacer()
                    closeButton
                        .padding(.trailing, 18)
                        .padding(.top, 6)
                }
                Spacer()
            }
        }
        .environment(\.bpPalette, palette)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .onAppear {
            if vm == nil {
                if let onboardingViewModel {
                    vm = PaywallViewModel(viewModel: onboardingViewModel)
                } else {
                    vm = PaywallViewModel(profile: profiles.first)
                }
            }
            Analytics.track(.paywallViewed, properties: [
                "source": isOnboarding ? "onboarding" : "settings",
                "version": "single_page_enterprise",
            ])

            if storeKitService.subscriptions.isEmpty && !storeKitService.productsLoadError {
                Task { await storeKitService.loadProducts() }
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                showCTA = true
            }

            if !reduceMotion {
                withAnimation(BPAnimation.ctaBreath.delay(1.0)) {
                    ctaPulse = true
                }
            }
        }
        .alert("Purchase Failed", isPresented: Binding(
            get: { vm?.purchaseError != nil },
            set: { if !$0 { vm?.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm?.purchaseError ?? "")
        }
        .sheet(isPresented: $showExitSurvey) {
            PaywallExitSurveyView { _ in
                // Only fires when the user taps "Continue with Free".
                // Close the sheet then dismiss the paywall — no manual
                // delay; SwiftUI sequences the sheet-dismiss animation
                // and the parent dismiss naturally.
                showExitSurvey = false
                vm?.dismissPaywall(dismiss: dismiss)
            }
            // System-optimized .medium detent. Custom .fraction(...)
            // detents are recomputed by SwiftUI on each frame of the
            // slide animation; .medium uses a precomputed system path.
            // No drag indicator — X is the explicit close affordance.
            // Palette is locked inside PaywallExitSurveyView itself
            // so we don't need preferredColorScheme on the sheet
            // (which forces an extra environment-propagation pass).
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Background

    private var backgroundLayers: some View {
        // Lean background: solid surface + one calm linear gradient + one
        // soft radial halo. The previous layout had a 60-pixel-blur'd
        // fullscreen biblical image at 0.08 opacity AND a plusLighter
        // blend-mode radial — both invisible to the user but expensive
        // to render every frame, especially while the exit-survey sheet
        // animates up over the live (non-snapshotted) paywall.
        ZStack {
            palette.background.ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: palette.surfaceElevated.opacity(0.55), location: 0.0),
                    .init(color: palette.background, location: 0.45),
                    .init(color: palette.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [accentGold.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 0.05),
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            HapticService.lightImpact()
            if isOnboarding {
                showExitSurvey = true
            } else {
                Analytics.track(.paywallDismissed, properties: ["reason": "close"])
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textMuted)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(palette.surfaceElevated.opacity(0.9))
                        .overlay(Circle().stroke(palette.border.opacity(0.4), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                )
        }
        .accessibilityLabel("Close")
    }

    // MARK: - Page Content

    private func content(vm: PaywallViewModel) -> some View {
        // Adaptive composition. The proxy height drives a Compact /
        // Regular split: iPhone SE territory uses tighter table rows,
        // shorter plan cards, and trimmed headline typography so the
        // page never overflows. Larger phones get the more generous
        // version. Two equal Spacers split any device headroom left
        // into matched breathing top and bottom.
        GeometryReader { proxy in
            let isCompact = proxy.size.height < 600
            let metrics = Metrics(isCompact: isCompact)

            VStack(spacing: 0) {
                Spacer(minLength: 4)

                brandNameplate
                    .padding(.bottom, metrics.afterBrand)

                headlineBlock(vm: vm, metrics: metrics)
                    .padding(.horizontal, 28)
                    .padding(.bottom, metrics.afterHeadline)

                socialProofStrip
                    .padding(.bottom, metrics.afterSocial)

                comparisonTable(metrics: metrics)
                    .padding(.horizontal, 20)
                    .padding(.bottom, metrics.afterTable)

                planCards(vm: vm, metrics: metrics)
                    .padding(.horizontal, 20)

                Spacer(minLength: 4)
            }
        }
    }

    /// Per-device sizing constants. Compact is iPhone SE / 13 mini;
    /// Regular is everything from iPhone 14 upward. Reading from a
    /// single struct keeps the layout intent in one place instead of
    /// scattered ternaries throughout the body.
    private struct Metrics {
        let isCompact: Bool

        // Inter-block paddings
        var afterBrand: CGFloat   { isCompact ? 8  : 12 }
        var afterHeadline: CGFloat { isCompact ? 6  : 8 }
        var afterSocial: CGFloat   { isCompact ? 10 : 16 }
        var afterTable: CGFloat    { isCompact ? 8  : 14 }

        // Headline typography
        var nameSize: CGFloat       { isCompact ? 12   : 13 }
        var headlineSize: CGFloat   { isCompact ? 22   : 26 }
        var subtitleSize: CGFloat   { isCompact ? 12   : 13 }

        // Comparison table
        var rowHeight: CGFloat      { isCompact ? 24   : 32 }
        var headerHeight: CGFloat   { isCompact ? 26   : 34 }
        var rowFontSize: CGFloat    { isCompact ? 11   : 12 }
        var rowFreeSize: CGFloat    { isCompact ? 10.5 : 11.5 }
        var rowProSize: CGFloat     { isCompact ? 11   : 12 }

        // Plan cards
        var yearlyHeight: CGFloat   { isCompact ? 78   : 104 }
        var weeklyHeight: CGFloat   { isCompact ? 64   : 84 }
        var planTitleSize: CGFloat  { isCompact ? 16   : 19 }
        var planMetaSize: CGFloat   { isCompact ? 11   : 12.5 }
        var planPriceSize: CGFloat  { isCompact ? 22   : 27 }
        var planUnitSize: CGFloat   { isCompact ? 11   : 13 }
        var cardSpacing: CGFloat    { isCompact ? 8    : 10 }
        var cardVPad: CGFloat       { isCompact ? 12   : 18 }
    }

    // MARK: - Brand Nameplate
    //
    // Editorial wordmark with a fine gold underline rule. Reads as a
    // masthead — "Bible Plus, the Pro tier" — rather than a logo dump.

    private var brandNameplate: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("BIBLE PLUS")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .tracking(3.2)
                    .foregroundStyle(palette.textPrimary)

                Text("PRO")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentGold.blend(with: .white, amount: 0.1), accentGold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, accentGold.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Headline
    //
    // Two-line editorial headline. Greeting + personalized name on
    // line one (italic, secondary weight); the value statement on line
    // two (Baskerville bold). Handles short and long names equally
    // well — the name is never load-bearing for the value claim.

    private func headlineBlock(vm: PaywallViewModel, metrics: Metrics) -> some View {
        VStack(spacing: 4) {
            if !vm.firstName.isEmpty {
                Text("For \(vm.firstName)")
                    .font(.custom("Georgia-Italic", size: metrics.nameSize))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text("Everything unlocked.")
                .font(.custom("Baskerville-Bold", size: metrics.headlineSize))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Built around the way you believe.")
                .font(.custom("Georgia-Italic", size: metrics.subtitleSize))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Social Proof Strip

    private var socialProofStrip: some View {
        HStack(spacing: 7) {
            HStack(spacing: 1.5) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accentGold)
                }
            }

            Text("4.9")
                .font(.custom("Georgia-Bold", size: 11.5))
                .foregroundStyle(palette.textPrimary)

            Text("·")
                .foregroundStyle(palette.textMuted)

            Text("700K+ believers")
                .font(.custom("Georgia-Italic", size: 11.5))
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comparison Table (Centerpiece)

    private struct ComparisonRow: Identifiable {
        let id = UUID()
        let icon: String
        let feature: String
        let free: String
        let pro: String
    }

    private var comparisonRows: [ComparisonRow] {
        [
            ComparisonRow(icon: "sparkles",                       feature: "AI companion chats",   free: "10",  pro: "Unlimited"),
            ComparisonRow(icon: "book.closed",                    feature: "Bible translations",   free: "2",   pro: "8"),
            ComparisonRow(icon: "calendar",                       feature: "Reading plans",        free: "1",   pro: "29"),
            ComparisonRow(icon: "waveform",                       feature: "Sanctuary soundscapes", free: "4",  pro: "31"),
            ComparisonRow(icon: "photo.on.rectangle.angled",      feature: "Sanctuary backgrounds", free: "12", pro: "52"),
            ComparisonRow(icon: "speaker.wave.2",                 feature: "Audio Bible voices",   free: "1",   pro: "9"),
            ComparisonRow(icon: "rectangle.stack.badge.plus",     feature: "Home & Lock widgets",  free: "—",   pro: "10"),
        ]
    }

    private let freeColumnWidth: CGFloat = 60
    private let proColumnWidth: CGFloat = 84

    private func comparisonTable(metrics: Metrics) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentGold)
                    Text("Compare Plans")
                        .font(.custom("Georgia-Bold", size: 12))
                        .foregroundStyle(palette.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

                Text("FREE")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: freeColumnWidth)

                Text("PRO")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(accentGold)
                    .frame(width: proColumnWidth)
            }
            .padding(.horizontal, 14)
            .frame(height: metrics.headerHeight)
            .background(
                LinearGradient(
                    colors: [accentGold.opacity(0.10), accentGold.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Rectangle()
                .fill(accentGold.opacity(0.30))
                .frame(height: 0.6)

            ForEach(Array(comparisonRows.enumerated()), id: \.element.id) { index, row in
                comparisonRowView(row, metrics: metrics)
                if index < comparisonRows.count - 1 {
                    Rectangle()
                        .fill(palette.border.opacity(0.22))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)
                }
            }
        }
        // Header + divider (0.6) + 7 rows + 6 dividers (3pt total)
        .frame(height: metrics.headerHeight + 0.6 + (metrics.rowHeight * 7) + 3)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surfaceElevated.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [accentGold.opacity(0.45), accentGold.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: accentGold.opacity(0.10), radius: 12, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func comparisonRowView(_ row: ComparisonRow, metrics: Metrics) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: row.icon)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(accentGold.opacity(0.85))
                    .frame(width: 16)

                Text(row.feature)
                    .font(.custom("Georgia", size: metrics.rowFontSize))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.free)
                .font(.custom("Georgia", size: metrics.rowFreeSize))
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
                .frame(width: freeColumnWidth)

            Text(row.pro)
                .font(.custom("Georgia-Bold", size: metrics.rowProSize))
                .foregroundStyle(accentGold)
                .lineLimit(1)
                .frame(width: proColumnWidth)
        }
        .padding(.horizontal, 14)
        .frame(height: metrics.rowHeight)
    }

    // MARK: - Plan Cards

    private func planCards(vm: PaywallViewModel, metrics: Metrics) -> some View {
        VStack(spacing: metrics.cardSpacing) {
            yearlyCard(vm: vm, metrics: metrics)
            weeklyCard(vm: vm, metrics: metrics)
        }
    }

    private func yearlyCard(vm: PaywallViewModel, metrics: Metrics) -> some View {
        let isSelected = vm.selectedProductID == StoreKitService.yearlyID

        return Button {
            vm.selectedProductID = StoreKitService.yearlyID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": "yearly"])
        } label: {
            HStack(spacing: 14) {
                selectionRadio(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Yearly")
                        .font(.custom("Baskerville-Bold", size: metrics.planTitleSize))
                        .foregroundStyle(palette.textPrimary)

                    HStack(spacing: 6) {
                        Text("3-day free trial")
                            .font(.custom("Georgia", size: metrics.planMetaSize))
                            .foregroundStyle(palette.textSecondary)

                        Text("·")
                            .foregroundStyle(palette.textMuted)

                        Text("Save \(vm.savingsPercent(storeKitService))%")
                            .font(.custom("Georgia-Bold", size: metrics.planMetaSize))
                            .foregroundStyle(saveGreen)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(vm.yearlyWeeklyBreakdown(storeKitService))
                            .font(.custom("Baskerville-Bold", size: metrics.planPriceSize))
                            .foregroundStyle(palette.textPrimary)
                        Text("/wk")
                            .font(.custom("Baskerville", size: metrics.planUnitSize))
                            .foregroundStyle(palette.textMuted)
                    }
                    Text("\(vm.yearlyPriceLabel(storeKitService))/yr")
                        .font(.custom("Georgia", size: 11))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, metrics.cardVPad)
            .frame(height: metrics.yearlyHeight)
            .background(planCardBackground(isSelected: isSelected, isPrimary: true))
            .overlay(planCardBorder(isSelected: isSelected, isPrimary: true))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            // Corner tag is applied AFTER clipShape so it can ride
            // half-outside the card's top-right corner without being
            // clipped — premium SaaS ribbon-marker pattern. Previously
            // the badge sat inside the ZStack underneath clipShape and
            // its top portion got cut off.
            .overlay(alignment: .topTrailing) {
                Text("BEST VALUE")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentGold.blend(with: .white, amount: 0.12), accentGold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: accentGold.opacity(0.35), radius: 6, y: 2)
                    .offset(x: -10, y: -7)
            }
            .shadow(
                color: isSelected ? accentGold.opacity(0.22) : .black.opacity(0.05),
                radius: isSelected ? 14 : 4,
                y: isSelected ? 6 : 2
            )
            .scaleEffect(isSelected ? 1.010 : 1.0)
            // Reserve vertical space for the badge that protrudes 7pt
            // above the card. Padding the top by 8pt prevents the
            // surrounding VStack from clipping the ribbon when the cards
            // are stacked tightly.
            .padding(.top, 8)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeOut(duration: 0.22), value: isSelected)
    }

    private func selectionRadio(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accentGold : palette.border.opacity(0.55), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            if isSelected {
                Circle()
                    .fill(accentGold)
                    .frame(width: 11, height: 11)
            }
        }
    }

    private func weeklyCard(vm: PaywallViewModel, metrics: Metrics) -> some View {
        let isSelected = vm.selectedProductID == StoreKitService.weeklyID

        return Button {
            vm.selectedProductID = StoreKitService.weeklyID
            HapticService.impact(.medium)
            Analytics.track(.paywallPriceCardSelected, properties: ["product": "weekly"])
        } label: {
            HStack(spacing: 14) {
                selectionRadio(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly")
                        .font(.custom("Baskerville-Bold", size: metrics.planTitleSize))
                        .foregroundStyle(palette.textPrimary)

                    Text("Flexible · Cancel anytime")
                        .font(.custom("Georgia", size: metrics.planMetaSize))
                        .foregroundStyle(palette.textSecondary)
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(vm.weeklyPriceLabel(storeKitService))
                        .font(.custom("Baskerville-Bold", size: metrics.planPriceSize))
                        .foregroundStyle(palette.textPrimary)
                    Text("/wk")
                        .font(.custom("Baskerville", size: metrics.planUnitSize))
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, metrics.cardVPad - 2)
            .frame(height: metrics.weeklyHeight)
            .background(planCardBackground(isSelected: isSelected, isPrimary: false))
            .overlay(planCardBorder(isSelected: isSelected, isPrimary: false))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isSelected ? accentGold.opacity(0.20) : .black.opacity(0.03),
                radius: isSelected ? 12 : 3,
                y: isSelected ? 5 : 1
            )
            .scaleEffect(isSelected ? 1.010 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.easeOut(duration: 0.22), value: isSelected)
    }

    private func planCardBackground(isSelected: Bool, isPrimary: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(palette.surfaceElevated.opacity(isSelected ? 1.0 : 0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentGold.opacity(isSelected ? 0.10 : 0.0),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
    }

    /// Selected → solid gold stroke. Unselected → neutral hairline so
    /// only the chosen card carries the accent. Removes the "two
    /// gold-bordered cards competing" look that diluted hierarchy.
    private func planCardBorder(isSelected: Bool, isPrimary: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                isSelected ? accentGold.opacity(0.85) : palette.border.opacity(0.40),
                lineWidth: isSelected ? 1.6 : 0.7
            )
    }

    // MARK: - Trust Line
    //
    // A single typographic line communicating the three trial guarantees.
    // Replaces the previous dot-and-line timeline — same information,
    // ~⅓ the visual weight, fits cleanly into the rhythm above the CTA.

    private func trustLine(vm: PaywallViewModel) -> some View {
        let isYearly = vm.selectedProductID == StoreKitService.yearlyID
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentGold.opacity(0.75))

            Text(isYearly
                 ? "3 days free, then a reminder before billing"
                 : "Cancel anytime in Settings")
                .font(.custom("Georgia-Italic", size: 11.5))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sticky CTA

    private func stickyCTA(vm: PaywallViewModel) -> some View {
        VStack(spacing: 6) {
            // Trust line sits at the very top of the CTA region so the
            // 3-day-free-trial promise is immediately above the action,
            // not stranded above the plan cards in dead vertical space.
            trustLine(vm: vm)
                .padding(.bottom, 4)

            Button {
                HapticService.impact(.light)
                Analytics.track(.paywallCTATapped, properties: [
                    "product": vm.selectedProductID ?? "unknown",
                ])
                Task { await vm.purchaseSelected(storeKitService: storeKitService, dismiss: dismiss) }
            } label: {
                Text(ctaTitle(vm: vm))
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
                                        accentGold.blend(with: .white, amount: 0.1),
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
                    .scaleEffect(ctaPulse ? 1.018 : 1.0)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(vm.isPurchasing)
            .padding(.horizontal, 24)

            Text(ctaSubtitle(vm: vm))
                .font(.custom("Georgia", size: 11))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 24)

            // Footer is intentionally three items only — the top-right
            // ✕ handles dismissal (and routes to the exit survey during
            // onboarding), so a "Not now" link here would be redundant
            // and dilute the CTA region.
            HStack(spacing: 16) {
                footerLink("Restore") {
                    Analytics.track(.paywallRestoreTapped)
                    Task { await storeKitService.restorePurchases() }
                }
                footerDot
                footerLink("Terms") {
                    if let url = URL(string: "https://bibleplus.io/terms") { openURL(url) }
                }
                footerDot
                footerLink("Privacy") {
                    if let url = URL(string: "https://bibleplus.io/privacy") { openURL(url) }
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: palette.background.opacity(0.0), location: 0.0),
                    .init(color: palette.background.opacity(0.55), location: 0.30),
                    .init(color: palette.background.opacity(0.94), location: 0.65),
                    .init(color: palette.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(showCTA ? 1 : 0)
        .offset(y: showCTA ? 0 : 16)
    }

    private func ctaTitle(vm: PaywallViewModel) -> String {
        if vm.isPurchasing { return "Processing..." }
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "Start 3-Day Free Trial"
        }
        return "Continue with Weekly"
    }

    private func ctaSubtitle(vm: PaywallViewModel) -> String {
        if vm.selectedProductID == StoreKitService.yearlyID {
            return "Then \(vm.yearlyPriceLabel(storeKitService))/yr · Cancel anytime"
        }
        return "\(vm.weeklyPriceLabel(storeKitService))/wk · Cancel anytime"
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Georgia", size: 10.5))
                .foregroundStyle(palette.textMuted)
        }
    }

    private var footerDot: some View {
        Circle().fill(palette.border).frame(width: 2.5, height: 2.5)
    }
}
