import SwiftUI

enum BPFont {
    // Prayer/Verse Text (feed) — New York serif, Medium, 20–26pt
    static let prayerLarge = Font.system(size: 26, weight: .medium, design: .serif)
    static let prayerMedium = Font.system(size: 22, weight: .medium, design: .serif)
    static let prayerSmall = Font.system(size: 20, weight: .medium, design: .serif)

    // {Name} in prayers — New York serif, Semibold, 20–26pt
    static let prayerNameLarge = Font.system(size: 26, weight: .semibold, design: .serif)
    static let prayerNameMedium = Font.system(size: 22, weight: .semibold, design: .serif)

    // Bible Reader text — New York serif, Regular, 18–22pt
    static let bibleLarge = Font.system(size: 22, weight: .regular, design: .serif)
    static let bibleMedium = Font.system(size: 20, weight: .regular, design: .serif)
    static let bibleSmall = Font.system(size: 18, weight: .regular, design: .serif)

    // AI Chat messages — SF Pro Text, Regular, 16pt
    static let chat = Font.system(size: 16, weight: .regular, design: .default)

    // App Headings — SF Pro Display, Semibold, 28–34pt
    static let headingLarge = Font.system(size: 34, weight: .semibold, design: .default)
    static let headingMedium = Font.system(size: 30, weight: .semibold, design: .default)
    static let headingSmall = Font.system(size: 28, weight: .semibold, design: .default)

    // Body/UI Text — SF Pro Text, Regular, 16pt
    static let body = Font.system(size: 16, weight: .regular, design: .default)

    // Buttons & Labels — SF Pro Text, Medium, 15pt
    static let button = Font.system(size: 15, weight: .medium, design: .default)

    // Verse References — New York serif, Light, 13pt
    static let reference = Font.system(size: 13, weight: .light, design: .serif)

    // Small caption — SF Pro Text, Regular, 12pt
    static let caption = Font.system(size: 12, weight: .regular, design: .default)

    // Onboarding subtitle — SF Pro Text, Regular, 17pt
    static let onboardingSubtitle = Font.system(size: 17, weight: .regular, design: .default)
}
