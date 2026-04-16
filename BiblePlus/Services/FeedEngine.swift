import Foundation
import SwiftData

final class FeedEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Generate a batch of scored, ordered content for the feed.
    func generateFeed(
        for profile: UserProfile,
        count: Int = 20,
        excluding shownIDs: Set<UUID> = []
    ) -> [PrayerContent] {
        let allContent = fetchAllContent()

        // Filter: remove shown, pro-only if not pro, too-advanced faith level
        let eligible = allContent.filter { content in
            !shownIDs.contains(content.id)
                && (!content.isProOnly || profile.isPro)
                && content.faithLevelMin.numericValue <= profile.faithLevel.numericValue
        }

        // Score each item
        let scored = eligible.map { content in
            ScoredContent(
                content: content,
                score: computeScore(content: content, profile: profile)
            )
        }

        // Sort by score descending
        let sorted = scored.sorted { $0.score > $1.score }

        // Apply type ratio enforcement
        let selected = applyTypeRatios(from: sorted, count: count)

        return selected
    }

    // MARK: - Scoring Algorithm

    private func computeScore(content: PrayerContent, profile: UserProfile) -> Double {
        var score: Double = 1.0

        // Burden weighting: 3x boost if content matches any user burden
        let userBurdens = Set(profile.currentBurdens)
        let contentBurdens = Set(content.applicableBurdens)
        if !userBurdens.intersection(contentBurdens).isEmpty {
            score *= 3.0
        }

        // Season filtering: 2x boost if content matches any user life season
        let userSeasons = Set(profile.lifeSeasons)
        let contentSeasons = Set(content.applicableSeasons)
        if !userSeasons.intersection(contentSeasons).isEmpty {
            score *= 2.0
        }

        // Time awareness: 1.5x if content matches current time of day
        let currentSlot = Self.currentTimeSlot()
        if content.timeOfDay.contains(currentSlot) {
            score *= 1.5
        }

        // Faith depth: 1.3x if exact faith level match
        if content.faithLevelMin == profile.faithLevel {
            score *= 1.3
        }

        // Deterministic jitter seeded by content ID + day (stable within a session,
        // refreshes daily). Uses djb2 hash instead of random() so the feed order
        // doesn't shuffle on every call and stays consistent with widgets.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let jitterInput = content.id.uuidString + String(dayOfYear)
        var djb2: UInt64 = 5381
        for byte in jitterInput.utf8 { djb2 = ((djb2 &<< 5) &+ djb2) &+ UInt64(byte) }
        let jitter = 0.8 + Double(Int(djb2 & 0x7FFFFFFFFFFFFFFF) % 1000) / 1000.0 * 0.4
        score *= jitter

        return score
    }

    // MARK: - Type Ratio Enforcement

    private static let typeRatios: [(ContentType, Double)] = [
        (.prayer, 0.35),
        (.verse, 0.30),
        (.devotional, 0.15),
        (.quote, 0.12),
        (.reflection, 0.08),
    ]

    private func applyTypeRatios(from scored: [ScoredContent], count: Int) -> [PrayerContent] {
        var result: [PrayerContent] = []
        var used: Set<UUID> = []

        // Group by type
        var byType: [ContentType: [ScoredContent]] = [:]
        for item in scored {
            byType[item.content.type, default: []].append(item)
        }

        // Fill each type's quota
        for (type, ratio) in Self.typeRatios {
            let quota = max(1, Int(round(Double(count) * ratio)))
            let available = byType[type] ?? []
            for item in available.prefix(quota) {
                if !used.contains(item.content.id) {
                    result.append(item.content)
                    used.insert(item.content.id)
                }
            }
        }

        // Backfill from remaining highest-scored if under count
        if result.count < count {
            for item in scored where !used.contains(item.content.id) {
                result.append(item.content)
                used.insert(item.content.id)
                if result.count >= count { break }
            }
        }

        // Interleave types for variety
        return interleaveByType(result)
    }

    /// Distribute content types evenly so user doesn't see many of one type in a row
    private func interleaveByType(_ items: [PrayerContent]) -> [PrayerContent] {
        var buckets: [ContentType: [PrayerContent]] = [:]
        for item in items {
            buckets[item.type, default: []].append(item)
        }

        var result: [PrayerContent] = []
        var exhausted = false
        while !exhausted {
            exhausted = true
            for (type, _) in Self.typeRatios {
                if var bucket = buckets[type], !bucket.isEmpty {
                    result.append(bucket.removeFirst())
                    buckets[type] = bucket
                    exhausted = false
                }
            }
        }
        return result
    }

    // MARK: - Helpers

    private func fetchAllContent() -> [PrayerContent] {
        let descriptor = FetchDescriptor<PrayerContent>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    static func currentTimeSlot() -> PrayerTimeSlot {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .midday
        case 17..<21: return .evening
        default: return .bedtime
        }
    }

    // MARK: - Inner Types

    private struct ScoredContent {
        let content: PrayerContent
        let score: Double
    }
}
