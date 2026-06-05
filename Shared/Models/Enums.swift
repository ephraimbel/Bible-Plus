import Foundation
import UIKit
import SwiftUI
import AVFoundation

// MARK: - Faith Level

enum FaithLevel: String, Codable, CaseIterable, Identifiable {
    case justCurious
    case growing
    case deepInTheWord

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justCurious: String(localized: "Just Curious")
        case .growing: String(localized: "Growing")
        case .deepInTheWord: String(localized: "Deep in the Word")
        }
    }

    var description: String {
        switch self {
        case .justCurious: String(localized: "I'm exploring faith")
        case .growing: String(localized: "I'm building my faith")
        case .deepInTheWord: String(localized: "I study Scripture seriously")
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
    // Stage / vocation
    case student
    case workingProfessional
    case entrepreneur
    case military
    // Relationship
    case single
    case dating
    case engaged
    case newlywed
    case married
    // Family
    case newParent
    case parent
    case emptyNester
    case divorced
    case widowed
    case caregiver
    case retired
    // Transition / circumstance
    case betweenJobs
    case careerChange
    case healthJourney
    case newToFaith
    case hardSeason
    case startingOver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .student: String(localized: "Student")
        case .workingProfessional: String(localized: "Working Professional")
        case .entrepreneur: String(localized: "Entrepreneur")
        case .military: String(localized: "Military / Service")
        case .single: String(localized: "Single")
        case .dating: String(localized: "Dating")
        case .engaged: String(localized: "Engaged")
        case .newlywed: String(localized: "Newly Married")
        case .married: String(localized: "Married")
        case .newParent: String(localized: "New Parent")
        case .parent: String(localized: "Parent")
        case .emptyNester: String(localized: "Empty Nester")
        case .divorced: String(localized: "Divorced / Separated")
        case .widowed: String(localized: "Widowed")
        case .caregiver: String(localized: "Caregiver")
        case .retired: String(localized: "Retired / Elder")
        case .betweenJobs: String(localized: "Between Jobs")
        case .careerChange: String(localized: "Career Change")
        case .healthJourney: String(localized: "Health Journey")
        case .newToFaith: String(localized: "New to Faith")
        case .hardSeason: String(localized: "In a Hard Season")
        case .startingOver: String(localized: "Starting Over")
        }
    }

    var icon: String {
        switch self {
        case .student: "graduationcap"
        case .workingProfessional: "briefcase"
        case .entrepreneur: "lightbulb"
        case .military: "shield"
        case .single: "person"
        case .dating: "heart"
        case .engaged: "hands.sparkles"
        case .newlywed: "heart.circle.fill"
        case .married: "heart.circle"
        case .newParent: "stroller"
        case .parent: "figure.and.child.holdinghands"
        case .emptyNester: "house"
        case .divorced: "heart.slash"
        case .widowed: "heart.slash.circle"
        case .caregiver: "heart.text.square"
        case .retired: "leaf.circle"
        case .betweenJobs: "magnifyingglass"
        case .careerChange: "arrow.triangle.2.circlepath"
        case .healthJourney: "cross.case"
        case .newToFaith: "sparkles"
        case .hardSeason: "water.waves"
        case .startingOver: "sunrise"
        }
    }
}

// MARK: - Burden

enum Burden: String, Codable, CaseIterable, Identifiable {
    case anxiety
    case stress
    case depression
    case fear
    case grief
    case doubt
    case anger
    case loneliness
    case shame
    case temptation
    case addiction
    case health
    case financial
    case work
    case relationship
    case marriage
    case family
    case parenting
    case forgiveness
    case purpose
    case selfWorth
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anxiety: String(localized: "Anxiety & Worry")
        case .stress: String(localized: "Stress & Burnout")
        case .depression: String(localized: "Depression & Sadness")
        case .fear: String(localized: "Fear")
        case .grief: String(localized: "Grief & Loss")
        case .doubt: String(localized: "Doubt & Uncertainty")
        case .anger: String(localized: "Anger & Frustration")
        case .loneliness: String(localized: "Loneliness")
        case .shame: String(localized: "Shame & Guilt")
        case .temptation: String(localized: "Temptation")
        case .addiction: String(localized: "Addiction & Habits")
        case .health: String(localized: "Health Concerns")
        case .financial: String(localized: "Financial Stress")
        case .work: String(localized: "Work & Career")
        case .relationship: String(localized: "Relationship Pain")
        case .marriage: String(localized: "Marriage Struggles")
        case .family: String(localized: "Family Conflict")
        case .parenting: String(localized: "Parenting")
        case .forgiveness: String(localized: "Forgiveness")
        case .purpose: String(localized: "Purpose & Direction")
        case .selfWorth: String(localized: "Self-Worth & Identity")
        case .none: String(localized: "Nothing Specific")
        }
    }

    var icon: String {
        switch self {
        case .anxiety: "cloud.rain"
        case .stress: "bolt.heart"
        case .depression: "cloud.fill"
        case .fear: "exclamationmark.shield"
        case .grief: "heart.slash"
        case .doubt: "questionmark.circle"
        case .anger: "flame"
        case .loneliness: "person.crop.circle.badge.minus"
        case .shame: "eye.slash"
        case .temptation: "exclamationmark.triangle"
        case .addiction: "arrow.triangle.2.circlepath"
        case .health: "cross.case"
        case .financial: "dollarsign.circle"
        case .work: "briefcase"
        case .relationship: "person.2.slash"
        case .marriage: "heart.slash.circle"
        case .family: "house"
        case .parenting: "figure.and.child.holdinghands"
        case .forgiveness: "hands.sparkles"
        case .purpose: "compass.drawing"
        case .selfWorth: "person.fill.questionmark"
        case .none: "checkmark.circle"
        }
    }

    func personalizedVerse(name: String) -> String {
        switch self {
        case .anxiety:
            "\(name), cast all your anxiety on Him, because He cares for you. — 1 Peter 5:7"
        case .stress:
            "\(name), come to Me, all who are weary and burdened, and I will give you rest. — Matthew 11:28"
        case .depression:
            "\(name), the Lord is near to the brokenhearted. Joy comes in the morning. — Psalm 34:18"
        case .fear:
            "\(name), do not fear, for I am with you; I am your God. — Isaiah 41:10"
        case .grief:
            "\(name), the Lord is close to the brokenhearted. He's near you right now."
        case .doubt:
            "\(name), faith isn't the absence of doubt. It's trusting God in the middle of it."
        case .anger:
            "\(name), be quick to listen, slow to speak, slow to anger. — James 1:19"
        case .loneliness:
            "\(name), you are never truly alone. The Creator of the universe is with you."
        case .shame:
            "\(name), there is now no condemnation for those in Christ Jesus. You are not your worst moment."
        case .temptation:
            "\(name), no temptation has overtaken you except what is common. God provides a way out."
        case .addiction:
            "\(name), where the Spirit of the Lord is, there is freedom. He is setting you free."
        case .health:
            "\(name), He heals the brokenhearted and binds up their wounds. — Psalm 147:3"
        case .financial:
            "\(name), God owns the cattle on a thousand hills. Trust His provision today."
        case .work:
            "\(name), whatever you do, work at it with all your heart, as for the Lord. He sees you."
        case .relationship:
            "\(name), love is patient, love is kind. Pray for grace in this season."
        case .marriage:
            "\(name), may grace fill your home and soften every word. Love covers a multitude."
        case .family:
            "\(name), as for me and my house, we will serve the Lord. He can restore what feels broken."
        case .parenting:
            "\(name), train up a child in the way they should go. You're doing holy work — lean on His strength."
        case .forgiveness:
            "\(name), be kind and compassionate, forgiving as in Christ God forgave you. — Ephesians 4:32"
        case .purpose:
            "\(name), God is working all things together for your good. The path will become clear."
        case .selfWorth:
            "\(name), you are fearfully and wonderfully made. You are His, and that is enough."
        case .none:
            "\(name), you're here. That's enough. Let's grow together."
        }
    }
}

// MARK: - Gender
//
// Used only to make onboarding copy feel personal ("walking with you"). Light
// personalization — never gates content.

enum Gender: String, Codable, CaseIterable, Identifiable {
    case woman
    case man

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .woman: String(localized: "Woman")
        case .man: String(localized: "Man")
        }
    }
}

// MARK: - Christian Background
//
// A broad denomination/tradition list so users can self-identify precisely.
// Ordered roughly by prevalence, with the catch-alls ("Other", "Still
// exploring") last. Used to tailor language/tone — never gates content.

enum ChristianBackground: String, Codable, CaseIterable, Identifiable {
    case christian
    case catholic
    case baptist
    case nonDenominational
    case methodist
    case pentecostal
    case evangelical
    case lutheran
    case presbyterian
    case anglican
    case reformed
    case easternOrthodox
    case orientalOrthodox
    case adventist
    case assembliesOfGod
    case churchOfChrist
    case nazarene
    case anabaptist
    case quaker
    case latterDaySaint
    case jehovahsWitness
    case other
    case exploring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .christian: String(localized: "Christian")
        case .catholic: String(localized: "Catholic")
        case .baptist: String(localized: "Baptist")
        case .nonDenominational: String(localized: "Non-denominational")
        case .methodist: String(localized: "Methodist")
        case .pentecostal: String(localized: "Pentecostal")
        case .evangelical: String(localized: "Evangelical")
        case .lutheran: String(localized: "Lutheran")
        case .presbyterian: String(localized: "Presbyterian")
        case .anglican: String(localized: "Anglican / Episcopal")
        case .reformed: String(localized: "Reformed")
        case .easternOrthodox: String(localized: "Eastern Orthodox")
        case .orientalOrthodox: String(localized: "Oriental Orthodox")
        case .adventist: String(localized: "Seventh-day Adventist")
        case .assembliesOfGod: String(localized: "Assemblies of God")
        case .churchOfChrist: String(localized: "Church of Christ")
        case .nazarene: String(localized: "Nazarene")
        case .anabaptist: String(localized: "Mennonite / Anabaptist")
        case .quaker: String(localized: "Quaker")
        case .latterDaySaint: String(localized: "Latter-day Saint")
        case .jehovahsWitness: String(localized: "Jehovah's Witness")
        case .other: String(localized: "Other")
        case .exploring: String(localized: "Still exploring")
        }
    }
}

// MARK: - Devotion Frequency
//
// The BEHAVIORAL baseline — how often the user currently spends time in the
// Word/prayer right now. Deliberately distinct from `FaithLevel` (which is
// IDENTITY/maturity) so the two questions never feel redundant. Combines
// reading + prayer into one question on purpose. Sets the "before" the daily
// rhythm builds on.

enum DevotionFrequency: String, Codable, CaseIterable, Identifiable {
    case notYet
    case onceInAWhile
    case fewTimesAWeek
    case mostDays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notYet: String(localized: "Not yet — I'm just starting")
        case .onceInAWhile: String(localized: "Once in a while")
        case .fewTimesAWeek: String(localized: "A few times a week")
        case .mostDays: String(localized: "Most days")
        }
    }
}

// MARK: - Growth Blocker
//
// Practical obstacles to building a daily habit. Kept strictly about what gets
// in the WAY of showing up (busyness, distraction) so it doesn't overlap with
// `Burden` (life pains like grief/anxiety). Multi-select.

enum GrowthBlocker: String, Codable, CaseIterable, Identifiable {
    case busyness
    case distraction
    case whereToStart
    case consistency
    case tooTired
    case boredom
    case comprehension
    case focus
    case accountability
    case unworthy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .busyness: String(localized: "I'm too busy")
        case .distraction: String(localized: "Too many distractions")
        case .whereToStart: String(localized: "Don't know where to start")
        case .consistency: String(localized: "I lose consistency")
        case .tooTired: String(localized: "Too tired or drained")
        case .boredom: String(localized: "It starts to feel boring")
        case .comprehension: String(localized: "Hard to understand the Bible")
        case .focus: String(localized: "Hard to stay focused")
        case .accountability: String(localized: "No one to keep me going")
        case .unworthy: String(localized: "I feel unworthy")
        }
    }
}

// MARK: - App Goal
//
// Forward-looking aspirations — what the user wants OUT of the app. Drives the
// "Your Plan" reveal. Multi-select.

enum AppGoal: String, Codable, CaseIterable, Identifiable {
    case closerToGod
    case dailyHabit
    case peace
    case understandBible
    case prayConsistently
    case hearFromGod
    case overcomeStruggle
    case readWholeBible
    case memorizeScripture
    case strengthenFamily
    case gratitude
    case shareFaith

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .closerToGod: String(localized: "Grow closer to God")
        case .dailyHabit: String(localized: "Build a daily habit")
        case .peace: String(localized: "Find peace & calm")
        case .understandBible: String(localized: "Understand the Bible")
        case .prayConsistently: String(localized: "Pray consistently")
        case .hearFromGod: String(localized: "Hear from God")
        case .overcomeStruggle: String(localized: "Overcome a struggle")
        case .readWholeBible: String(localized: "Read the whole Bible")
        case .memorizeScripture: String(localized: "Memorize Scripture")
        case .strengthenFamily: String(localized: "Strengthen my family")
        case .gratitude: String(localized: "Grow in gratitude")
        case .shareFaith: String(localized: "Share my faith")
        }
    }
}

// MARK: - Time Commitment

enum TimeCommitment: String, Codable, CaseIterable, Identifiable {
    case threeMin
    case fiveMin
    case tenMin
    case fifteenPlus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeMin: String(localized: "3 minutes")
        case .fiveMin: String(localized: "5 minutes")
        case .tenMin: String(localized: "10 minutes")
        case .fifteenPlus: String(localized: "15+ minutes")
        }
    }

    /// Bare number for inline copy ("a 5-minute daily rhythm").
    var minutesLabel: String {
        switch self {
        case .threeMin: "3"
        case .fiveMin: "5"
        case .tenMin: "10"
        case .fifteenPlus: "15"
        }
    }
}

// MARK: - Referral Source
//
// Pure attribution — where the user heard about the app. No personalization
// value; collected for marketing insight.

enum ReferralSource: String, Codable, CaseIterable, Identifiable {
    case appStore
    case friendOrFamily
    case instagramFacebook
    case tiktok
    case youtube
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appStore: String(localized: "App Store")
        case .friendOrFamily: String(localized: "Friend or family")
        case .instagramFacebook: String(localized: "Instagram / Facebook")
        case .tiktok: String(localized: "TikTok")
        case .youtube: String(localized: "YouTube")
        case .other: String(localized: "Somewhere else")
        }
    }
}

// MARK: - Bible Translation

enum BibleTranslation: String, Codable, CaseIterable, Identifiable {
    case kjv
    case web
    case niv
    case esv
    case nlt
    case nasb
    case message
    case nkjv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kjv: String(localized: "King James Version")
        case .web: String(localized: "World English Bible")
        case .niv: String(localized: "New International Version")
        case .esv: String(localized: "English Standard Version")
        case .nlt: String(localized: "New Living Translation")
        case .nasb: String(localized: "New American Standard Bible")
        case .message: String(localized: "The Message")
        case .nkjv: String(localized: "New King James Version")
        }
    }

    /// Short abbreviation shown in compact UI (toolbar badge, etc.)
    var abbreviation: String {
        switch self {
        case .kjv: "KJV"
        case .web: "WEB"
        case .niv: "NIV"
        case .esv: "ESV"
        case .nlt: "NLT"
        case .nasb: "NASB"
        case .message: "MSG"
        case .nkjv: "NKJV"
        }
    }

    var subtitle: String {
        switch self {
        case .kjv: String(localized: "Classic and poetic language")
        case .web: String(localized: "Modern English, public domain")
        case .niv: String(localized: "Clear, accurate, and widely trusted")
        case .esv: String(localized: "Precise and faithful to the original texts")
        case .nlt: String(localized: "Simple, natural, and easy to read")
        case .nasb: String(localized: "Literal word-for-word accuracy")
        case .message: String(localized: "Conversational and contemporary paraphrase")
        case .nkjv: String(localized: "Modern update of the classic King James")
        }
    }

    var apiCode: String {
        switch self {
        case .kjv: "KJV"
        case .web: "WEB"
        case .niv: "NIV"
        case .esv: "ESV"
        case .nlt: "NLT"
        case .nasb: "NASB"
        case .message: "MSG"
        case .nkjv: "NKJV"
        }
    }

    /// Whether this translation is bundled offline (public domain).
    var isBundled: Bool {
        switch self {
        case .kjv, .web: true
        default: false
        }
    }

    /// Whether this translation requires Pro subscription.
    var isProOnly: Bool {
        switch self {
        case .kjv, .web: false
        default: true
        }
    }

    var john316: String {
        switch self {
        case .kjv:
            "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."
        case .web:
            "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life."
        case .niv:
            "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."
        case .esv:
            "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life."
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
        case .morning: String(localized: "Morning")
        case .midday: String(localized: "Midday")
        case .evening: String(localized: "Evening")
        case .bedtime: String(localized: "Before Sleep")
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

    func notificationSubtitles(name: String) -> [String] {
        switch self {
        case .morning:
            [
                "Good morning, \(name). Here's a word to carry with you today.",
                "Rise and shine, \(name). God has something for you this morning.",
                "\(name), start your day in His presence.",
                "A new morning, a new mercy. Good morning, \(name).",
                "Before the rush begins, \(name) — a moment with God.",
                "\(name), today is full of possibility. Start here.",
                "His mercies are new this morning, \(name).",
                "Good morning, \(name). You are seen and loved today.",
                "A new mercy for a new morning, \(name).",
                "Before the world gets loud, \(name)...",
                "\(name), grace meets you right where you are this morning.",
                "First things first, \(name). He comes before everything.",
                "Good morning, \(name). Walk boldly into this day.",
                "\(name), the One who made the sunrise is thinking of you.",
                "Morning by morning, \(name). He is faithful.",
                "\(name), let this truth set the tone for your whole day.",
            ]
        case .midday:
            [
                "\(name), pause for a moment. God is with you right now.",
                "Midday check-in, \(name). Take a breath and lean on Him.",
                "\(name), He sees your afternoon. Rest in that.",
                "A word for your afternoon, \(name).",
                "Still standing, \(name). Here's fuel for the rest of your day.",
                "\(name), breathe. He's right here with you.",
                "Halfway through, \(name). Let this refuel you.",
                "A moment of peace in your busy day, \(name).",
                "Right where you are, \(name), God is.",
                "\(name), don't forget who's carrying you today.",
                "A gentle reminder for your afternoon, \(name).",
                "\(name), strength for the second half of your day.",
                "In the middle of it all, \(name) — He is still good.",
                "\(name), this moment is a gift. Receive it.",
                "Take thirty seconds, \(name). Just breathe and believe.",
                "\(name), you're doing better than you think.",
            ]
        case .evening:
            [
                "\(name), what did God show you today? Take a moment to reflect.",
                "Good evening, \(name). Reflect on today's blessings.",
                "\(name), unwind with a word from the Lord.",
                "The day is fading, \(name). Let His peace settle in.",
                "The day is winding down, \(name). Breathe and receive.",
                "\(name), you made it through today. Here's a gift for tonight.",
                "Before you rest, \(name) — one more truth to hold onto.",
                "\(name), let tonight be about gratitude.",
                "Take this moment to be still, \(name).",
                "\(name), exhale. You are held tonight.",
                "As the sun sets, \(name), His faithfulness remains.",
                "\(name), look back on today — where did you see God?",
                "Evening peace for you, \(name). Let go and let God.",
                "\(name), you carried a lot today. Set it down now.",
                "The evening is yours, \(name). Rest in His goodness.",
                "\(name), end this day the way you started — with Him.",
            ]
        case .bedtime:
            [
                "\(name), release your worries. He watches over you as you sleep.",
                "Rest well, \(name). His angels guard your sleep.",
                "\(name), lay it all down. Tomorrow is in His hands.",
                "Goodnight, \(name). Let this truth carry you to sleep.",
                "Sleep in peace, \(name). He is your shield tonight.",
                "\(name), close your eyes knowing you are deeply loved.",
                "The day is done, \(name). Let this truth follow you into dreams.",
                "One last word before sleep, \(name). You are not alone.",
                "Sleep in His peace tonight, \(name).",
                "Tomorrow is in His hands, \(name). Rest now.",
                "\(name), He neither slumbers nor sleeps. You can.",
                "Goodnight, \(name). You are safe in the Father's arms.",
                "\(name), let your last thought tonight be of His love.",
                "The night is quiet, \(name). So is His faithfulness.",
                "\(name), nothing can separate you from His love. Sleep well.",
                "Pillow talk with God, \(name). He's listening.",
            ]
        }
    }

    func notificationPreview(name: String) -> String {
        notificationSubtitles(name: name).randomElement()
            ?? "Open your heart to God's word today."
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
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        case .auto: String(localized: "Auto")
        case .immersive: String(localized: "Immersive")
        }
    }
}

// MARK: - Content Type

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case prayer
    case verse
    case devotional
    case quote
    case reflection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .prayer: String(localized: "Prayer")
        case .verse: String(localized: "Bible Verse")
        case .devotional: String(localized: "Devotional")
        case .quote: String(localized: "Quote")
        case .reflection: String(localized: "Reflection")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ContentType(rawValue: raw) ?? .prayer
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
        case .story: String(localized: "Story")
        case .square: String(localized: "Square")
        case .wide: String(localized: "Wide")
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

// MARK: - Soundscape

enum Soundscape: String, Codable, CaseIterable, Identifiable {
    // Free
    case stillWaters
    case morningLight
    case eveningRest
    case pureSilence
    // Pro — Nature
    case forestBirds
    case babblingBrook
    case gentleBreeze
    case nightCrickets
    case gentleWaves
    case gentleWaterfall
    case thunderstorm
    case morningDew
    case whaleSong
    // Pro — Ambient & Music
    case peacefulPiano
    case softFlute
    case softGuitar
    case heavenlyHarp
    case singingBowls
    case tibetanBells
    case gregorianChant
    case celestialVoices
    case worshipPads
    case deepSpace
    // Pro — Classic
    case gardenPrayer
    case mountainTop
    case nightWatch
    case oceanOfGrace
    case heavenlyWorship
    case rainOfBlessing
    case fireplace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stillWaters: String(localized: "Still Waters")
        case .morningLight: String(localized: "Morning Light")
        case .eveningRest: String(localized: "Evening Rest")
        case .pureSilence: String(localized: "Pure Silence")
        case .forestBirds: String(localized: "Forest Birds")
        case .babblingBrook: String(localized: "Babbling Brook")
        case .gentleBreeze: String(localized: "Gentle Breeze")
        case .nightCrickets: String(localized: "Night Crickets")
        case .gentleWaves: String(localized: "Gentle Waves")
        case .gentleWaterfall: String(localized: "Gentle Waterfall")
        case .thunderstorm: String(localized: "Thunderstorm")
        case .morningDew: String(localized: "Morning Dew")
        case .whaleSong: String(localized: "Whale Song")
        case .peacefulPiano: String(localized: "Peaceful Piano")
        case .softFlute: String(localized: "Soft Flute")
        case .softGuitar: String(localized: "Soft Guitar")
        case .heavenlyHarp: String(localized: "Heavenly Harp")
        case .singingBowls: String(localized: "Singing Bowls")
        case .tibetanBells: String(localized: "Tibetan Bells")
        case .gregorianChant: String(localized: "Gregorian Chant")
        case .celestialVoices: String(localized: "Celestial Voices")
        case .worshipPads: String(localized: "Worship Pads")
        case .deepSpace: String(localized: "Deep Space")
        case .gardenPrayer: String(localized: "Garden Prayer")
        case .mountainTop: String(localized: "Mountain Top")
        case .nightWatch: String(localized: "Night Watch")
        case .oceanOfGrace: String(localized: "Ocean of Grace")
        case .heavenlyWorship: String(localized: "Heavenly Worship")
        case .rainOfBlessing: String(localized: "Rain of Blessing")
        case .fireplace: String(localized: "Fireplace")
        }
    }

    var description: String {
        switch self {
        case .stillWaters: String(localized: "Gentle flowing water for peaceful meditation")
        case .morningLight: String(localized: "Soft piano and birds to start your day")
        case .eveningRest: String(localized: "Warm ambient tones for winding down")
        case .pureSilence: String(localized: "No sound — just you and God")
        case .forestBirds: String(localized: "Birdsong in a peaceful forest canopy")
        case .babblingBrook: String(localized: "Flowing stream through a quiet woodland")
        case .gentleBreeze: String(localized: "Soft wind whispering through the trees")
        case .nightCrickets: String(localized: "Crickets chirping under a starlit sky")
        case .gentleWaves: String(localized: "Calm ocean waves lapping at the shore")
        case .gentleWaterfall: String(localized: "Soothing cascade of falling water")
        case .thunderstorm: String(localized: "Distant thunder and steady rain")
        case .morningDew: String(localized: "Peaceful dawn with soft nature sounds")
        case .whaleSong: String(localized: "Majestic whale calls in the deep ocean")
        case .peacefulPiano: String(localized: "Soft solo piano for quiet reflection")
        case .softFlute: String(localized: "Delicate flute melodies for meditation")
        case .softGuitar: String(localized: "Gentle acoustic guitar for devotion")
        case .heavenlyHarp: String(localized: "Soothing harp melodies for worship")
        case .singingBowls: String(localized: "Resonant singing bowls for deep meditation")
        case .tibetanBells: String(localized: "Harmonic bell tones for contemplation")
        case .gregorianChant: String(localized: "Ancient monastic chanting for contemplation")
        case .celestialVoices: String(localized: "Ethereal vocal harmonies for prayer")
        case .worshipPads: String(localized: "Ambient atmosphere for prayerful moments")
        case .deepSpace: String(localized: "Cosmic ambient tones for wonder and awe")
        case .gardenPrayer: String(localized: "Nature sounds with gentle wind")
        case .mountainTop: String(localized: "Sweeping atmosphere for deep worship")
        case .nightWatch: String(localized: "Deep midnight ambience for late prayers")
        case .oceanOfGrace: String(localized: "Rolling waves and distant shore")
        case .heavenlyWorship: String(localized: "Ethereal pads and soft vocals")
        case .rainOfBlessing: String(localized: "Gentle rainfall with distant thunder")
        case .fireplace: String(localized: "Warm crackling fire for cozy devotions")
        }
    }

    var icon: String {
        switch self {
        case .stillWaters: "drop"
        case .morningLight: "sunrise"
        case .eveningRest: "moon.haze"
        case .pureSilence: "speaker.slash"
        case .forestBirds: "bird"
        case .babblingBrook: "humidity"
        case .gentleBreeze: "wind"
        case .nightCrickets: "moon.stars.fill"
        case .gentleWaves: "water.waves"
        case .gentleWaterfall: "drop.triangle"
        case .thunderstorm: "cloud.bolt.rain"
        case .morningDew: "sun.and.horizon"
        case .whaleSong: "fish"
        case .peacefulPiano: "pianokeys"
        case .softFlute: "music.note"
        case .softGuitar: "guitars"
        case .heavenlyHarp: "guitars.fill"
        case .singingBowls: "bell"
        case .tibetanBells: "bell.and.waves.left.and.right"
        case .gregorianChant: "building.columns"
        case .celestialVoices: "person.and.background.dotted"
        case .worshipPads: "waveform"
        case .deepSpace: "sparkle"
        case .gardenPrayer: "leaf"
        case .mountainTop: "mountain.2"
        case .nightWatch: "moon.stars"
        case .oceanOfGrace: "water.waves"
        case .heavenlyWorship: "sparkles"
        case .rainOfBlessing: "cloud.rain"
        case .fireplace: "flame"
        }
    }

    var fileName: String? {
        switch self {
        case .pureSilence: nil
        default: rawValue
        }
    }

    var isProOnly: Bool {
        switch self {
        case .pureSilence:
            false
        default:
            true
        }
    }

    var isAvailable: Bool {
        guard let fileName else { return true } // pureSilence always available
        return Bundle.main.url(forResource: fileName, withExtension: "m4a") != nil
    }

    static var freeSoundscapes: [Soundscape] {
        allCases.filter { !$0.isProOnly }
    }

    static var proSoundscapes: [Soundscape] {
        allCases.filter { $0.isProOnly }
    }

    static var natureSoundscapes: [Soundscape] {
        [.forestBirds, .babblingBrook, .gentleBreeze, .nightCrickets, .gentleWaves,
         .gentleWaterfall, .thunderstorm, .morningDew, .whaleSong]
    }

    static var ambientSoundscapes: [Soundscape] {
        [.peacefulPiano, .softFlute, .softGuitar, .heavenlyHarp, .singingBowls,
         .tibetanBells, .gregorianChant, .celestialVoices, .worshipPads, .deepSpace]
    }

    static var classicSoundscapes: [Soundscape] {
        [.gardenPrayer, .mountainTop, .nightWatch, .oceanOfGrace,
         .heavenlyWorship, .rainOfBlessing, .fireplace]
    }
}

// MARK: - Sleep Timer Duration

enum SleepTimerDuration: String, CaseIterable, Identifiable {
    case fifteenMin
    case thirtyMin
    case oneHour
    case twoHours
    case untilClose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fifteenMin: String(localized: "15 Minutes")
        case .thirtyMin: String(localized: "30 Minutes")
        case .oneHour: String(localized: "1 Hour")
        case .twoHours: String(localized: "2 Hours")
        case .untilClose: String(localized: "Until I Close")
        }
    }

    var timeInterval: TimeInterval? {
        switch self {
        case .fifteenMin: 15 * 60
        case .thirtyMin: 30 * 60
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        case .untilClose: nil
        }
    }
}

// MARK: - Background Collection

enum BackgroundCollection: String, CaseIterable, Identifiable {
    case essentials
    case nature
    case oceanAndWater
    case nightSky
    case warmthAndGlow
    case calmAndSerene
    case sacred
    case heavenly
    case seasonal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essentials: String(localized: "Essentials")
        case .nature: String(localized: "Nature")
        case .oceanAndWater: String(localized: "Ocean & Water")
        case .nightSky: String(localized: "Night Sky")
        case .warmthAndGlow: String(localized: "Warmth & Glow")
        case .calmAndSerene: String(localized: "Calm & Serene")
        case .sacred: String(localized: "Sacred")
        case .heavenly: String(localized: "Heavenly")
        case .seasonal: String(localized: "Seasonal")
        }
    }

    var isProOnly: Bool {
        switch self {
        case .essentials: false
        case .nature, .oceanAndWater, .nightSky, .warmthAndGlow, .calmAndSerene, .sacred, .heavenly, .seasonal: true
        }
    }
}

// MARK: - Sanctuary Background

struct SanctuaryBackground: Identifiable, Hashable {
    let id: String
    let name: String
    let collection: BackgroundCollection
    let gradientColors: [String]
    let imageName: String?
    let videoFileName: String?
    let isProOnly: Bool

    var hasVideo: Bool { videoFileName != nil }
    var hasImage: Bool { imageName != nil }

    private static var imageCache: [String: UIImage] = [:]
    private static var videoThumbnailCache: [String: UIImage] = [:]

    static func loadImage(named name: String) -> UIImage? {
        if let cached = imageCache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache[name] = image
        return image
    }

    static func loadVideoThumbnail(named videoName: String) -> UIImage? {
        if let cached = videoThumbnailCache[videoName] { return cached }
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else { return nil }
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 1200)
        for seconds in [2.0, 1.0, 0.5] {
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                videoThumbnailCache[videoName] = image
                return image
            }
        }
        return nil
    }

    init(id: String, name: String, collection: BackgroundCollection, gradientColors: [String], imageName: String? = nil, videoFileName: String? = nil, isProOnly: Bool = false) {
        self.id = id
        self.name = name
        self.collection = collection
        self.gradientColors = gradientColors
        self.imageName = imageName
        self.videoFileName = videoFileName
        self.isProOnly = isProOnly
    }

    static let allBackgrounds: [SanctuaryBackground] = {
        var bgs: [SanctuaryBackground] = []

        // MARK: Essentials (12 free gradients)
        bgs.append(contentsOf: [
            SanctuaryBackground(id: "warm-gold", name: "Warm Gold", collection: .essentials, gradientColors: ["C9A96E", "D4B483", "F0E8D8"]),
            SanctuaryBackground(id: "soft-cream", name: "Soft Cream", collection: .essentials, gradientColors: ["FAF8F4", "F0E8D8", "E8DCC8"]),
            SanctuaryBackground(id: "forest-dawn", name: "Forest Dawn", collection: .essentials, gradientColors: ["2D5016", "4A7A2E", "8FB174"]),
            SanctuaryBackground(id: "mountain-mist", name: "Mountain Mist", collection: .essentials, gradientColors: ["6B7B8D", "9AACBD", "C8D5E0"]),
            SanctuaryBackground(id: "desert-sun", name: "Desert Sun", collection: .essentials, gradientColors: ["C2842F", "D4A054", "F0D8A0"]),
            SanctuaryBackground(id: "twilight-lake", name: "Twilight Lake", collection: .essentials, gradientColors: ["1A2744", "3A4F6E", "6E8AAA"]),
            SanctuaryBackground(id: "meadow-green", name: "Meadow Green", collection: .essentials, gradientColors: ["3A6B35", "5C9454", "A8D5A0"]),
            SanctuaryBackground(id: "royal-purple", name: "Royal Purple", collection: .essentials, gradientColors: ["2D1B4E", "4A2C7A", "7B52AB"]),
            SanctuaryBackground(id: "ember-glow", name: "Ember Glow", collection: .essentials, gradientColors: ["4A1A1A", "7A2D2D", "A04040"]),
            SanctuaryBackground(id: "midnight-blue", name: "Midnight Blue", collection: .essentials, gradientColors: ["0A1628", "1A2D50", "2A4478"]),
            SanctuaryBackground(id: "rose-gold", name: "Rose Gold", collection: .essentials, gradientColors: ["8B6B61", "B89485", "E0C4B8"]),
            SanctuaryBackground(id: "steel-grey", name: "Steel Grey", collection: .essentials, gradientColors: ["2C2C2C", "484848", "6A6A6A"]),
        ])

        // MARK: Nature (64 — all Pro)
        bgs.append(contentsOf: [
            // Animated Videos
            SanctuaryBackground(id: "forest-sunlight", name: "Forest Sunlight", collection: .nature, gradientColors: ["1A3D0A", "2D6B1A", "5C9A3A"], videoFileName: "forest-sunlight", isProOnly: true),
            SanctuaryBackground(id: "gentle-waterfall", name: "Gentle Waterfall", collection: .nature, gradientColors: ["1A4A5C", "2D7A9A", "5AACCC"], videoFileName: "gentle-waterfall", isProOnly: true),
            SanctuaryBackground(id: "misty-mountains", name: "Misty Mountains", collection: .nature, gradientColors: ["4A5A6A", "6A7A8A", "9AACBC"], videoFileName: "misty-mountains", isProOnly: true),
            SanctuaryBackground(id: "cherry-blossoms", name: "Cherry Blossoms", collection: .nature, gradientColors: ["8B3060", "C06090", "E8A0BF"], videoFileName: "cherry-blossoms", isProOnly: true),
            SanctuaryBackground(id: "autumn-leaves", name: "Autumn Leaves", collection: .nature, gradientColors: ["6B2D10", "A05020", "D48040"], videoFileName: "autumn-leaves", isProOnly: true),
            SanctuaryBackground(id: "wheat-field-wind", name: "Wheat Field", collection: .nature, gradientColors: ["6B5A1A", "9A8430", "C8B060"], videoFileName: "wheat-field-wind", isProOnly: true),
            SanctuaryBackground(id: "morning-fog-lake", name: "Morning Fog Lake", collection: .nature, gradientColors: ["3A4A5A", "5A7A8A", "8AACBC"], videoFileName: "morning-fog-lake", isProOnly: true),
            SanctuaryBackground(id: "desert-dunes", name: "Desert Dunes", collection: .nature, gradientColors: ["8B6A3A", "B89060", "D8B888"], videoFileName: "desert-dunes", isProOnly: true),
            SanctuaryBackground(id: "golden-flower-field", name: "Golden Flowers", collection: .nature, gradientColors: ["6B5A1A", "9A8430", "C8B060"], videoFileName: "golden-flower-field", isProOnly: true),
            SanctuaryBackground(id: "sunbeams-forest-video", name: "Sunbeams in Forest", collection: .nature, gradientColors: ["1A3A0A", "3A6A1A", "5A9A3A"], videoFileName: "sunbeams-forest", isProOnly: true),
            SanctuaryBackground(id: "golden-forest-light-video", name: "Golden Forest Light", collection: .nature, gradientColors: ["3A2A0A", "6A5A1A", "9A8A3A"], videoFileName: "golden-forest-light", isProOnly: true),
            SanctuaryBackground(id: "forest-morning-rays-video", name: "Forest Morning Rays", collection: .nature, gradientColors: ["1A2A0A", "3A5A1A", "5A7A3A"], videoFileName: "forest-morning-rays", isProOnly: true),
            SanctuaryBackground(id: "dappled-forest-sun-video", name: "Dappled Sunlight", collection: .nature, gradientColors: ["2A4A1A", "4A6A2A", "6A8A4A"], videoFileName: "dappled-forest-sun", isProOnly: true),
            SanctuaryBackground(id: "wildflowers-swaying-video", name: "Wildflowers Swaying", collection: .nature, gradientColors: ["4A6A1A", "7A9A2A", "A0C04A"], videoFileName: "wildflowers-swaying", isProOnly: true),
            SanctuaryBackground(id: "meadow-flowers-video", name: "Meadow Flowers", collection: .nature, gradientColors: ["3A5A2A", "5A8A4A", "8AB06A"], videoFileName: "meadow-flowers-breeze", isProOnly: true),
            SanctuaryBackground(id: "sunflower-field-wind-video", name: "Sunflower Wind", collection: .nature, gradientColors: ["5A4A0A", "8A7A1A", "B0A030"], videoFileName: "sunflower-field-wind", isProOnly: true),
            SanctuaryBackground(id: "alpine-lake-still-video", name: "Alpine Lake", collection: .nature, gradientColors: ["1A3A5A", "2D5A7A", "4A8AAA"], videoFileName: "alpine-lake-still", isProOnly: true),
            // Additional nature gradients
            SanctuaryBackground(id: "bamboo-forest-wind", name: "Bamboo Forest", collection: .nature, gradientColors: ["1A3A1A", "3A6A2A", "5A8A4A"], isProOnly: true),
            SanctuaryBackground(id: "river-flowing", name: "Flowing River", collection: .nature, gradientColors: ["1A3A4A", "2D5A6A", "4A8A9A"], isProOnly: true),
            SanctuaryBackground(id: "wildflower-breeze", name: "Wildflower Breeze", collection: .nature, gradientColors: ["4A6A2A", "7A9A4A", "A0C06A"], isProOnly: true),
            SanctuaryBackground(id: "lavender-fields", name: "Lavender Fields", collection: .nature, gradientColors: ["4A3A6A", "6B5B8A", "8A7AAA"], isProOnly: true),
            SanctuaryBackground(id: "sunflower-field", name: "Sunflower Field", collection: .nature, gradientColors: ["5A4A0A", "8A7A1A", "B0A030"], isProOnly: true),
            SanctuaryBackground(id: "birch-forest-light", name: "Birch Forest", collection: .nature, gradientColors: ["4A5A3A", "7A8A6A", "A0B090"], isProOnly: true),
            SanctuaryBackground(id: "fireflies-dusk", name: "Fireflies at Dusk", collection: .nature, gradientColors: ["0A1A0A", "1A3A1A", "2A4A2A"], isProOnly: true),
            // Images
            SanctuaryBackground(id: "mountain-sunrise-img", name: "Mountain Sunrise", collection: .nature, gradientColors: ["C2842F", "D4A054", "F0D8A0"], imageName: "mountain-sunrise", isProOnly: true),
            SanctuaryBackground(id: "forest-path-img", name: "Forest Path", collection: .nature, gradientColors: ["1A3D0A", "3A6B2A", "6A9A5A"], imageName: "forest-path", isProOnly: true),
            SanctuaryBackground(id: "calm-lake-img", name: "Calm Lake", collection: .nature, gradientColors: ["2A4A6A", "4A7A9A", "7AACCC"], imageName: "calm-lake", isProOnly: true),
            SanctuaryBackground(id: "misty-forest-img", name: "Misty Forest", collection: .nature, gradientColors: ["2D4A2D", "4A6A4A", "7A9A7A"], imageName: "misty-forest", isProOnly: true),
            SanctuaryBackground(id: "green-meadow-img", name: "Green Meadow", collection: .nature, gradientColors: ["3A6B35", "5C9454", "A8D5A0"], imageName: "green-meadow", isProOnly: true),
            SanctuaryBackground(id: "tropical-waterfall-img", name: "Tropical Falls", collection: .nature, gradientColors: ["1A4A3A", "2D7A5A", "4AAA7A"], imageName: "tropical-waterfall", isProOnly: true),
            SanctuaryBackground(id: "dramatic-mountains-img", name: "Dramatic Mountains", collection: .nature, gradientColors: ["3A4A5A", "5A7080", "8A9AAA"], imageName: "dramatic-mountains", isProOnly: true),
            SanctuaryBackground(id: "moonlit-mountains-img", name: "Moonlit Mountains", collection: .nature, gradientColors: ["0A1628", "1A2D50", "3A4D70"], imageName: "moonlit-mountains", isProOnly: true),
            SanctuaryBackground(id: "mountain-sunrise-mist-img", name: "Mountain Sunrise Mist", collection: .nature, gradientColors: ["C2842F", "D4A054", "F0D8A0"], imageName: "mountain-sunrise-mist", isProOnly: true),
            SanctuaryBackground(id: "autumn-forest-sun-img", name: "Autumn Forest Sun", collection: .nature, gradientColors: ["8B5A2F", "B87A40", "D4956A"], imageName: "autumn-forest-sun", isProOnly: true),
            SanctuaryBackground(id: "forest-sunset-golden-img", name: "Forest Sunset", collection: .nature, gradientColors: ["6B3A10", "9A5A20", "C88040"], imageName: "forest-sunset-golden", isProOnly: true),
            SanctuaryBackground(id: "heavenly-forest-rays", name: "Heavenly Forest", collection: .nature, gradientColors: ["1A2A1A", "3A5A2A", "5A7A3A"], imageName: "forest-heavenly-rays", isProOnly: true),
            SanctuaryBackground(id: "crucifix-garden", name: "Garden Crucifix", collection: .nature, gradientColors: ["2A4A2A", "4A6A3A", "6A8A5A"], imageName: "wooden-crucifix-garden", isProOnly: true),
            // New images
            SanctuaryBackground(id: "alpine-wildflowers-img", name: "Alpine Wildflowers", collection: .nature, gradientColors: ["3A5A2A", "5A8A4A", "8AB06A"], imageName: "alpine-wildflowers", isProOnly: true),
            SanctuaryBackground(id: "redwood-canopy-img", name: "Redwood Canopy", collection: .nature, gradientColors: ["2A1A0A", "4A3A1A", "6A5A2A"], imageName: "redwood-canopy", isProOnly: true),
            SanctuaryBackground(id: "japanese-garden-img", name: "Japanese Garden", collection: .nature, gradientColors: ["1A3A2A", "2D5A3A", "4A7A5A"], imageName: "japanese-garden", isProOnly: true),
            SanctuaryBackground(id: "winding-river-valley-img", name: "River Valley", collection: .nature, gradientColors: ["2A4A3A", "4A6A5A", "6A8A7A"], imageName: "winding-river-valley", isProOnly: true),
            SanctuaryBackground(id: "snow-capped-peaks-img", name: "Snow Capped Peaks", collection: .nature, gradientColors: ["4A5A6A", "7A8A9A", "B0C0D0"], imageName: "snow-capped-peaks", isProOnly: true),
            SanctuaryBackground(id: "tulip-field-img", name: "Tulip Field", collection: .nature, gradientColors: ["6A2A3A", "9A4A5A", "C06A7A"], imageName: "tulip-field", isProOnly: true),
            SanctuaryBackground(id: "mossy-stones-img", name: "Mossy Stones", collection: .nature, gradientColors: ["2A3A2A", "4A5A3A", "6A7A5A"], imageName: "mossy-stones", isProOnly: true),
            SanctuaryBackground(id: "foggy-hillside-img", name: "Foggy Hillside", collection: .nature, gradientColors: ["5A6A5A", "7A8A7A", "A0B0A0"], imageName: "foggy-hillside", isProOnly: true),
            SanctuaryBackground(id: "pine-forest-snow-img", name: "Snowy Pine Forest", collection: .nature, gradientColors: ["1A2A3A", "3A4A5A", "5A6A7A"], imageName: "pine-forest-snow", isProOnly: true),
            SanctuaryBackground(id: "rolling-hills-img", name: "Rolling Hills", collection: .nature, gradientColors: ["4A6A2A", "6A8A4A", "8AAA6A"], imageName: "rolling-hills", isProOnly: true),
            SanctuaryBackground(id: "lavender-sunset-img", name: "Lavender Sunset", collection: .nature, gradientColors: ["4A3A6A", "6B5B8A", "8A7AAA"], imageName: "lavender-field-sunset", isProOnly: true),
            SanctuaryBackground(id: "lavender-sky-img", name: "Lavender Sky", collection: .nature, gradientColors: ["4A3A7A", "6B5B9A", "8A7ABA"], imageName: "lavender-field-blue-sky", isProOnly: true),
            SanctuaryBackground(id: "sunflower-golden-img", name: "Sunflower Golden", collection: .nature, gradientColors: ["5A4A0A", "8A7A1A", "B0A030"], imageName: "sunflower-field-golden", isProOnly: true),
            SanctuaryBackground(id: "sunflower-sunset-img", name: "Sunflower Sunset", collection: .nature, gradientColors: ["6A4A0A", "9A7A1A", "C0A030"], imageName: "sunflower-sunset", isProOnly: true),
            SanctuaryBackground(id: "wildflower-meadow-img", name: "Wildflower Meadow", collection: .nature, gradientColors: ["4A6A2A", "6A8A4A", "8AAA6A"], imageName: "wildflower-meadow", isProOnly: true),
            SanctuaryBackground(id: "green-rice-terraces-img", name: "Rice Terraces", collection: .nature, gradientColors: ["2A4A1A", "4A6A2A", "6A8A4A"], imageName: "green-rice-terraces", isProOnly: true),
            SanctuaryBackground(id: "mountain-stream-forest-img", name: "Mountain Stream", collection: .nature, gradientColors: ["1A3A3A", "2D5A5A", "4A7A7A"], imageName: "mountain-stream-forest", isProOnly: true),
            SanctuaryBackground(id: "serene-forest-stream-img", name: "Forest Stream", collection: .nature, gradientColors: ["1A3A2A", "2D5A4A", "4A7A6A"], imageName: "serene-forest-stream", isProOnly: true),
            SanctuaryBackground(id: "waterfall-lush-img", name: "Lush Waterfall", collection: .nature, gradientColors: ["1A4A3A", "2D7A5A", "4AAA7A"], imageName: "waterfall-lush-green", isProOnly: true),
            SanctuaryBackground(id: "waterfall-mossy-img", name: "Mossy Waterfall", collection: .nature, gradientColors: ["1A3A2A", "2D5A3A", "4A7A5A"], imageName: "waterfall-mossy-rocks", isProOnly: true),
            SanctuaryBackground(id: "winding-road-img", name: "Winding Road", collection: .nature, gradientColors: ["3A4A3A", "5A6A5A", "7A8A7A"], imageName: "winding-mountain-road", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "autumn-ember", name: "Autumn Ember", collection: .nature, gradientColors: ["8B3A2F", "B85C3A", "D4956A"], isProOnly: true),
            SanctuaryBackground(id: "cherry-blossom", name: "Cherry Blossom", collection: .nature, gradientColors: ["E8A0BF", "F0C8D8", "FCE4EC"], isProOnly: true),
            SanctuaryBackground(id: "northern-lights", name: "Northern Lights", collection: .nature, gradientColors: ["0B3D2E", "1A6B4A", "38C98B"], isProOnly: true),
            SanctuaryBackground(id: "stormy-sky", name: "Stormy Sky", collection: .nature, gradientColors: ["2C3E50", "4A6274", "7A9BB0"], isProOnly: true),
            SanctuaryBackground(id: "canyon-rock", name: "Canyon Rock", collection: .nature, gradientColors: ["8B4513", "A0522D", "CD853F"], isProOnly: true),
        ])

        // MARK: Ocean & Water (42 — all Pro)
        bgs.append(contentsOf: [
            // Animated Videos
            SanctuaryBackground(id: "flowing-water", name: "Flowing Water", collection: .oceanAndWater, gradientColors: ["1A5276", "2980B9", "5DADE2"], videoFileName: "water-ripples", isProOnly: true),
            SanctuaryBackground(id: "ocean-aerial", name: "Ocean Aerial", collection: .oceanAndWater, gradientColors: ["0A3D5C", "1A6B8A", "2E9AB8"], videoFileName: "ocean-aerial", isProOnly: true),
            SanctuaryBackground(id: "ocean-waves", name: "Ocean Waves", collection: .oceanAndWater, gradientColors: ["0D4F6B", "1A7A9E", "3AACCC"], videoFileName: "ocean-waves", isProOnly: true),
            SanctuaryBackground(id: "gentle-rain", name: "Gentle Rain", collection: .oceanAndWater, gradientColors: ["37474F", "546E7A", "78909C"], videoFileName: "rain-window", isProOnly: true),
            SanctuaryBackground(id: "rain-on-leaves", name: "Rain on Leaves", collection: .oceanAndWater, gradientColors: ["1A3D1A", "2D5A2D", "4A7A4A"], videoFileName: "rain-on-leaves", isProOnly: true),
            SanctuaryBackground(id: "underwater-light", name: "Underwater Light", collection: .oceanAndWater, gradientColors: ["0A2D5C", "1A5A8A", "2A8AB8"], videoFileName: "underwater-light", isProOnly: true),
            SanctuaryBackground(id: "ember-particles", name: "Shimmering Sea", collection: .oceanAndWater, gradientColors: ["1A0A00", "4A1A08", "8B3A10"], videoFileName: "water-glistening", isProOnly: true),
            SanctuaryBackground(id: "aerial-sea-waves", name: "Aerial Sea Waves", collection: .oceanAndWater, gradientColors: ["0A5276", "1A80B9", "3DADE2"], videoFileName: "aerial-sea-waves", isProOnly: true),
            SanctuaryBackground(id: "calm-beach-waves", name: "Calm Beach", collection: .oceanAndWater, gradientColors: ["1A5A6A", "2D8A9A", "5ABACC"], videoFileName: "calm-beach-waves", isProOnly: true),
            SanctuaryBackground(id: "slowmo-waves", name: "Slow Motion Waves", collection: .oceanAndWater, gradientColors: ["0D4F6B", "1A7A9E", "3AACCC"], videoFileName: "slowmo-waves", isProOnly: true),
            SanctuaryBackground(id: "river-flowing-forest-video", name: "River in Forest", collection: .oceanAndWater, gradientColors: ["1A3A4A", "2D5A6A", "4A8A9A"], videoFileName: "river-flowing-forest", isProOnly: true),
            SanctuaryBackground(id: "mountain-stream-video", name: "Mountain Stream", collection: .oceanAndWater, gradientColors: ["1A4A5A", "2D7A8A", "4AAABB"], videoFileName: "mountain-stream-rocks", isProOnly: true),
            SanctuaryBackground(id: "forest-waterfall-video", name: "Forest Waterfall", collection: .oceanAndWater, gradientColors: ["1A3A3A", "2D5A5A", "4A7A7A"], videoFileName: "forest-waterfall-stream", isProOnly: true),
            SanctuaryBackground(id: "cascading-waterfall-video", name: "Cascading Falls", collection: .oceanAndWater, gradientColors: ["1A4A5A", "2D6A7A", "4A8A9A"], videoFileName: "cascading-waterfall", isProOnly: true),
            SanctuaryBackground(id: "gentle-river-video", name: "Gentle River", collection: .oceanAndWater, gradientColors: ["1A3A4A", "2D5A6A", "4A7A8A"], videoFileName: "gentle-river-nature", isProOnly: true),
            SanctuaryBackground(id: "babbling-brook-video", name: "Babbling Brook", collection: .oceanAndWater, gradientColors: ["1A3A3A", "2D5A5A", "4A7A7A"], videoFileName: "babbling-brook", isProOnly: true),
            SanctuaryBackground(id: "autumn-creek-video", name: "Autumn Creek", collection: .oceanAndWater, gradientColors: ["3A2A1A", "5A4A2A", "7A6A4A"], videoFileName: "autumn-creek", isProOnly: true),
            SanctuaryBackground(id: "crystal-stream-video", name: "Crystal Stream", collection: .oceanAndWater, gradientColors: ["1A5A6A", "2D8A9A", "4ABACC"], videoFileName: "crystal-clear-stream", isProOnly: true),
            SanctuaryBackground(id: "lake-reflection-video", name: "Lake Reflection", collection: .oceanAndWater, gradientColors: ["1A3A5A", "2D5A7A", "4A7A9A"], videoFileName: "lake-mountain-reflection", isProOnly: true),
            // Additional ocean gradients
            SanctuaryBackground(id: "tidal-pool", name: "Tidal Pool", collection: .oceanAndWater, gradientColors: ["0A2A3A", "1A4A5A", "2A6A7A"], isProOnly: true),
            SanctuaryBackground(id: "misty-shoreline", name: "Misty Shoreline", collection: .oceanAndWater, gradientColors: ["3A4A5A", "5A6A7A", "8A9AAA"], isProOnly: true),
            // Images
            SanctuaryBackground(id: "ocean-sunset-img", name: "Ocean Sunset", collection: .oceanAndWater, gradientColors: ["8B3A1A", "C96B3A", "E8A060"], imageName: "ocean-sunset", isProOnly: true),
            // New images
            SanctuaryBackground(id: "coral-reef-img", name: "Coral Reef", collection: .oceanAndWater, gradientColors: ["0A3A5A", "1A5A7A", "3A8AAA"], imageName: "coral-reef", isProOnly: true),
            SanctuaryBackground(id: "turquoise-cove-img", name: "Turquoise Cove", collection: .oceanAndWater, gradientColors: ["0A5A6A", "1A8A9A", "3ABACC"], imageName: "turquoise-cove", isProOnly: true),
            SanctuaryBackground(id: "rocky-coastline-img", name: "Rocky Coastline", collection: .oceanAndWater, gradientColors: ["3A4A5A", "5A6A7A", "7A8A9A"], imageName: "rocky-coastline", isProOnly: true),
            SanctuaryBackground(id: "tropical-beach-img", name: "Tropical Beach", collection: .oceanAndWater, gradientColors: ["1A6A6A", "2A9A9A", "4ACACC"], imageName: "tropical-beach", isProOnly: true),
            SanctuaryBackground(id: "frozen-lake-img", name: "Frozen Lake", collection: .oceanAndWater, gradientColors: ["5A6A7A", "8A9AAA", "B0C0D0"], imageName: "frozen-lake", isProOnly: true),
            SanctuaryBackground(id: "misty-waterfall-img", name: "Misty Waterfall", collection: .oceanAndWater, gradientColors: ["2A4A3A", "4A6A5A", "6A8A7A"], imageName: "misty-waterfall", isProOnly: true),
            SanctuaryBackground(id: "mountain-lake-reflect-img", name: "Mountain Reflection", collection: .oceanAndWater, gradientColors: ["2A4A6A", "4A6A8A", "6A8AAA"], imageName: "mountain-lake-reflection", isProOnly: true),
            SanctuaryBackground(id: "lake-braies-img", name: "Lake Braies", collection: .oceanAndWater, gradientColors: ["1A4A5A", "2D6A7A", "4A8A9A"], imageName: "lake-braies-reflection", isProOnly: true),
            SanctuaryBackground(id: "mountain-lake-pan-img", name: "Lake Panorama", collection: .oceanAndWater, gradientColors: ["2A3A5A", "4A5A7A", "6A7A9A"], imageName: "mountain-lake-panorama", isProOnly: true),
            SanctuaryBackground(id: "pristine-lake-img", name: "Pristine Lake", collection: .oceanAndWater, gradientColors: ["1A4A6A", "2D6A8A", "4A8AAA"], imageName: "pristine-mountain-lake", isProOnly: true),
            SanctuaryBackground(id: "blue-mountain-lake-img", name: "Blue Mountain Lake", collection: .oceanAndWater, gradientColors: ["1A3A6A", "2D5A8A", "4A7AAA"], imageName: "blue-mountain-lake", isProOnly: true),
            SanctuaryBackground(id: "crystal-blue-lake-img", name: "Crystal Blue Lake", collection: .oceanAndWater, gradientColors: ["1A5A7A", "2D8A9A", "4ABACC"], imageName: "crystal-blue-lake", isProOnly: true),
            SanctuaryBackground(id: "emerald-water-img", name: "Emerald Waters", collection: .oceanAndWater, gradientColors: ["0A4A4A", "1A6A6A", "3A9A9A"], imageName: "emerald-tropical-water", isProOnly: true),
            SanctuaryBackground(id: "sunset-ocean-img", name: "Sunset Ocean", collection: .oceanAndWater, gradientColors: ["8B4A1A", "C06A30", "E89050"], imageName: "sunset-ocean-horizon", isProOnly: true),
            SanctuaryBackground(id: "mountain-mirror-img", name: "Mirror Lake", collection: .oceanAndWater, gradientColors: ["2A4A5A", "4A6A7A", "6A8A9A"], imageName: "mountain-mirror-lake", isProOnly: true),
            SanctuaryBackground(id: "river-valley-img", name: "River Valley", collection: .oceanAndWater, gradientColors: ["2A4A3A", "4A6A5A", "6A8A7A"], imageName: "river-valley-aerial", isProOnly: true),
            SanctuaryBackground(id: "mountain-valley-river-img", name: "Valley River", collection: .oceanAndWater, gradientColors: ["2A3A4A", "4A5A6A", "6A7A8A"], imageName: "mountain-valley-river", isProOnly: true),
            SanctuaryBackground(id: "snow-mountain-lake-img", name: "Snow Mountain Lake", collection: .oceanAndWater, gradientColors: ["3A5A7A", "5A7A9A", "7A9ABA"], imageName: "snow-mountain-lake", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "ocean-deep", name: "Ocean Deep", collection: .oceanAndWater, gradientColors: ["0A2342", "1A4570", "2E6D9E"]),
        ])

        // MARK: Night Sky (17 — all Pro)
        bgs.append(contentsOf: [
            // Animated Videos
            SanctuaryBackground(id: "starfield", name: "Starfield", collection: .nightSky, gradientColors: ["0A0A1A", "14142D", "1E1E40"], videoFileName: "starry-night"),
            SanctuaryBackground(id: "aurora-wave", name: "Aurora Wave", collection: .nightSky, gradientColors: ["0D2137", "1A4A4A", "2D8A6A"], videoFileName: "milky-way", isProOnly: true),
            SanctuaryBackground(id: "northern-aurora", name: "Northern Aurora", collection: .nightSky, gradientColors: ["0B1D0B", "0D3B2E", "38C98B"], videoFileName: "northern-aurora", isProOnly: true),
            SanctuaryBackground(id: "starry-timelapse", name: "Starry Timelapse", collection: .nightSky, gradientColors: ["0A0A1A", "0D1B3D", "1A2D5E"], videoFileName: "starry-timelapse", isProOnly: true),
            SanctuaryBackground(id: "moonlit-clouds", name: "Moonlit Clouds", collection: .nightSky, gradientColors: ["0A1628", "1A2D50", "3A4D70"], videoFileName: "moonlit-clouds", isProOnly: true),
            SanctuaryBackground(id: "aurora-borealis", name: "Aurora Borealis", collection: .nightSky, gradientColors: ["0B1D0B", "0D3B2E", "1A6B4A"], videoFileName: "aurora-borealis", isProOnly: true),
            SanctuaryBackground(id: "stars-mountains-pexels", name: "Stars Over Mountains", collection: .nightSky, gradientColors: ["0A0A1A", "0D1B3D", "1A2D5E"], videoFileName: "stars-mountains", isProOnly: true),
            SanctuaryBackground(id: "stars-drifting-vid", name: "Stars Drifting", collection: .nightSky, gradientColors: ["060610", "0A0A22", "141438"], videoFileName: "stars-drifting", isProOnly: true),
            // Additional night sky gradients
            SanctuaryBackground(id: "meteor-shower", name: "Meteor Shower", collection: .nightSky, gradientColors: ["0A0A14", "0D0D28", "14143C"], isProOnly: true),
            SanctuaryBackground(id: "galaxy-rotation", name: "Galaxy Rotation", collection: .nightSky, gradientColors: ["0A0A18", "10102A", "1A1A3C"], isProOnly: true),
            // Images
            SanctuaryBackground(id: "starry-mountains-img", name: "Starry Mountains", collection: .nightSky, gradientColors: ["0A0A1A", "14142D", "1E1E40"], imageName: "starry-mountains", isProOnly: true),
            SanctuaryBackground(id: "aurora-wallpaper-img", name: "Aurora Wallpaper", collection: .nightSky, gradientColors: ["0B2D1E", "1A5A3A", "38A06B"], imageName: "aurora-wallpaper", isProOnly: true),
            SanctuaryBackground(id: "northern-lights-snow-img", name: "Northern Lights Snow", collection: .nightSky, gradientColors: ["0B1D2B", "1A3D4A", "2D6B6A"], imageName: "northern-lights-snow", isProOnly: true),
            // New images
            SanctuaryBackground(id: "milky-way-desert-img", name: "Milky Way Desert", collection: .nightSky, gradientColors: ["0A0A14", "14142D", "2A2A50"], imageName: "milky-way-desert", isProOnly: true),
            SanctuaryBackground(id: "full-moon-clouds-img", name: "Full Moon", collection: .nightSky, gradientColors: ["0A1020", "1A2040", "2A3060"], imageName: "full-moon-clouds", isProOnly: true),
            SanctuaryBackground(id: "starry-forest-img", name: "Starry Forest", collection: .nightSky, gradientColors: ["0A0A1A", "0D1A2A", "1A2A3A"], imageName: "starry-forest", isProOnly: true),
            SanctuaryBackground(id: "crescent-moon-img", name: "Crescent Moon", collection: .nightSky, gradientColors: ["0A0A18", "10102A", "20203A"], imageName: "crescent-moon", isProOnly: true),
            SanctuaryBackground(id: "night-sky-lake-img", name: "Night Sky Lake", collection: .nightSky, gradientColors: ["0A0A14", "0D1A2A", "1A2A4A"], imageName: "night-sky-lake", isProOnly: true),
        ])

        // MARK: Warmth & Glow (30 — all Pro)
        bgs.append(contentsOf: [
            // Animated Videos
            SanctuaryBackground(id: "candle-flicker", name: "Candle Flicker", collection: .warmthAndGlow, gradientColors: ["4A2800", "8B5E14", "C9A96E"], videoFileName: "candlelight", isProOnly: true),
            SanctuaryBackground(id: "golden-dust", name: "Golden Dust", collection: .warmthAndGlow, gradientColors: ["1A1408", "3D3014", "6B5424"], videoFileName: "golden-lake", isProOnly: true),
            SanctuaryBackground(id: "fireplace", name: "Warm Fireplace", collection: .warmthAndGlow, gradientColors: ["3D1A08", "6B3010", "9A5020"], videoFileName: "fireplace", isProOnly: true),
            SanctuaryBackground(id: "sunset-clouds", name: "Sunset Clouds", collection: .warmthAndGlow, gradientColors: ["8B3A1A", "C96B3A", "E8A060"], videoFileName: "sunset-clouds", isProOnly: true),
            SanctuaryBackground(id: "flickering-candle", name: "Flickering Candle", collection: .warmthAndGlow, gradientColors: ["3A2000", "6B4014", "9A6A28"], videoFileName: "flickering-candle", isProOnly: true),
            SanctuaryBackground(id: "candle-darkness", name: "Candle in Darkness", collection: .warmthAndGlow, gradientColors: ["1A1008", "3D2810", "6B4A20"], videoFileName: "candle-darkness", isProOnly: true),
            SanctuaryBackground(id: "sunset-clouds-timelapse", name: "Sunset Timelapse", collection: .warmthAndGlow, gradientColors: ["8B4A1A", "C97040", "E8A060"], videoFileName: "sunset-clouds-timelapse", isProOnly: true),
            SanctuaryBackground(id: "vertical-sunset-pexels", name: "Golden Sunset", collection: .warmthAndGlow, gradientColors: ["8B3A1A", "C96B3A", "E8A060"], videoFileName: "vertical-sunset", isProOnly: true),
            SanctuaryBackground(id: "golden-lake-sunset-pexels", name: "Golden Lake Sunset", collection: .warmthAndGlow, gradientColors: ["6B4A1A", "9A7030", "C89A50"], videoFileName: "golden-lake-sunset", isProOnly: true),
            SanctuaryBackground(id: "sunset-timelapse-video", name: "Sunset Timelapse", collection: .warmthAndGlow, gradientColors: ["8B4A1A", "C97040", "E8A060"], videoFileName: "sunset-timelapse", isProOnly: true),
            SanctuaryBackground(id: "golden-sunset-sky-video", name: "Golden Sky", collection: .warmthAndGlow, gradientColors: ["8B3A1A", "C96B3A", "E8A060"], videoFileName: "golden-sunset-sky", isProOnly: true),
            SanctuaryBackground(id: "sunset-landscape-video", name: "Sunset Landscape", collection: .warmthAndGlow, gradientColors: ["6B3A1A", "9A5A30", "C88050"], videoFileName: "sunset-landscape", isProOnly: true),
            SanctuaryBackground(id: "sunset-clouds-golden-video", name: "Golden Clouds", collection: .warmthAndGlow, gradientColors: ["8B5A1A", "C98A3A", "E8B060"], videoFileName: "sunset-clouds-golden", isProOnly: true),
            // Additional warmth gradients
            SanctuaryBackground(id: "campfire-embers", name: "Campfire Embers", collection: .warmthAndGlow, gradientColors: ["2A0A00", "5A1A08", "8A3A10"], isProOnly: true),
            SanctuaryBackground(id: "floating-lanterns", name: "Floating Lanterns", collection: .warmthAndGlow, gradientColors: ["1A0A08", "3A1A10", "6A3A20"], isProOnly: true),
            // Images
            SanctuaryBackground(id: "desert-sunset-img", name: "Desert Sunset", collection: .warmthAndGlow, gradientColors: ["8B4A1A", "B86A30", "D89050"], imageName: "desert-sunset", isProOnly: true),
            SanctuaryBackground(id: "desert-landscape-img", name: "Desert Landscape", collection: .warmthAndGlow, gradientColors: ["8B6A3A", "B89060", "D8B888"], imageName: "desert-landscape", isProOnly: true),
            SanctuaryBackground(id: "grand-canyon-img", name: "Grand Canyon", collection: .warmthAndGlow, gradientColors: ["8B4513", "A0622D", "CD8540"], imageName: "grand-canyon", isProOnly: true),
            // New images
            SanctuaryBackground(id: "golden-wheat-img", name: "Golden Wheat", collection: .warmthAndGlow, gradientColors: ["7A5A1A", "A08030", "C8A050"], imageName: "golden-wheat", isProOnly: true),
            SanctuaryBackground(id: "autumn-road-img", name: "Autumn Road", collection: .warmthAndGlow, gradientColors: ["6B3A10", "9A5A20", "C88040"], imageName: "autumn-road", isProOnly: true),
            SanctuaryBackground(id: "sunset-silhouette-img", name: "Sunset Silhouette", collection: .warmthAndGlow, gradientColors: ["4A1A0A", "8A3A1A", "C06030"], imageName: "sunset-silhouette", isProOnly: true),
            SanctuaryBackground(id: "amber-leaves-img", name: "Amber Leaves", collection: .warmthAndGlow, gradientColors: ["6A3A0A", "9A6A1A", "C89A30"], imageName: "amber-leaves", isProOnly: true),
            SanctuaryBackground(id: "rustic-barn-img", name: "Rustic Barn", collection: .warmthAndGlow, gradientColors: ["4A2A1A", "6A4A2A", "8A6A4A"], imageName: "rustic-barn", isProOnly: true),
            SanctuaryBackground(id: "golden-sunset-field-img", name: "Golden Sunset Field", collection: .warmthAndGlow, gradientColors: ["8B5A1A", "B88030", "D8A050"], imageName: "golden-sunset-field", isProOnly: true),
            SanctuaryBackground(id: "mountain-sunset-img", name: "Mountain Sunset", collection: .warmthAndGlow, gradientColors: ["6B3A0A", "9A5A1A", "C88030"], imageName: "mountain-sunset-golden", isProOnly: true),
            SanctuaryBackground(id: "sunset-mountain-sil-img", name: "Mountain Silhouette", collection: .warmthAndGlow, gradientColors: ["4A1A0A", "8A3A1A", "C06030"], imageName: "sunset-mountain-silhouette", isProOnly: true),
            SanctuaryBackground(id: "golden-hour-clouds-img", name: "Golden Hour Clouds", collection: .warmthAndGlow, gradientColors: ["8B5A2A", "B88040", "D8A060"], imageName: "golden-hour-clouds", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "coral-sunset", name: "Coral Sunset", collection: .warmthAndGlow, gradientColors: ["FF6B6B", "EE5A6F", "C44569"], isProOnly: true),
            SanctuaryBackground(id: "bronze-age", name: "Bronze Age", collection: .warmthAndGlow, gradientColors: ["5C3D1E", "8B6040", "B08860"], isProOnly: true),
            SanctuaryBackground(id: "charcoal-flame", name: "Charcoal Flame", collection: .warmthAndGlow, gradientColors: ["1A1A1A", "3D1C1C", "6B2D2D"], isProOnly: true),
        ])

        // MARK: Calm & Serene (17 — all Pro)
        bgs.append(contentsOf: [
            // Animated Videos
            SanctuaryBackground(id: "cloud-drift", name: "Cloud Drift", collection: .calmAndSerene, gradientColors: ["4A6FA5", "6B8FC4", "A8C8E8"], videoFileName: "clouds-moving", isProOnly: true),
            SanctuaryBackground(id: "mountain-clouds", name: "Mountain Clouds", collection: .calmAndSerene, gradientColors: ["3A4A5A", "5A6A7A", "8A9AAA"], videoFileName: "mountain-clouds", isProOnly: true),
            SanctuaryBackground(id: "snow-falling", name: "Gentle Snow", collection: .calmAndSerene, gradientColors: ["B0BEC5", "CFD8DC", "ECEFF1"], videoFileName: "snow-falling", isProOnly: true),
            SanctuaryBackground(id: "cloudy-sky-timelapse", name: "Cloudy Sky", collection: .calmAndSerene, gradientColors: ["6A8FA5", "8BAFC4", "B8D8E8"], videoFileName: "cloudy-sky-timelapse", isProOnly: true),
            // Additional calm gradients
            SanctuaryBackground(id: "rolling-fog", name: "Rolling Fog", collection: .calmAndSerene, gradientColors: ["5A6A6A", "7A8A8A", "A0B0B0"], isProOnly: true),
            SanctuaryBackground(id: "floating-petals", name: "Floating Petals", collection: .calmAndSerene, gradientColors: ["7A4A5A", "9A6A7A", "BA8A9A"], isProOnly: true),
            // Images
            SanctuaryBackground(id: "cherry-blossom-trees-img", name: "Blossom Avenue", collection: .calmAndSerene, gradientColors: ["E8A0BF", "F0C8D8", "FCE4EC"], imageName: "cherry-blossom-trees", isProOnly: true),
            // New images
            SanctuaryBackground(id: "morning-meadow-img", name: "Morning Meadow", collection: .calmAndSerene, gradientColors: ["4A6A3A", "6A8A5A", "8AAA7A"], imageName: "morning-meadow", isProOnly: true),
            SanctuaryBackground(id: "lotus-pond-img", name: "Lotus Pond", collection: .calmAndSerene, gradientColors: ["3A5A4A", "5A7A6A", "7A9A8A"], imageName: "lotus-pond", isProOnly: true),
            SanctuaryBackground(id: "bamboo-path-img", name: "Bamboo Path", collection: .calmAndSerene, gradientColors: ["2A4A2A", "4A6A4A", "6A8A6A"], imageName: "bamboo-path", isProOnly: true),
            SanctuaryBackground(id: "peaceful-lake-img", name: "Peaceful Lake", collection: .calmAndSerene, gradientColors: ["3A5A6A", "5A7A8A", "7A9AAA"], imageName: "peaceful-lake", isProOnly: true),
            SanctuaryBackground(id: "forest-lake-reflect-img", name: "Forest Reflection", collection: .calmAndSerene, gradientColors: ["2A4A3A", "4A6A5A", "6A8A7A"], imageName: "forest-lake-reflection", isProOnly: true),
            SanctuaryBackground(id: "mountain-sunrise-glow-img", name: "Mountain Glow", collection: .calmAndSerene, gradientColors: ["5A3A2A", "8A5A4A", "B07A6A"], imageName: "mountain-sunrise-glow", isProOnly: true),
            SanctuaryBackground(id: "tropical-paradise-img", name: "Tropical Paradise", collection: .calmAndSerene, gradientColors: ["1A5A6A", "2D8A9A", "4ABACC"], imageName: "tropical-paradise-aerial", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "teal-dream", name: "Teal Dream", collection: .calmAndSerene, gradientColors: ["0E4D40", "1A7A6A", "2AB09C"], isProOnly: true),
            SanctuaryBackground(id: "lavender-haze", name: "Lavender Haze", collection: .calmAndSerene, gradientColors: ["6B5B95", "8B7BB5", "B8A9D0"], isProOnly: true),
            SanctuaryBackground(id: "ice-crystal", name: "Ice Crystal", collection: .calmAndSerene, gradientColors: ["D6EAF8", "AED6F1", "85C1E9"], isProOnly: true),
        ])

        // MARK: Sacred (10 — all Pro)
        bgs.append(contentsOf: [
            SanctuaryBackground(id: "stained-glass", name: "Stained Glass", collection: .sacred, gradientColors: ["1A237E", "4A148C", "B71C1C"], isProOnly: true),
            SanctuaryBackground(id: "golden-icon", name: "Golden Icon", collection: .sacred, gradientColors: ["8B6914", "C9A96E", "F0D8A0"], isProOnly: true),
            SanctuaryBackground(id: "olive-branch", name: "Olive Branch", collection: .sacred, gradientColors: ["3E4A2E", "5C6B3A", "8B9A6B"], isProOnly: true),
            SanctuaryBackground(id: "dove-white", name: "Dove White", collection: .sacred, gradientColors: ["E8E4DC", "F0ECE4", "FAF8F4"], isProOnly: true),
            SanctuaryBackground(id: "wine-red", name: "Wine Red", collection: .sacred, gradientColors: ["3B0A0A", "5C1A1A", "8B2D2D"], isProOnly: true),
            SanctuaryBackground(id: "frankincense", name: "Frankincense", collection: .sacred, gradientColors: ["4A3728", "6B5040", "8B7058"], isProOnly: true),
            SanctuaryBackground(id: "ark-gold", name: "Ark Gold", collection: .sacred, gradientColors: ["6B5014", "9B7A2E", "C9A96E"], isProOnly: true),
            SanctuaryBackground(id: "burning-bush", name: "Burning Bush", collection: .sacred, gradientColors: ["6B1A08", "A03010", "D45A20"], isProOnly: true),
            SanctuaryBackground(id: "garden-eden", name: "Garden of Eden", collection: .sacred, gradientColors: ["1A3D1A", "2D6B2D", "4A9A4A"], isProOnly: true),
            SanctuaryBackground(id: "shepherd-field", name: "Shepherd's Field", collection: .sacred, gradientColors: ["4A5A2E", "6B7A40", "8B9A5A"], isProOnly: true),
        ])

        // MARK: Heavenly (32 — all Pro)
        bgs.append(contentsOf: [
            SanctuaryBackground(id: "christ-redeemer", name: "Christ the Redeemer", collection: .heavenly, gradientColors: ["3A5F8A", "6B9FCE", "A8D4F0"], imageName: "christ-redeemer-rio", isProOnly: true),
            SanctuaryBackground(id: "cross-at-sunset", name: "Cross at Sunset", collection: .heavenly, gradientColors: ["8B3A0A", "D4700A", "F0A030"], imageName: "cross-at-sunset", isProOnly: true),
            SanctuaryBackground(id: "glowing-cross-night", name: "Glowing Cross", collection: .heavenly, gradientColors: ["0A0A1A", "1A1A3A", "2A2A5A"], imageName: "glowing-cross-night", isProOnly: true),
            SanctuaryBackground(id: "heaven-sun-rays", name: "Heaven's Rays", collection: .heavenly, gradientColors: ["4A6080", "8AAAC0", "D0E8F8"], imageName: "heaven-sun-rays", isProOnly: true),
            SanctuaryBackground(id: "dramatic-sky-rays", name: "Divine Sky", collection: .heavenly, gradientColors: ["2A3A5A", "5A7AAA", "90B0D0"], imageName: "dramatic-sky-rays", isProOnly: true),
            SanctuaryBackground(id: "stained-glass-church", name: "Stained Glass", collection: .heavenly, gradientColors: ["2A1A3A", "5A3A6A", "8A5A9A"], imageName: "stained-glass-church", isProOnly: true),
            SanctuaryBackground(id: "stained-glass-sacred", name: "Sacred Windows", collection: .heavenly, gradientColors: ["1A2A4A", "3A5A8A", "6A8ABA"], imageName: "stained-glass-religious", isProOnly: true),
            SanctuaryBackground(id: "sunlit-church", name: "Sunlit Church", collection: .heavenly, gradientColors: ["3A2A1A", "6A5A4A", "9A8A7A"], imageName: "sunlit-church-interior", isProOnly: true),
            SanctuaryBackground(id: "stone-angel", name: "Stone Angel", collection: .heavenly, gradientColors: ["4A5A6A", "7A8A9A", "A0B0C0"], imageName: "stone-angel", isProOnly: true),
            SanctuaryBackground(id: "angel-trumpet", name: "Angel's Trumpet", collection: .heavenly, gradientColors: ["5A6A7A", "8A9AAA", "B0C0D0"], imageName: "angel-with-trumpet", isProOnly: true),
            SanctuaryBackground(id: "white-dove", name: "White Dove", collection: .heavenly, gradientColors: ["1A1A2A", "2A2A3A", "4A4A5A"], imageName: "white-dove-flight", isProOnly: true),
            SanctuaryBackground(id: "christ-king", name: "Christ the King", collection: .heavenly, gradientColors: ["4A5A7A", "7A8AAA", "A0B0D0"], imageName: "christ-king-statue", isProOnly: true),
            SanctuaryBackground(id: "altar-cross", name: "Altar & Cross", collection: .heavenly, gradientColors: ["2A1A0A", "5A3A1A", "8A5A2A"], imageName: "altar-cross-candles", isProOnly: true),
            SanctuaryBackground(id: "heavenly-sun-rays-img", name: "Heavenly Sun Rays", collection: .heavenly, gradientColors: ["6A5A3A", "9A8A5A", "C0B07A"], imageName: "heavenly-sun-rays-clouds", isProOnly: true),
            SanctuaryBackground(id: "heavenly-golden-img", name: "Golden Heavens", collection: .heavenly, gradientColors: ["6A4A1A", "9A7A3A", "C0A060"], imageName: "heavenly-golden-clouds", isProOnly: true),
            SanctuaryBackground(id: "heavenly-light-beams-img", name: "Light Beams", collection: .heavenly, gradientColors: ["3A4A5A", "5A7A8A", "8AAABB"], imageName: "heavenly-light-beams", isProOnly: true),
            SanctuaryBackground(id: "aerial-coastline-img", name: "Aerial Coastline", collection: .heavenly, gradientColors: ["1A5A6A", "2D8A9A", "4ABACC"], imageName: "aerial-coastline", isProOnly: true),
            SanctuaryBackground(id: "cross-light-video", name: "Cross in Light", collection: .heavenly, gradientColors: ["0A0A1A", "1A1A2A", "3A3A4A"], videoFileName: "black-cross-light", isProOnly: true),
            SanctuaryBackground(id: "christ-redeemer-video", name: "Christ Redeemer", collection: .heavenly, gradientColors: ["3A5A8A", "6A8ABB", "9AB0D0"], videoFileName: "christ-redeemer-video", isProOnly: true),
            SanctuaryBackground(id: "religious-image-video", name: "Sacred Glow", collection: .heavenly, gradientColors: ["2A1A0A", "5A3A1A", "8A6A3A"], videoFileName: "religious-image", isProOnly: true),
            SanctuaryBackground(id: "sunrays-window-video", name: "Holy Light", collection: .heavenly, gradientColors: ["3A2A1A", "6A5A3A", "9A8A6A"], videoFileName: "sunrays-through-window", isProOnly: true),
            SanctuaryBackground(id: "cathedral-glass-video", name: "Cathedral Glass", collection: .heavenly, gradientColors: ["1A1A3A", "3A3A6A", "5A5A9A"], videoFileName: "cathedral-stained-glass", isProOnly: true),
            SanctuaryBackground(id: "church-windows-video", name: "Church Windows", collection: .heavenly, gradientColors: ["3A2A1A", "5A4A3A", "7A6A5A"], videoFileName: "church-sun-windows", isProOnly: true),
            SanctuaryBackground(id: "stained-glass-video", name: "Living Glass", collection: .heavenly, gradientColors: ["1A2A4A", "3A5A7A", "5A7A9A"], videoFileName: "stained-glass-bright", isProOnly: true),
            SanctuaryBackground(id: "sacred-candles-video", name: "Sacred Candles", collection: .heavenly, gradientColors: ["2A0A0A", "5A1A1A", "8A3A2A"], videoFileName: "burning-candles-sacred", isProOnly: true),
            SanctuaryBackground(id: "heavenly-clouds-video", name: "Heavenly Clouds", collection: .heavenly, gradientColors: ["3A5A8A", "6A8AB0", "90B0D8"], videoFileName: "heavenly-clouds", isProOnly: true),
            SanctuaryBackground(id: "clouds-timelapse-video", name: "Cloud Timelapse", collection: .heavenly, gradientColors: ["4A6A9A", "7A9AC0", "A0C0E0"], videoFileName: "clouds-timelapse", isProOnly: true),
            SanctuaryBackground(id: "candle-glow-video", name: "Candle Glow", collection: .heavenly, gradientColors: ["1A0A0A", "3A1A0A", "5A2A1A"], videoFileName: "burning-red-candle", isProOnly: true),
            SanctuaryBackground(id: "candle-closeup-video", name: "Candlelight", collection: .heavenly, gradientColors: ["0A0A0A", "2A1A0A", "4A2A1A"], videoFileName: "candle-closeup", isProOnly: true),
            SanctuaryBackground(id: "jesus-statue-video", name: "Jesus Statue", collection: .heavenly, gradientColors: ["3A4A5A", "5A6A7A", "7A8A9A"], videoFileName: "jesus-statue-closeup", isProOnly: true),
            SanctuaryBackground(id: "church-cross-video", name: "Church & Cross", collection: .heavenly, gradientColors: ["1A1A2A", "2A2A4A", "4A4A6A"], videoFileName: "man-church-cross", isProOnly: true),
            SanctuaryBackground(id: "flame-darkness-video", name: "Flame in Darkness", collection: .heavenly, gradientColors: ["0A0A0A", "1A0A0A", "3A1A0A"], videoFileName: "candle-flame-darkness", isProOnly: true),
        ])

        // MARK: Seasonal (17 — all Pro)
        bgs.append(contentsOf: [
            // Gradients
            SanctuaryBackground(id: "spring-bloom", name: "Spring Bloom", collection: .seasonal, gradientColors: ["F8BBD0", "F0E8D8", "C8E6C9"], isProOnly: true),
            SanctuaryBackground(id: "summer-warmth", name: "Summer Warmth", collection: .seasonal, gradientColors: ["FFB74D", "FF8A65", "FF7043"], isProOnly: true),
            SanctuaryBackground(id: "fall-harvest", name: "Fall Harvest", collection: .seasonal, gradientColors: ["8D6E63", "A1887F", "D7CCC8"], isProOnly: true),
            SanctuaryBackground(id: "winter-frost", name: "Winter Frost", collection: .seasonal, gradientColors: ["CFD8DC", "B0BEC5", "90A4AE"], isProOnly: true),
            SanctuaryBackground(id: "christmas-eve", name: "Christmas Eve", collection: .seasonal, gradientColors: ["1A3C1A", "8B1A1A", "C9A96E"], isProOnly: true),
            SanctuaryBackground(id: "easter-dawn", name: "Easter Dawn", collection: .seasonal, gradientColors: ["FFF8E1", "FFECB3", "FFD54F"], isProOnly: true),
            SanctuaryBackground(id: "advent-purple", name: "Advent Purple", collection: .seasonal, gradientColors: ["2D1B4E", "4A2C7A", "6B3FA0"], isProOnly: true),
            SanctuaryBackground(id: "lenten-ash", name: "Lenten Ash", collection: .seasonal, gradientColors: ["424242", "616161", "9E9E9E"], isProOnly: true),
            SanctuaryBackground(id: "pentecost-fire", name: "Pentecost Fire", collection: .seasonal, gradientColors: ["BF360C", "E64A19", "FF6E40"], isProOnly: true),
            SanctuaryBackground(id: "palm-sunday", name: "Palm Sunday", collection: .seasonal, gradientColors: ["33691E", "558B2F", "7CB342"], isProOnly: true),
            // Images
            SanctuaryBackground(id: "spring-cherry-img", name: "Spring Cherry Tree", collection: .seasonal, gradientColors: ["E8A0BF", "F0C8D8", "FCE4EC"], imageName: "spring-cherry-tree", isProOnly: true),
            SanctuaryBackground(id: "summer-beach-img", name: "Summer Beach", collection: .seasonal, gradientColors: ["1A7A8A", "2AAABB", "4ADAEC"], imageName: "summer-beach", isProOnly: true),
            SanctuaryBackground(id: "christmas-lights-img", name: "Christmas Lights", collection: .seasonal, gradientColors: ["1A0A0A", "3A1A1A", "5A2A1A"], imageName: "christmas-lights", isProOnly: true),
            SanctuaryBackground(id: "easter-lilies-img", name: "Easter Lilies", collection: .seasonal, gradientColors: ["FAF8F4", "F0E8D8", "E8DCC8"], imageName: "easter-lilies", isProOnly: true),
            // Additional seasonal gradients
            SanctuaryBackground(id: "falling-leaves", name: "Falling Leaves", collection: .seasonal, gradientColors: ["6B2D10", "A05020", "D48040"], isProOnly: true),
            SanctuaryBackground(id: "christmas-snow", name: "Christmas Snow", collection: .seasonal, gradientColors: ["0A1A2A", "1A2A3A", "3A4A5A"], isProOnly: true),
        ])

        return bgs
    }()

    static func background(for id: String) -> SanctuaryBackground? {
        allBackgrounds.first { $0.id == id }
    }

    static func backgrounds(in collection: BackgroundCollection) -> [SanctuaryBackground] {
        allBackgrounds.filter { $0.collection == collection }
    }

    /// Maps any background ID to the nearest ThemeDefinition ID for onboarding.
    static func nearestThemeID(for backgroundID: String) -> String {
        let mapping: [String: String] = [
            "warm-gold": "sunrise-mountains",
            "forest-dawn": "forest-mist",
            "mountain-mist": "ocean-peace",
            "desert-sun": "sunrise-mountains",
            "twilight-lake": "midnight-gold",
            "meadow-green": "forest-mist",
            "royal-purple": "midnight-gold",
            "ember-glow": "sunrise-mountains",
            "midnight-blue": "midnight-gold",
            "rose-gold": "sunrise-mountains",
            "soft-cream": "minimal-cream",
            "steel-grey": "midnight-gold",
        ]
        return mapping[backgroundID] ?? "sunrise-mountains"
    }
}

// MARK: - Verse Highlight Color

enum VerseHighlightColor: String, Codable, CaseIterable, Identifiable {
    case gold
    case blue
    case green
    case pink
    case purple
    case orange
    case teal
    case lavender

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gold: String(localized: "Gold")
        case .blue: String(localized: "Blue")
        case .green: String(localized: "Green")
        case .pink: String(localized: "Pink")
        case .purple: String(localized: "Purple")
        case .orange: String(localized: "Orange")
        case .teal: String(localized: "Teal")
        case .lavender: String(localized: "Lavender")
        }
    }

    var lightTint: String {
        switch self {
        case .gold: "FFF3D0"
        case .blue: "D6EEFF"
        case .green: "D4F5D4"
        case .pink: "FFD6E8"
        case .purple: "E8D6FF"
        case .orange: "FFE4C9"
        case .teal: "CCF0EC"
        case .lavender: "E4DAFF"
        }
    }

    var darkTint: String {
        switch self {
        case .gold: "4A3F1F"
        case .blue: "1E3448"
        case .green: "1E3D1E"
        case .pink: "3D1E2E"
        case .purple: "2E1E3D"
        case .orange: "4A2E1A"
        case .teal: "1A3D3A"
        case .lavender: "2A2040"
        }
    }

    var dotColor: String {
        switch self {
        case .gold: "C9A96E"
        case .blue: "5B9BD5"
        case .green: "6BBF6B"
        case .pink: "E88AAF"
        case .purple: "9B7BD5"
        case .orange: "E8944A"
        case .teal: "4ABFB5"
        case .lavender: "8B7BC9"
        }
    }

    /// Returns gradient colors for the luminous highlight effect (full tint → 30% tint → clear).
    func gradientColors(for colorScheme: ColorScheme) -> [Color] {
        let hex = colorScheme == .dark ? darkTint : lightTint
        let tint = Color(hex: hex)
        return [tint, tint.opacity(0.3), .clear]
    }
}

// MARK: - Reader Font Style

enum ReaderFontStyle: String, Codable, CaseIterable, Identifiable {
    case serif
    case sansSerif
    case rounded
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serif: String(localized: "Serif")
        case .sansSerif: String(localized: "Sans Serif")
        case .rounded: String(localized: "Rounded")
        case .mono: String(localized: "Mono")
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .serif: .serif
        case .sansSerif: .default
        case .rounded: .rounded
        case .mono: .monospaced
        }
    }

    var previewLetter: String {
        switch self {
        case .serif: "Aa"
        case .sansSerif: "Aa"
        case .rounded: "Aa"
        case .mono: "Aa"
        }
    }
}

// MARK: - Reader Font Weight

enum ReaderFontWeight: String, Codable, CaseIterable, Identifiable {
    case light
    case regular
    case medium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: String(localized: "Light")
        case .regular: String(localized: "Regular")
        case .medium: String(localized: "Medium")
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        }
    }
}

// MARK: - Audio Playback Speed

enum PlaybackSpeed: Double, CaseIterable, Identifiable {
    case slow = 0.75
    case normal = 1.0
    case fast = 1.25
    case faster = 1.5

    var id: Double { rawValue }

    var displayName: String {
        switch self {
        case .slow: "0.75x"
        case .normal: String(localized: "1x")
        case .fast: "1.25x"
        case .faster: "1.5x"
        }
    }
}

// MARK: - Bible Voice

enum BibleVoice: String, CaseIterable, Identifiable, Codable {
    // Free
    case onyx

    // Pro — Male
    case echo
    case fable

    // Pro — Female
    case nova
    case sage

    var id: String { rawValue }

    /// The OpenAI TTS API voice name (cases match 1:1).
    var apiVoice: String { rawValue }

    /// Ordered list of voice identifiers to try, from highest to lowest quality.
    /// Each voice uses a different locale so they sound distinct even with compact fallbacks.
    var preferredVoiceIdentifiers: [String] {
        switch self {
        case .onyx: // Deep profound male — prefers American Aaron/Zac,
                    // falls back to British Daniel (which ships preinstalled
                    // on every iOS device, so resolution never falls through
                    // to the system default Samantha voice).
            ["com.apple.voice.premium.en-US.Zac",
             "com.apple.voice.enhanced.en-US.Aaron",
             "com.apple.voice.compact.en-US.Aaron",
             "com.apple.voice.enhanced.en-GB.Daniel",
             "com.apple.voice.compact.en-GB.Daniel"]
        case .echo: // British male
            ["com.apple.voice.enhanced.en-GB.Daniel",
             "com.apple.voice.compact.en-GB.Daniel"]
        case .fable: // Australian male
            ["com.apple.voice.enhanced.en-AU.Lee",
             "com.apple.voice.compact.en-AU.Lee"]
        case .nova: // American female
            ["com.apple.voice.premium.en-US.Ava",
             "com.apple.voice.enhanced.en-US.Samantha",
             "com.apple.voice.compact.en-US.Samantha"]
        case .sage: // British female
            ["com.apple.voice.enhanced.en-GB.Kate",
             "com.apple.voice.compact.en-GB.Kate"]
        }
    }

    /// The language locale for this voice (used as final fallback).
    var voiceLanguage: String {
        switch self {
        case .onyx, .nova: "en-US"
        case .echo, .sage: "en-GB"
        case .fable: "en-AU"
        }
    }

    /// Resolves the best available voice on this device.
    ///
    /// Resolution order:
    ///   1. Named identifiers in `preferredVoiceIdentifiers` (premium → enhanced → compact).
    ///   2. A gender-matched scan of installed voices in the target language —
    ///      prevents an all-male choice like `.onyx` from silently falling
    ///      through to Samantha (the en-US system default) when Aaron/Zac
    ///      aren't downloaded.
    ///   3. Final language fallback.
    var resolvedVoice: AVSpeechSynthesisVoice? {
        for identifier in preferredVoiceIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }

        let targetGender: AVSpeechSynthesisVoiceGender = BibleVoice.maleVoices.contains(self) ? .male : .female
        let installed = AVSpeechSynthesisVoice.speechVoices()
        if let match = installed.first(where: {
            $0.gender == targetGender && $0.language.hasPrefix(voiceLanguage.prefix(2))
        }) {
            return match
        }
        if let match = installed.first(where: { $0.gender == targetGender }) {
            return match
        }

        return AVSpeechSynthesisVoice(language: voiceLanguage)
    }

    var displayName: String {
        switch self {
        case .onyx:  String(localized: "Solomon")
        case .echo:  String(localized: "Elijah")
        case .fable: String(localized: "Arthur")
        case .nova:  String(localized: "Grace")
        case .sage:  String(localized: "Naomi")
        }
    }

    var subtitle: String {
        switch self {
        case .onyx:  String(localized: "Deep & commanding")
        case .echo:  String(localized: "Warm & smooth")
        case .fable: String(localized: "Rich & expressive")
        case .nova:  String(localized: "Warm & heartfelt")
        case .sage:  String(localized: "Tender & wise")
        }
    }

    var gender: String {
        switch self {
        case .onyx, .echo, .fable: "Male"
        case .nova, .sage: "Female"
        }
    }

    var isProOnly: Bool { true }

    static let maleVoices: [BibleVoice] = [.onyx, .echo, .fable]
    static let femaleVoices: [BibleVoice] = [.nova, .sage]

    static func voice(for id: String) -> BibleVoice? {
        allCases.first { $0.rawValue == id }
    }
}

// MARK: - Theme Definition

struct ThemeDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let previewGradient: [String] // hex color strings
    let isProOnly: Bool

    /// Maps each theme to a default SanctuaryBackground for unified background system
    var defaultBackgroundID: String {
        switch id {
        case "sunrise-mountains": return "warm-gold"
        case "midnight-gold": return "midnight-blue"
        case "ocean-peace": return "ocean-deep"
        case "minimal-cream": return "soft-cream"
        case "forest-mist": return "forest-dawn"
        case "starry-night": return "starfield"
        default: return "warm-gold"
        }
    }

    static let allThemes: [ThemeDefinition] = [
        ThemeDefinition(
            id: "sunrise-mountains",
            name: "Sunrise Mountains",
            previewGradient: ["C9A96E", "D4B483", "F0E8D8"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "midnight-gold",
            name: "Midnight Gold",
            previewGradient: ["0A1628", "1A2D50", "2A4478"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "ocean-peace",
            name: "Ocean Peace",
            previewGradient: ["0A2342", "1A4570", "2E6D9E"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "minimal-cream",
            name: "Minimal Cream",
            previewGradient: ["FAF8F4", "F0E8D8", "E8DCC8"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "forest-mist",
            name: "Forest Mist",
            previewGradient: ["2D5016", "4A7A2E", "8FB174"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "starry-night",
            name: "Starry Night",
            previewGradient: ["0A0A1A", "14142D", "1E1E40"],
            isProOnly: false
        ),
    ]
}

// MARK: - Activity Event Type

enum ActivityEventType: String, Codable, CaseIterable, Identifiable {
    case chapterRead
    case planDayCompleted
    case aiChatSent
    case verseSaved
    case verseHighlighted
    case audioChapterCompleted
    case prayerWritten
    case prayerAnswered
    case appOpened

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chapterRead: String(localized: "Read a Chapter")
        case .planDayCompleted: String(localized: "Completed a Plan Day")
        case .aiChatSent: String(localized: "Asked AI Companion")
        case .verseSaved: String(localized: "Saved a Verse")
        case .verseHighlighted: String(localized: "Highlighted a Verse")
        case .audioChapterCompleted: String(localized: "Listened to a Chapter")
        case .prayerWritten: String(localized: "Wrote a Prayer")
        case .prayerAnswered: String(localized: "Prayer Answered")
        case .appOpened: String(localized: "Opened the App")
        }
    }

    var icon: String {
        switch self {
        case .chapterRead: "book.fill"
        case .planDayCompleted: "checkmark.circle.fill"
        case .aiChatSent: "bubble.left.fill"
        case .verseSaved: "bookmark.fill"
        case .verseHighlighted: "highlighter"
        case .audioChapterCompleted: "headphones"
        case .prayerWritten: "pencil.and.scribble"
        case .prayerAnswered: "checkmark.seal.fill"
        case .appOpened: "app.badge"
        }
    }
}

// MARK: - Biblical Character

enum BiblicalCharacter: String, CaseIterable, Identifiable {
    case paul, david, moses, mary, solomon, ruth, peter, esther

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paul: String(localized: "Paul")
        case .david: String(localized: "David")
        case .moses: String(localized: "Moses")
        case .mary: String(localized: "Mary")
        case .solomon: String(localized: "Solomon")
        case .ruth: String(localized: "Ruth")
        case .peter: String(localized: "Peter")
        case .esther: String(localized: "Esther")
        }
    }

    var icon: String {
        switch self {
        case .paul: "p.circle.fill"
        case .david: "d.circle.fill"
        case .moses: "m.circle.fill"
        case .mary: "m.circle.fill"
        case .solomon: "s.circle.fill"
        case .ruth: "r.circle.fill"
        case .peter: "p.circle.fill"
        case .esther: "e.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .paul: String(localized: "Apostle & Theologian")
        case .david: String(localized: "King & Psalmist")
        case .moses: String(localized: "Deliverer & Lawgiver")
        case .mary: String(localized: "Mother of Jesus")
        case .solomon: String(localized: "Wisest King")
        case .ruth: String(localized: "Woman of Loyalty")
        case .peter: String(localized: "Rock of the Church")
        case .esther: String(localized: "Queen of Courage")
        }
    }
}

// MARK: - Conversation Mode

enum ConversationMode: String, CaseIterable, Identifiable {
    case comfort, challenge, teach, pray, story

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comfort: String(localized: "Comfort me")
        case .challenge: String(localized: "Challenge me")
        case .teach: String(localized: "Teach me")
        case .pray: String(localized: "Pray with me")
        case .story: String(localized: "Tell me a story")
        }
    }

    var icon: String {
        switch self {
        case .comfort: "heart.fill"
        case .challenge: "flame.fill"
        case .teach: "book.fill"
        case .pray: "hands.sparkles.fill"
        case .story: "book.pages.fill"
        }
    }
}

// MARK: - Chat Emotion

enum ChatEmotion: String, CaseIterable, Identifiable {
    case anxious, sad, grateful, lost, angry, hopeful, lonely, peaceful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anxious: String(localized: "Anxious")
        case .sad: String(localized: "Sad")
        case .grateful: String(localized: "Grateful")
        case .lost: String(localized: "Lost")
        case .angry: String(localized: "Angry")
        case .hopeful: String(localized: "Hopeful")
        case .lonely: String(localized: "Lonely")
        case .peaceful: String(localized: "Peaceful")
        }
    }

    var icon: String {
        switch self {
        case .anxious: "wind"
        case .sad: "cloud.rain.fill"
        case .grateful: "sun.max.fill"
        case .lost: "questionmark.circle.fill"
        case .angry: "bolt.heart.fill"
        case .hopeful: "sunrise.fill"
        case .lonely: "person.fill.questionmark"
        case .peaceful: "leaf.fill"
        }
    }

    var prompt: String {
        switch self {
        case .anxious:
            "I'm feeling anxious right now. Can you help me find peace in Scripture and pray with me?"
        case .sad:
            "I'm feeling really sad today. Can you sit with me in this and share something comforting from the Bible?"
        case .grateful:
            "I'm feeling so grateful right now. Help me express my thanks to God with a prayer of gratitude."
        case .lost:
            "I feel lost and unsure about my direction. What does God's Word say about finding guidance?"
        case .angry:
            "I'm struggling with anger right now. Help me process this through Scripture and prayer."
        case .hopeful:
            "I'm feeling hopeful today. Share a verse that celebrates hope and help me praise God for it."
        case .lonely:
            "I'm feeling really lonely. Remind me from Scripture that God is near, and pray with me."
        case .peaceful:
            "I'm in a peaceful place right now. Help me dwell in God's presence with a meditation on His peace."
        }
    }
}

// MARK: - Notification Topic

enum NotificationTopic: String, Codable, CaseIterable, Identifiable {
    // Free topics (8)
    case morningVerses
    case eveningPeace
    case anxiety
    case strength
    case hope
    case gratitude
    case prayers
    case encouragement

    // Pro topics (12)
    case godsLove
    case faith
    case wisdom
    case forgiveness
    case joy
    case peace
    case trust
    case marriage
    case parenting
    case healing
    case provision
    case spiritualWarfare

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morningVerses: String(localized: "Morning Verses")
        case .eveningPeace: String(localized: "Evening Peace")
        case .anxiety: String(localized: "Anxiety & Comfort")
        case .strength: String(localized: "Strength & Courage")
        case .hope: String(localized: "Hope")
        case .gratitude: String(localized: "Gratitude")
        case .prayers: String(localized: "Prayers")
        case .encouragement: String(localized: "Encouragement")
        case .godsLove: String(localized: "God's Love")
        case .faith: String(localized: "Faith")
        case .wisdom: String(localized: "Wisdom")
        case .forgiveness: String(localized: "Forgiveness")
        case .joy: String(localized: "Joy")
        case .peace: String(localized: "Peace")
        case .trust: String(localized: "Trust")
        case .marriage: String(localized: "Marriage")
        case .parenting: String(localized: "Parenting")
        case .healing: String(localized: "Comfort & Healing")
        case .provision: String(localized: "Provision")
        case .spiritualWarfare: String(localized: "Spiritual Warfare")
        }
    }

    var icon: String {
        switch self {
        case .morningVerses: "sunrise"
        case .eveningPeace: "moon.stars"
        case .anxiety: "heart.circle"
        case .strength: "bolt.heart"
        case .hope: "sun.and.horizon"
        case .gratitude: "hands.sparkles"
        case .prayers: "hands.and.sparkles"
        case .encouragement: "hand.thumbsup"
        case .godsLove: "heart.fill"
        case .faith: "sparkles"
        case .wisdom: "book.closed"
        case .forgiveness: "arrow.uturn.backward.circle"
        case .joy: "face.smiling"
        case .peace: "leaf"
        case .trust: "shield"
        case .marriage: "heart.circle.fill"
        case .parenting: "figure.and.child.holdinghands"
        case .healing: "cross.case"
        case .provision: "basket"
        case .spiritualWarfare: "shield.checkered"
        }
    }

    var isPro: Bool {
        switch self {
        case .morningVerses, .eveningPeace, .anxiety, .strength,
             .hope, .gratitude, .prayers, .encouragement:
            false
        case .godsLove, .faith, .wisdom, .forgiveness,
             .joy, .peace, .trust, .marriage,
             .parenting, .healing, .provision, .spiritualWarfare:
            true
        }
    }

    /// Which curated verse MARK categories this topic maps to.
    var verseCategories: [String] {
        switch self {
        case .morningVerses: ["Morning", "More Morning"]
        case .eveningPeace: ["Bedtime / Peace", "Rest & Sabbath"]
        case .anxiety: ["Anxiety & Worry"]
        case .strength: ["Strength & Courage"]
        case .hope: ["Hope"]
        case .gratitude: ["Gratitude & Thanksgiving"]
        case .prayers: ["Prayer Life"]
        case .encouragement: ["Patience & Perseverance", "Identity in Christ", "More Identity in Christ"]
        case .godsLove: ["God's Love"]
        case .faith: ["Faith"]
        case .wisdom: ["Wisdom"]
        case .forgiveness: ["Forgiveness"]
        case .joy: ["Joy"]
        case .peace: ["Peace"]
        case .trust: ["Trust"]
        case .marriage: ["Marriage"]
        case .parenting: ["Parenting", "Children & Youth"]
        case .healing: ["Comfort & Healing", "Health"]
        case .provision: ["Provision", "More Provision", "Financial", "Work & Diligence", "Generosity & Service"]
        case .spiritualWarfare: ["Spiritual Warfare", "Protection", "More Protection"]
        }
    }

    /// Which notification-content.json categories this topic maps to (if any).
    var notifCategories: [String] {
        switch self {
        case .prayers: ["prayer"]
        case .encouragement: ["encouragement", "affirmation"]
        case .gratitude: ["gratitude"]
        case .hope: ["reflection"]
        case .eveningPeace: ["blessing"]
        default: []
        }
    }

    static var freeTopics: [NotificationTopic] {
        allCases.filter { !$0.isPro }
    }

    static var proTopics: [NotificationTopic] {
        allCases.filter { $0.isPro }
    }
}
