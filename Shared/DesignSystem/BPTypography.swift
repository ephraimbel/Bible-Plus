import SwiftUI

enum BPFont {
    // Prayer/Verse Text (feed) — New York serif, Medium, 16–26pt
    static let prayerLarge = Font.system(size: 26, weight: .medium, design: .serif)
    static let prayerMedium = Font.system(size: 22, weight: .medium, design: .serif)
    static let prayerSmall = Font.system(size: 20, weight: .medium, design: .serif)
    static let prayerXSmall = Font.system(size: 18, weight: .medium, design: .serif)
    static let prayerTiny = Font.system(size: 16, weight: .medium, design: .serif)

    // {Name} in prayers — New York serif, Semibold, 20–26pt
    static let prayerNameLarge = Font.system(size: 26, weight: .semibold, design: .serif)
    static let prayerNameMedium = Font.system(size: 22, weight: .semibold, design: .serif)

    // Bible Reader text — New York serif, Regular, 18–22pt
    static let bibleLarge = Font.system(size: 22, weight: .regular, design: .serif)
    static let bibleMedium = Font.system(size: 20, weight: .regular, design: .serif)
    static let bibleSmall = Font.system(size: 18, weight: .regular, design: .serif)

    // AI Chat messages — SF Pro Rounded, Regular, 16pt
    static let chat = Font.system(size: 16, weight: .regular, design: .rounded)

    // App Headings — SF Pro Rounded, Semibold, 28–34pt
    static let headingLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let headingMedium = Font.system(size: 30, weight: .bold, design: .rounded)
    static let headingSmall = Font.system(size: 28, weight: .semibold, design: .rounded)

    // Body/UI Text — SF Pro Rounded, Regular, 16pt
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)

    // Buttons & Labels — SF Pro Rounded, Medium, 15pt
    static let button = Font.system(size: 15, weight: .medium, design: .rounded)

    // Verse References — New York serif, Light, 13pt
    static let reference = Font.system(size: 13, weight: .light, design: .serif)

    // Small caption — SF Pro Rounded, Regular, 12pt
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)

    // Onboarding subtitle — SF Pro Rounded, Regular, 17pt
    static let onboardingSubtitle = Font.system(size: 17, weight: .regular, design: .rounded)

    // Onboarding Heading — SF Pro Rounded, Semibold, 26pt
    static let onboardingHeading = Font.system(size: 26, weight: .semibold, design: .rounded)

    // Onboarding Body — SF Pro Rounded, Regular, 15pt
    static let onboardingBody = Font.system(size: 15, weight: .regular, design: .rounded)

    // Elegant serif (Georgia) — used for card headers, section titles, and
    // content-voice labels to match the "Ask anything about Scripture" pill
    // and the onboarding/chat serif voice.
    //
    // These are computed — for CJK scripts (Chinese, Japanese, Korean) and
    // Ethiopic (Amharic) Georgia has no glyphs, so iOS would fall back to a
    // default system font that visually breaks the "elegant serif" line.
    // Using `Font.system(design: .serif)` for those locales lets the OS pick
    // the matching locale serif (PingFang / Hiragino / Apple SD Gothic / Kefa)
    // so text renders in a consistent, native-looking weight.
    static var elegantTitle: Font { elegantFont(size: 28, weight: .bold) }
    static var elegantHeadingLarge: Font { elegantFont(size: 22, weight: .bold) }
    static var elegantHeadingMedium: Font { elegantFont(size: 17, weight: .bold) }
    static var elegantHeadingSmall: Font { elegantFont(size: 15, weight: .bold) }
    static var elegantBody: Font { elegantFont(size: 15, weight: .regular) }
    static var elegantSubtitle: Font { elegantFont(size: 13, weight: .regular) }
    static var elegantCaption: Font { elegantFont(size: 11, weight: .regular) }

    /// Scripts where iOS's system `.serif` design is a safer pick than
    /// Georgia. Georgia ships with Latin + Cyrillic + Greek glyphs, so
    /// European languages (es, pt, fr, de, it, pl, ru) look great with it.
    /// These codes cover scripts that Georgia can't render at all.
    private static let glyphGapScripts: Set<String> = [
        "zh-Hans", "zh-Hant", "zh", "ja", "ko", "am", "hi", "bn", "ur", "ar", "he", "fa", "th"
    ]

    private static func elegantFont(size: CGFloat, weight: Font.Weight) -> Font {
        let code = LocalizationService.currentLanguageCode() ?? ""
        if glyphGapScripts.contains(code) {
            return Font.system(size: size, weight: weight, design: .serif)
        }
        let name = weight == .bold ? "Georgia-Bold" : "Georgia"
        return Font.custom(name, size: size)
    }
}
