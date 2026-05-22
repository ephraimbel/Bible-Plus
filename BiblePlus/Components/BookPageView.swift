import SwiftUI

/// Visual wrapper that makes any content look like a right-hand page in a
/// bound book. Used by the onboarding so each question feels like its own
/// page. The flip animation itself lives in the parent (two-layer
/// orchestration with a rotating outgoing layer), this just handles the
/// paper aesthetic: warm cream background, a soft spine gutter on the
/// leading edge, a hairline gold border, and an optional page-number
/// ornament in the bottom-right corner.
struct BookPageView<Content: View>: View {
    let pageNumber: Int?
    let content: Content

    init(pageNumber: Int? = nil, @ViewBuilder content: () -> Content) {
        self.pageNumber = pageNumber
        self.content = content()
    }

    private let paperLight = Color(red: 0.985, green: 0.962, blue: 0.905)
    private let paperDeep = Color(red: 0.955, green: 0.918, blue: 0.838)
    private let accentGold = Color(red: 0.79, green: 0.66, blue: 0.43)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Paper — slight warm gradient, top lighter than bottom so the
            // page reads as lit from above rather than flat-fill. Extends
            // fully behind the safe area so the page is the screen.
            LinearGradient(
                colors: [paperLight, paperDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Spine gutter — soft darkening along the leading edge. Makes
            // the page read as a right-hand page bound into a book. A
            // touch wider than a card-style page because the gutter lives
            // against the screen edge now, not a card border.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.08),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 28)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Page content — safe-area-respecting, generous margins
            // appropriate for a full-bleed page. Top padding leaves room
            // for the overlaid progress/back bar.
            content
                .padding(.top, 60)
                .padding(.bottom, 72)
                .padding(.leading, 28)
                .padding(.trailing, 22)

            // Page number ornament — small italic roman-style number tucked
            // into the bottom outer corner. No flanking rules — cleaner.
            if let number = pageNumber {
                VStack {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(number)")
                            .font(.custom("Baskerville-Italic", size: 13))
                            .foregroundStyle(accentGold.opacity(0.6))
                            .tracking(0.5)
                    }
                }
                .padding(.bottom, 18)
                .padding(.trailing, 22)
                .allowsHitTesting(false)
            }
        }
    }
}
