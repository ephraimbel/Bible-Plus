import Foundation
import UIKit

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

    var apiCode: String {
        switch self {
        case .niv: "NIV"
        case .esv: "ESV"
        case .kjv: "KJV"
        case .nlt: "NLT"
        case .nasb: "NASB"
        case .message: "MSG"
        case .nkjv: "NKJV"
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
        case .stillWaters: "Still Waters"
        case .morningLight: "Morning Light"
        case .eveningRest: "Evening Rest"
        case .pureSilence: "Pure Silence"
        case .forestBirds: "Forest Birds"
        case .babblingBrook: "Babbling Brook"
        case .gentleBreeze: "Gentle Breeze"
        case .nightCrickets: "Night Crickets"
        case .gentleWaves: "Gentle Waves"
        case .gentleWaterfall: "Gentle Waterfall"
        case .thunderstorm: "Thunderstorm"
        case .morningDew: "Morning Dew"
        case .whaleSong: "Whale Song"
        case .peacefulPiano: "Peaceful Piano"
        case .softFlute: "Soft Flute"
        case .softGuitar: "Soft Guitar"
        case .heavenlyHarp: "Heavenly Harp"
        case .singingBowls: "Singing Bowls"
        case .tibetanBells: "Tibetan Bells"
        case .gregorianChant: "Gregorian Chant"
        case .celestialVoices: "Celestial Voices"
        case .worshipPads: "Worship Pads"
        case .deepSpace: "Deep Space"
        case .gardenPrayer: "Garden Prayer"
        case .mountainTop: "Mountain Top"
        case .nightWatch: "Night Watch"
        case .oceanOfGrace: "Ocean of Grace"
        case .heavenlyWorship: "Heavenly Worship"
        case .rainOfBlessing: "Rain of Blessing"
        case .fireplace: "Fireplace"
        }
    }

    var description: String {
        switch self {
        case .stillWaters: "Gentle flowing water for peaceful meditation"
        case .morningLight: "Soft piano and birds to start your day"
        case .eveningRest: "Warm ambient tones for winding down"
        case .pureSilence: "No sound — just you and God"
        case .forestBirds: "Birdsong in a peaceful forest canopy"
        case .babblingBrook: "Flowing stream through a quiet woodland"
        case .gentleBreeze: "Soft wind whispering through the trees"
        case .nightCrickets: "Crickets chirping under a starlit sky"
        case .gentleWaves: "Calm ocean waves lapping at the shore"
        case .gentleWaterfall: "Soothing cascade of falling water"
        case .thunderstorm: "Distant thunder and steady rain"
        case .morningDew: "Peaceful dawn with soft nature sounds"
        case .whaleSong: "Majestic whale calls in the deep ocean"
        case .peacefulPiano: "Soft solo piano for quiet reflection"
        case .softFlute: "Delicate flute melodies for meditation"
        case .softGuitar: "Gentle acoustic guitar for devotion"
        case .heavenlyHarp: "Soothing harp melodies for worship"
        case .singingBowls: "Resonant singing bowls for deep meditation"
        case .tibetanBells: "Harmonic bell tones for contemplation"
        case .gregorianChant: "Ancient monastic chanting for contemplation"
        case .celestialVoices: "Ethereal vocal harmonies for prayer"
        case .worshipPads: "Ambient atmosphere for prayerful moments"
        case .deepSpace: "Cosmic ambient tones for wonder and awe"
        case .gardenPrayer: "Nature sounds with gentle wind"
        case .mountainTop: "Sweeping atmosphere for deep worship"
        case .nightWatch: "Deep midnight ambience for late prayers"
        case .oceanOfGrace: "Rolling waves and distant shore"
        case .heavenlyWorship: "Ethereal pads and soft vocals"
        case .rainOfBlessing: "Gentle rainfall with distant thunder"
        case .fireplace: "Warm crackling fire for cozy devotions"
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
        case .stillWaters, .morningLight, .eveningRest, .pureSilence:
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
        case .fifteenMin: "15 Minutes"
        case .thirtyMin: "30 Minutes"
        case .oneHour: "1 Hour"
        case .twoHours: "2 Hours"
        case .untilClose: "Until I Close"
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
    case seasonal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essentials: "Essentials"
        case .nature: "Nature"
        case .oceanAndWater: "Ocean & Water"
        case .nightSky: "Night Sky"
        case .warmthAndGlow: "Warmth & Glow"
        case .calmAndSerene: "Calm & Serene"
        case .sacred: "Sacred"
        case .seasonal: "Seasonal"
        }
    }

    var isProOnly: Bool {
        switch self {
        case .essentials: false
        case .nature, .oceanAndWater, .nightSky, .warmthAndGlow, .calmAndSerene, .sacred, .seasonal: true
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

    static func loadImage(named name: String) -> UIImage? {
        if let cached = imageCache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache[name] = image
        return image
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

        // MARK: Essentials (12 — all free)
        bgs.append(contentsOf: [
            SanctuaryBackground(id: "warm-gold", name: "Warm Gold", collection: .essentials, gradientColors: ["C9A96E", "D4B483", "F0E8D8"]),
            SanctuaryBackground(id: "forest-dawn", name: "Forest Dawn", collection: .essentials, gradientColors: ["2D5016", "4A7A2E", "8FB174"]),
            SanctuaryBackground(id: "mountain-mist", name: "Mountain Mist", collection: .essentials, gradientColors: ["6B7B8D", "9AACBD", "C8D5E0"]),
            SanctuaryBackground(id: "desert-sun", name: "Desert Sun", collection: .essentials, gradientColors: ["C2842F", "D4A054", "F0D8A0"]),
            SanctuaryBackground(id: "twilight-lake", name: "Twilight Lake", collection: .essentials, gradientColors: ["1A2744", "3A4F6E", "6E8AAA"]),
            SanctuaryBackground(id: "meadow-green", name: "Meadow Green", collection: .essentials, gradientColors: ["3A6B35", "5C9454", "A8D5A0"]),
            SanctuaryBackground(id: "royal-purple", name: "Royal Purple", collection: .essentials, gradientColors: ["2D1B4E", "4A2C7A", "7B52AB"]),
            SanctuaryBackground(id: "ember-glow", name: "Ember Glow", collection: .essentials, gradientColors: ["4A1A1A", "7A2D2D", "A04040"]),
            SanctuaryBackground(id: "midnight-blue", name: "Midnight Blue", collection: .essentials, gradientColors: ["0A1628", "1A2D50", "2A4478"]),
            SanctuaryBackground(id: "rose-gold", name: "Rose Gold", collection: .essentials, gradientColors: ["8B6B61", "B89485", "E0C4B8"]),
            SanctuaryBackground(id: "soft-cream", name: "Soft Cream", collection: .essentials, gradientColors: ["FAF8F4", "F0E8D8", "E8DCC8"]),
            SanctuaryBackground(id: "steel-grey", name: "Steel Grey", collection: .essentials, gradientColors: ["2C2C2C", "484848", "6A6A6A"]),
        ])

        // MARK: Nature (19 — all Pro, videos → images → gradients)
        bgs.append(contentsOf: [
            // Videos
            SanctuaryBackground(id: "forest-sunlight", name: "Forest Sunlight", collection: .nature, gradientColors: ["1A3D0A", "2D6B1A", "5C9A3A"], videoFileName: "forest-sunlight", isProOnly: true),
            SanctuaryBackground(id: "gentle-waterfall", name: "Gentle Waterfall", collection: .nature, gradientColors: ["1A4A5C", "2D7A9A", "5AACCC"], videoFileName: "gentle-waterfall", isProOnly: true),
            SanctuaryBackground(id: "misty-mountains", name: "Misty Mountains", collection: .nature, gradientColors: ["4A5A6A", "6A7A8A", "9AACBC"], videoFileName: "misty-mountains", isProOnly: true),
            SanctuaryBackground(id: "cherry-blossoms", name: "Cherry Blossoms", collection: .nature, gradientColors: ["8B3060", "C06090", "E8A0BF"], videoFileName: "cherry-blossoms", isProOnly: true),
            SanctuaryBackground(id: "autumn-leaves", name: "Autumn Leaves", collection: .nature, gradientColors: ["6B2D10", "A05020", "D48040"], videoFileName: "autumn-leaves", isProOnly: true),
            SanctuaryBackground(id: "wheat-field-wind", name: "Wheat Field", collection: .nature, gradientColors: ["6B5A1A", "9A8430", "C8B060"], videoFileName: "wheat-field-wind", isProOnly: true),
            SanctuaryBackground(id: "morning-fog-lake", name: "Morning Fog Lake", collection: .nature, gradientColors: ["3A4A5A", "5A7A8A", "8AACBC"], videoFileName: "morning-fog-lake", isProOnly: true),
            SanctuaryBackground(id: "desert-dunes", name: "Desert Dunes", collection: .nature, gradientColors: ["8B6A3A", "B89060", "D8B888"], videoFileName: "desert-dunes", isProOnly: true),
            // Images
            SanctuaryBackground(id: "mountain-sunrise-img", name: "Mountain Sunrise", collection: .nature, gradientColors: ["C2842F", "D4A054", "F0D8A0"], imageName: "mountain-sunrise", isProOnly: true),
            SanctuaryBackground(id: "forest-path-img", name: "Forest Path", collection: .nature, gradientColors: ["1A3D0A", "3A6B2A", "6A9A5A"], imageName: "forest-path", isProOnly: true),
            SanctuaryBackground(id: "calm-lake-img", name: "Calm Lake", collection: .nature, gradientColors: ["2A4A6A", "4A7A9A", "7AACCC"], imageName: "calm-lake", isProOnly: true),
            SanctuaryBackground(id: "misty-forest-img", name: "Misty Forest", collection: .nature, gradientColors: ["2D4A2D", "4A6A4A", "7A9A7A"], imageName: "misty-forest", isProOnly: true),
            SanctuaryBackground(id: "green-meadow-img", name: "Green Meadow", collection: .nature, gradientColors: ["3A6B35", "5C9454", "A8D5A0"], imageName: "green-meadow", isProOnly: true),
            SanctuaryBackground(id: "tropical-waterfall-img", name: "Tropical Falls", collection: .nature, gradientColors: ["1A4A3A", "2D7A5A", "4AAA7A"], imageName: "tropical-waterfall", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "autumn-ember", name: "Autumn Ember", collection: .nature, gradientColors: ["8B3A2F", "B85C3A", "D4956A"], isProOnly: true),
            SanctuaryBackground(id: "cherry-blossom", name: "Cherry Blossom", collection: .nature, gradientColors: ["E8A0BF", "F0C8D8", "FCE4EC"], isProOnly: true),
            SanctuaryBackground(id: "northern-lights", name: "Northern Lights", collection: .nature, gradientColors: ["0B3D2E", "1A6B4A", "38C98B"], isProOnly: true),
            SanctuaryBackground(id: "stormy-sky", name: "Stormy Sky", collection: .nature, gradientColors: ["2C3E50", "4A6274", "7A9BB0"], isProOnly: true),
            SanctuaryBackground(id: "canyon-rock", name: "Canyon Rock", collection: .nature, gradientColors: ["8B4513", "A0522D", "CD853F"], isProOnly: true),
        ])

        // MARK: Ocean & Water (9 — all Pro, videos → images → gradients)
        bgs.append(contentsOf: [
            // Videos
            SanctuaryBackground(id: "flowing-water", name: "Flowing Water", collection: .oceanAndWater, gradientColors: ["1A5276", "2980B9", "5DADE2"], videoFileName: "water-ripples", isProOnly: true),
            SanctuaryBackground(id: "ocean-aerial", name: "Ocean Aerial", collection: .oceanAndWater, gradientColors: ["0A3D5C", "1A6B8A", "2E9AB8"], videoFileName: "ocean-aerial", isProOnly: true),
            SanctuaryBackground(id: "ocean-waves", name: "Ocean Waves", collection: .oceanAndWater, gradientColors: ["0D4F6B", "1A7A9E", "3AACCC"], videoFileName: "ocean-waves", isProOnly: true),
            SanctuaryBackground(id: "gentle-rain", name: "Gentle Rain", collection: .oceanAndWater, gradientColors: ["37474F", "546E7A", "78909C"], videoFileName: "rain-window", isProOnly: true),
            SanctuaryBackground(id: "rain-on-leaves", name: "Rain on Leaves", collection: .oceanAndWater, gradientColors: ["1A3D1A", "2D5A2D", "4A7A4A"], videoFileName: "rain-on-leaves", isProOnly: true),
            SanctuaryBackground(id: "underwater-light", name: "Underwater Light", collection: .oceanAndWater, gradientColors: ["0A2D5C", "1A5A8A", "2A8AB8"], videoFileName: "underwater-light", isProOnly: true),
            SanctuaryBackground(id: "ember-particles", name: "Shimmering Sea", collection: .oceanAndWater, gradientColors: ["1A0A00", "4A1A08", "8B3A10"], videoFileName: "water-glistening", isProOnly: true),
            // Images
            SanctuaryBackground(id: "ocean-sunset-img", name: "Ocean Sunset", collection: .oceanAndWater, gradientColors: ["8B3A1A", "C96B3A", "E8A060"], imageName: "ocean-sunset", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "ocean-deep", name: "Ocean Deep", collection: .oceanAndWater, gradientColors: ["0A2342", "1A4570", "2E6D9E"], isProOnly: true),
        ])

        // MARK: Night Sky (6 — all Pro, videos → images)
        bgs.append(contentsOf: [
            // Videos
            SanctuaryBackground(id: "starfield", name: "Starfield", collection: .nightSky, gradientColors: ["0A0A1A", "14142D", "1E1E40"], videoFileName: "starry-night", isProOnly: true),
            SanctuaryBackground(id: "aurora-wave", name: "Aurora Wave", collection: .nightSky, gradientColors: ["0D2137", "1A4A4A", "2D8A6A"], videoFileName: "milky-way", isProOnly: true),
            SanctuaryBackground(id: "northern-aurora", name: "Northern Aurora", collection: .nightSky, gradientColors: ["0B1D0B", "0D3B2E", "38C98B"], videoFileName: "northern-aurora", isProOnly: true),
            SanctuaryBackground(id: "starry-timelapse", name: "Starry Timelapse", collection: .nightSky, gradientColors: ["0A0A1A", "0D1B3D", "1A2D5E"], videoFileName: "starry-timelapse", isProOnly: true),
            SanctuaryBackground(id: "moonlit-clouds", name: "Moonlit Clouds", collection: .nightSky, gradientColors: ["0A1628", "1A2D50", "3A4D70"], videoFileName: "moonlit-clouds", isProOnly: true),
            // Images
            SanctuaryBackground(id: "starry-mountains-img", name: "Starry Mountains", collection: .nightSky, gradientColors: ["0A0A1A", "14142D", "1E1E40"], imageName: "starry-mountains", isProOnly: true),
        ])

        // MARK: Warmth & Glow (8 — all Pro, videos → images → gradients)
        bgs.append(contentsOf: [
            // Videos
            SanctuaryBackground(id: "candle-flicker", name: "Candle Flicker", collection: .warmthAndGlow, gradientColors: ["4A2800", "8B5E14", "C9A96E"], videoFileName: "candlelight", isProOnly: true),
            SanctuaryBackground(id: "golden-dust", name: "Golden Dust", collection: .warmthAndGlow, gradientColors: ["1A1408", "3D3014", "6B5424"], videoFileName: "golden-lake", isProOnly: true),
            SanctuaryBackground(id: "fireplace", name: "Warm Fireplace", collection: .warmthAndGlow, gradientColors: ["3D1A08", "6B3010", "9A5020"], videoFileName: "fireplace", isProOnly: true),
            SanctuaryBackground(id: "sunset-clouds", name: "Sunset Clouds", collection: .warmthAndGlow, gradientColors: ["8B3A1A", "C96B3A", "E8A060"], videoFileName: "sunset-clouds", isProOnly: true),
            // Images
            SanctuaryBackground(id: "desert-sunset-img", name: "Desert Sunset", collection: .warmthAndGlow, gradientColors: ["8B4A1A", "B86A30", "D89050"], imageName: "desert-sunset", isProOnly: true),
            // Gradients
            SanctuaryBackground(id: "coral-sunset", name: "Coral Sunset", collection: .warmthAndGlow, gradientColors: ["FF6B6B", "EE5A6F", "C44569"], isProOnly: true),
            SanctuaryBackground(id: "bronze-age", name: "Bronze Age", collection: .warmthAndGlow, gradientColors: ["5C3D1E", "8B6040", "B08860"], isProOnly: true),
            SanctuaryBackground(id: "charcoal-flame", name: "Charcoal Flame", collection: .warmthAndGlow, gradientColors: ["1A1A1A", "3D1C1C", "6B2D2D"], isProOnly: true),
        ])

        // MARK: Calm & Serene (7 — all Pro, videos → images → gradients)
        bgs.append(contentsOf: [
            // Videos
            SanctuaryBackground(id: "cloud-drift", name: "Cloud Drift", collection: .calmAndSerene, gradientColors: ["4A6FA5", "6B8FC4", "A8C8E8"], videoFileName: "clouds-moving", isProOnly: true),
            SanctuaryBackground(id: "mountain-clouds", name: "Mountain Clouds", collection: .calmAndSerene, gradientColors: ["3A4A5A", "5A6A7A", "8A9AAA"], videoFileName: "mountain-clouds", isProOnly: true),
            SanctuaryBackground(id: "snow-falling", name: "Gentle Snow", collection: .calmAndSerene, gradientColors: ["B0BEC5", "CFD8DC", "ECEFF1"], videoFileName: "snow-falling", isProOnly: true),
            // Images
            SanctuaryBackground(id: "cherry-blossom-trees-img", name: "Blossom Avenue", collection: .calmAndSerene, gradientColors: ["E8A0BF", "F0C8D8", "FCE4EC"], imageName: "cherry-blossom-trees", isProOnly: true),
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

        // MARK: Seasonal (10 — all Pro)
        bgs.append(contentsOf: [
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
        ])

        return bgs
    }()

    static func background(for id: String) -> SanctuaryBackground? {
        allBackgrounds.first { $0.id == id }
    }

    static func backgrounds(in collection: BackgroundCollection) -> [SanctuaryBackground] {
        allBackgrounds.filter { $0.collection == collection }
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
        case .gold: "Gold"
        case .blue: "Blue"
        case .green: "Green"
        case .pink: "Pink"
        case .purple: "Purple"
        case .orange: "Orange"
        case .teal: "Teal"
        case .lavender: "Lavender"
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
}

// MARK: - Reader Font Style

enum ReaderFontStyle: String, Codable, CaseIterable, Identifiable {
    case serif
    case sansSerif

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serif: "Serif"
        case .sansSerif: "Sans Serif"
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
        case .normal: "1x"
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
    case ash
    case verse
    case fable
    case ballad
    case alloy

    // Pro — Female
    case nova
    case shimmer
    case coral
    case sage

    var id: String { rawValue }

    /// The OpenAI TTS voice name sent to the API.
    var apiVoice: String { rawValue }

    var displayName: String {
        switch self {
        case .onyx:    "The Preacher"
        case .echo:    "The Shepherd"
        case .ash:     "The Narrator"
        case .verse:   "The Prophet"
        case .fable:   "The Elder"
        case .ballad:  "The Patriarch"
        case .alloy:   "The Deacon"
        case .nova:    "The Comforter"
        case .shimmer: "The Psalmist"
        case .coral:   "The Guide"
        case .sage:    "The Sage"
        }
    }

    var subtitle: String {
        switch self {
        case .onyx:    "Deep & authoritative"
        case .echo:    "Warm & smooth"
        case .ash:     "Clear & grounded"
        case .verse:   "Dramatic & poetic"
        case .fable:   "Weathered & wise old soul"
        case .ballad:  "Warm & down-home country"
        case .alloy:   "Steady & balanced"
        case .nova:    "Warm & expressive"
        case .shimmer: "Bright & melodic"
        case .coral:   "Calm & clear"
        case .sage:    "Gentle & wise"
        }
    }

    var gender: String {
        switch self {
        case .onyx, .echo, .ash, .verse, .fable, .ballad, .alloy: "Male"
        case .nova, .shimmer, .coral, .sage: "Female"
        }
    }

    var icon: String {
        switch self {
        case .onyx:    "waveform"
        case .echo:    "waveform.path"
        case .ash:     "waveform.badge.mic"
        case .verse:   "theatermasks"
        case .fable:   "book.closed"
        case .ballad:  "mountain.2"
        case .alloy:   "person"
        case .nova:    "sparkles"
        case .shimmer: "music.note"
        case .coral:   "leaf"
        case .sage:    "moon.stars"
        }
    }

    var isProOnly: Bool {
        self != .onyx
    }

    static let freeVoices: [BibleVoice] = [.onyx]
    static let proMaleVoices: [BibleVoice] = [.echo, .ash, .verse, .fable, .ballad, .alloy]
    static let proFemaleVoices: [BibleVoice] = [.nova, .shimmer, .coral, .sage]

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
            previewGradient: ["FFF1E0", "FFDBB5", "F5EFE0"],
            isProOnly: false
        ),
        ThemeDefinition(
            id: "midnight-gold",
            name: "Midnight Gold",
            previewGradient: ["2B2A27", "343330", "3D3428"],
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
