import Foundation

// MARK: - Faith Level

enum FaithLevel: String, Codable, CaseIterable, Identifiable {
    case justCurious
    case growing
    case deepInTheWord

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justCurious: "Just Curious"
        case .growing: "Growing"
        case .deepInTheWord: "Deep in the Word"
        }
    }

    var description: String {
        switch self {
        case .justCurious: "I'm exploring faith"
        case .growing: "I'm building my faith"
        case .deepInTheWord: "I study Scripture seriously"
        }
    }

    var icon: String {
        switch self {
        case .justCurious: "sparkles"
        case .growing: "leaf"
        case .deepInTheWord: "book.closed"
        }
    }

    var numericValue: Int {
        switch self {
        case .justCurious: 1
        case .growing: 2
        case .deepInTheWord: 3
        }
    }
}

// MARK: - Life Season

enum LifeSeason: String, Codable, CaseIterable, Identifiable {
    case student
    case workingProfessional
    case parent
    case single
    case married
    case retired
    case hardSeason
    case startingOver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .student: "Student"
        case .workingProfessional: "Working Professional"
        case .parent: "Parent"
        case .single: "Single"
        case .married: "Married"
        case .retired: "Retired / Elder"
        case .hardSeason: "In a Hard Season"
        case .startingOver: "Starting Over"
        }
    }

    var icon: String {
        switch self {
        case .student: "graduationcap"
        case .workingProfessional: "briefcase"
        case .parent: "figure.and.child.holdinghands"
        case .single: "heart"
        case .married: "heart.circle"
        case .retired: "leaf.circle"
        case .hardSeason: "water.waves"
        case .startingOver: "sunrise"
        }
    }
}

// MARK: - Burden

enum Burden: String, Codable, CaseIterable, Identifiable {
    case anxiety
    case grief
    case doubt
    case loneliness
    case anger
    case temptation
    case health
    case financial
    case relationship
    case purpose
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anxiety: "Anxiety & Worry"
        case .grief: "Grief & Loss"
        case .doubt: "Doubt & Uncertainty"
        case .loneliness: "Loneliness"
        case .anger: "Anger & Frustration"
        case .temptation: "Temptation"
        case .health: "Health Concerns"
        case .financial: "Financial Stress"
        case .relationship: "Relationship Pain"
        case .purpose: "Purpose & Direction"
        case .none: "Nothing Specific"
        }
    }

    var icon: String {
        switch self {
        case .anxiety: "cloud.rain"
        case .grief: "heart.slash"
        case .doubt: "questionmark.circle"
        case .loneliness: "person.crop.circle.badge.minus"
        case .anger: "flame"
        case .temptation: "exclamationmark.triangle"
        case .health: "cross.case"
        case .financial: "dollarsign.circle"
        case .relationship: "person.2.slash"
        case .purpose: "compass.drawing"
        case .none: "checkmark.circle"
        }
    }

    func personalizedVerse(name: String) -> String {
        switch self {
        case .anxiety:
            "\(name), cast all your anxiety on Him, because He cares for you. — 1 Peter 5:7"
        case .grief:
            "\(name), the Lord is close to the brokenhearted. He's near you right now."
        case .doubt:
            "\(name), faith isn't the absence of doubt. It's trusting God in the middle of it."
        case .loneliness:
            "\(name), you are never truly alone. The Creator of the universe is with you."
        case .anger:
            "\(name), be quick to listen, slow to speak, slow to anger. — James 1:19"
        case .temptation:
            "\(name), no temptation has overtaken you except what is common. God provides a way out."
        case .health:
            "\(name), He heals the brokenhearted and binds up their wounds. — Psalm 147:3"
        case .financial:
            "\(name), God owns the cattle on a thousand hills. Trust His provision today."
        case .relationship:
            "\(name), love is patient, love is kind. Pray for grace in this season."
        case .purpose:
            "\(name), God is working all things together for your good. The path will become clear."
        case .none:
            "\(name), you're here. That's enough. Let's grow together."
        }
    }
}

// MARK: - Bible Translation

enum BibleTranslation: String, Codable, CaseIterable, Identifiable {
    case niv
    case esv
    case kjv
    case nlt
    case nasb
    case message
    case nkjv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .niv: "NIV"
        case .esv: "ESV"
        case .kjv: "KJV"
        case .nlt: "NLT"
        case .nasb: "NASB"
        case .message: "The Message"
        case .nkjv: "NKJV"
        }
    }

    var subtitle: String {
        switch self {
        case .niv: "Clear and widely trusted"
        case .esv: "Precise and faithful to the original"
        case .kjv: "Classic and poetic"
        case .nlt: "Simple, modern, and easy to read"
        case .nasb: "Word-for-word accuracy"
        case .message: "Conversational and fresh"
        case .nkjv: "Modern update of the classic King James"
        }
    }

    var john316: String {
        switch self {
        case .niv:
            "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."
        case .esv:
            "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life."
        case .kjv:
            "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."
        case .nlt:
            "For this is how God loved the world: He gave his one and only Son, so that everyone who believes in him will not perish but have eternal life."
        case .nasb:
            "For God so loved the world, that He gave His only Son, so that everyone who believes in Him will not perish, but have eternal life."
        case .message:
            "This is how much God loved the world: He gave his Son, his one and only Son. And this is why: so that no one need be destroyed; by believing in him, anyone can have a whole and lasting life."
        case .nkjv:
            "For God so loved the world that He gave His only begotten Son, that whoever believes in Him should not perish but have everlasting life."
        }
    }
}

// MARK: - Prayer Time Slot

enum PrayerTimeSlot: String, Codable, CaseIterable, Identifiable {
    case morning
    case midday
    case evening
    case bedtime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: "Morning"
        case .midday: "Midday"
        case .evening: "Evening"
        case .bedtime: "Before Sleep"
        }
    }

    var timeRange: String {
        switch self {
        case .morning: "6 – 9 AM"
        case .midday: "12 – 1 PM"
        case .evening: "6 – 9 PM"
        case .bedtime: "9 – 11 PM"
        }
    }

    var icon: String {
        switch self {
        case .morning: "sunrise"
        case .midday: "sun.max"
        case .evening: "sunset"
        case .bedtime: "moon.stars"
        }
    }

    func notificationPreview(name: String) -> String {
        switch self {
        case .morning:
            "Good morning, \(name). Here's a word to carry with you today."
        case .midday:
            "\(name), pause for a moment. God is with you right now."
        case .evening:
            "\(name), what did God show you today? Take a moment to reflect."
        case .bedtime:
            "\(name), release your worries. He watches over you as you sleep."
        }
    }
}

// MARK: - Color Mode

enum ColorMode: String, Codable, CaseIterable, Identifiable {
    case light
    case dark
    case auto
    case immersive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Golden Hour"
        case .dark: "Midnight Study"
        case .auto: "Auto"
        case .immersive: "Immersive"
        }
    }
}

// MARK: - Content Type

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case prayer
    case verse
    case devotional
    case quote
    case guidedPrayer
    case reflection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .prayer: "Prayer"
        case .verse: "Bible Verse"
        case .devotional: "Devotional"
        case .quote: "Quote"
        case .guidedPrayer: "Guided Prayer"
        case .reflection: "Reflection"
        }
    }
}

// MARK: - Message Role

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

// MARK: - Share Aspect Ratio

enum ShareAspectRatio: String, CaseIterable, Identifiable {
    case story
    case square
    case wide

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .story: "Story"
        case .square: "Square"
        case .wide: "Wide"
        }
    }

    var size: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .square: CGSize(width: 1080, height: 1080)
        case .wide: CGSize(width: 1920, height: 1080)
        }
    }

    var icon: String {
        switch self {
        case .story: "rectangle.portrait"
        case .square: "square"
        case .wide: "rectangle"
        }
    }
}

// MARK: - Theme Definition

struct ThemeDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let previewGradient: [String] // hex color strings
    let isProOnly: Bool

    static let allThemes: [ThemeDefinition] = [
        ThemeDefinition(
            id: "sunrise-mountains",
            name: "Sunrise Mountains",
            previewGradient: ["FFF1E0", "FFDBB5", "F5EFE0"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "midnight-gold",
            name: "Midnight Gold",
            previewGradient: ["1A1A1A", "242424", "3D3428"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "ocean-peace",
            name: "Ocean Peace",
            previewGradient: ["E8F4F8", "B8D4E3", "89B4C8"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "minimal-cream",
            name: "Minimal Cream",
            previewGradient: ["FAF8F4", "F0E8D8", "E8E0D0"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "forest-mist",
            name: "Forest Mist",
            previewGradient: ["E8F0E8", "C8D8C0", "A0B898"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "starry-night",
            name: "Starry Night",
            previewGradient: ["1A1A3E", "2D2D5E", "C9A96E"],
            isProOnly: false
        ),
    ]
}
