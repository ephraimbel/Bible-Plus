import UIKit
import SwiftUI

// MARK: - Biblical Image Service

/// Maps image keys to bundled classical art assets.
/// The AI references these keys via the system prompt; the service
/// resolves them to UIImage or falls back to a themed gradient.
///
/// Includes a semantic resolver: if the AI emits an unknown or imperfect key,
/// `resolveKey(for:context:)` finds the closest real artwork using tag overlap
/// against the surrounding caption/verse/summary text. This means a chat
/// response always renders relevant art — never a generic gradient — as long
/// as the catalog has any matching theme.
enum BiblicalImageService {

    // MARK: - Image Key Catalog

    /// All known image keys grouped by category.
    /// Each key SHOULD have a matching image set in Assets.xcassets/BiblicalArt/
    /// — but the catalog intentionally contains entries without bundled binaries.
    /// Those entries expand the AI's image vocabulary so it can reach for
    /// narrative-specific concepts; the resolver substitutes the closest
    /// available artwork until binaries are added. See `resolveKey(for:context:)`.
    static let catalog: [String: [ImageEntry]] = loadCatalog()

    private struct CategoryGroup: Decodable {
        let category: String
        let entries: [ImageEntry]
    }

    private static func loadCatalog() -> [String: [ImageEntry]] {
        guard let url = Bundle.main.url(forResource: "biblical-art-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let groups = try? JSONDecoder().decode([CategoryGroup].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: groups.map { ($0.category, $0.entries) })
    }

    /// Flat list of all entries.
    static let allEntries: [ImageEntry] = {
        catalog.values.flatMap { $0 }
    }()

    /// Flat list of all image keys for system prompt injection.
    static let allKeys: [String] = {
        allEntries.map(\.key).sorted()
    }()

    // MARK: - Lookup

    /// Returns the bundled UIImage for an exact key, or nil if not present in assets.
    /// This is the raw lookup — for fuzzy resolution use `image(for:context:)`.
    /// Tries the bare name first, then the namespaced path as a defense in
    /// depth in case the asset catalog's `provides-namespace` flag flips back on.
    static func rawImage(for key: String) -> UIImage? {
        if let direct = UIImage(named: "biblical_\(key)") {
            return direct
        }
        return UIImage(named: "BiblicalArt/biblical_\(key)")
    }

    /// Smart lookup: resolves the key (handles hallucinated/imperfect keys
    /// by tag-matching against optional context) and returns the bundled image.
    static func image(for key: String, context: String? = nil) -> UIImage? {
        let resolved = resolveKey(for: key, context: context)
        return rawImage(for: resolved)
    }

    /// Returns true if the asset exists for the exact key.
    static func hasImage(for key: String) -> Bool {
        rawImage(for: key) != nil
    }

    /// Returns the entry metadata for a key (uses smart resolution).
    static func entry(for key: String, context: String? = nil) -> ImageEntry? {
        let resolved = resolveKey(for: key, context: context)
        return allEntries.first { $0.key == resolved }
    }

    // MARK: - Semantic Resolver

    /// Resolves any string the AI might emit (real key, partial key, made-up key,
    /// or even a scene description) into the best-matching catalog key
    /// **whose asset is actually bundled**. This is the contract: callers can trust
    /// that `rawImage(for: resolveKey(...))` returns a real image, never nil
    /// (unless the catalog ships with zero bundled assets).
    ///
    /// Resolution order — every step filters by `hasImage`:
    /// 1. Exact key match against a bundled asset.
    /// 2. Substring match against bundled-asset keys
    ///    (e.g. "calms_storm" → "jesus_calms_storm").
    /// 3. Tag overlap scoring against input + context, **restricted to entries
    ///    with bundled assets**. Catalog entries without binaries still
    ///    participate as a routing signal: their tags lend their themes to the
    ///    asset-bearing entries via the resolver's input substitution.
    /// 4. Final fallback to the first bundled asset.
    ///
    /// Design note: it is INTENTIONAL that the catalog contains entries without
    /// bundled assets. They expand the AI's image vocabulary so it can reach for
    /// narrative-specific concepts ("noah_ark", "pentecost") even before the
    /// binaries land. The resolver then substitutes the closest available
    /// artwork. As binaries are added, they automatically light up.
    static func resolveKey(
        for input: String,
        context: String? = nil,
        excluding: Set<String> = [],
        seed: Int = 0
    ) -> String {
        let normalized = normalize(input)

        // 1. Exact match with bundled asset (skip if recently used in this
        //    conversation — we want variety over the AI's exact pick).
        if !normalized.isEmpty, hasImage(for: normalized), !excluding.contains(normalized) {
            return normalized
        }

        // Pre-compute the set of entries that actually have bundled assets.
        // Every subsequent step works only against this set so we never return
        // a key the renderer can't load.
        let availableEntries = allEntries.filter { hasImage(for: $0.key) }

        // Apply the recent-use exclusion. If it would empty the pool entirely
        // (small catalog or long conversation), fall back to the full set.
        let usableEntries = availableEntries.filter { !excluding.contains($0.key) }
        let candidates = usableEntries.isEmpty ? availableEntries : usableEntries

        // If the input matched a *catalog* entry without a binary, fold its
        // tags into the haystack so its theme still routes to the right art.
        var inputAugmentation = ""
        if !normalized.isEmpty,
           let phantomEntry = allEntries.first(where: { $0.key == normalized }),
           !hasImage(for: phantomEntry.key) {
            inputAugmentation = phantomEntry.tags.joined(separator: " ") + " " + phantomEntry.title
        }

        // 2. Substring match against candidates only
        if !normalized.isEmpty {
            let substring = candidates.first { entry in
                entry.key.contains(normalized) || normalized.contains(entry.key)
            }
            if let substring { return substring.key }
        }

        // 3. Subject-token gating (NEW).
        //
        // Extract specific "who/what is this about" tokens from input + context
        // and the phantom catalog entry. If we find any, restrict scoring to
        // candidates that share at least one subject token. Generic theme
        // overlap alone is not allowed to substitute one biblical figure for
        // another (the bug this guards against: an Elijah story rendering as
        // Daniel-in-the-lions just because they share "courage", "faith",
        // "prayer" tags).
        let phantomEntry = (!normalized.isEmpty)
            ? allEntries.first(where: { $0.key == normalized && !hasImage(for: $0.key) })
            : nil

        var inputSubjects = subjectTokens(from: input)
        if let context { inputSubjects.formUnion(subjectTokens(from: context)) }
        if let phantomEntry {
            inputSubjects.formUnion(subjectTokens(from: phantomEntry.title))
            for tag in phantomEntry.tags {
                inputSubjects.formUnion(subjectTokens(from: tag))
            }
        }

        let subjectFiltered: [ImageEntry]
        let hadSubjectSignal = !inputSubjects.isEmpty
        if hadSubjectSignal {
            subjectFiltered = candidates.filter { entry in
                !candidateSubjectTokens(entry).isDisjoint(with: inputSubjects)
            }
        } else {
            subjectFiltered = candidates
        }

        // 4. Tag-overlap scoring against input + context + phantom-entry tags,
        //    restricted to subject-relevant candidates.
        let haystack = ([input, inputAugmentation, context]
            .compactMap { $0 }
            .filter { !$0.isEmpty })
            .joined(separator: " ")
            .lowercased()

        let scoringPool = subjectFiltered

        if !haystack.isEmpty, !scoringPool.isEmpty {
            let scored = scoringPool
                .map { entry -> (entry: ImageEntry, score: Int) in
                    var score = 0
                    // Subject token overlap dominates — each shared specific
                    // token is worth far more than a generic tag hit.
                    let entrySubjects = candidateSubjectTokens(entry)
                    let sharedSubjects = entrySubjects.intersection(inputSubjects)
                    score += sharedSubjects.count * 10

                    for tag in entry.tags {
                        if haystack.contains(tag.lowercased()) {
                            // Longer tags are slightly more specific
                            score += max(1, tag.count / 4)
                        }
                    }
                    // Title token overlap as a secondary signal
                    for token in entry.title.lowercased().split(separator: " ") where token.count > 3 {
                        if haystack.contains(token) { score += 1 }
                    }
                    return (entry, score)
                }
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score > rhs.score }
                    return lhs.entry.key < rhs.entry.key
                }

            let positive = scored.filter { $0.score > 0 }
            if !positive.isEmpty {
                // Pick from top thematic matches using the seed for variety.
                let topK = Array(positive.prefix(3))
                let pickIndex = abs(seed) % topK.count
                return topK[pickIndex].entry.key
            }
        }

        // 5. Subject signal but nothing matched → neutral fallback.
        // (This is the key fix: prefer a majestic-but-neutral image over a
        // confidently wrong subject.)
        if hadSubjectSignal, let neutral = neutralFallback(excluding: excluding) {
            return neutral
        }

        // 6. Fallback: rotate through bundled assets by seed.
        if !candidates.isEmpty {
            let pickIndex = abs(seed) % candidates.count
            return candidates[pickIndex].key
        }
        if let firstAsset = availableEntries.first {
            return firstAsset.key
        }
        return allKeys.first ?? input
    }

    // MARK: - Per-Conversation Variety

    /// Per-message resolved-key cache. Keeps SwiftUI re-renders stable so the
    /// same message always shows the same artwork while still letting NEW
    /// messages pick fresh art.
    private static var resolvedKeyCache: [UUID: String] = [:]

    /// Recently-used keys per conversation. The resolver excludes these so
    /// each new scripture card in a conversation surfaces a different artwork.
    private static var recentKeysByConversation: [UUID: [String]] = [:]

    /// How many recent keys to remember per conversation before the oldest
    /// drops out and becomes eligible again.
    private static let recentWindowSize = 6

    /// Message-aware resolver. Use this from chat bubbles so each scripture
    /// card in a conversation rotates through different artworks. Stable
    /// per `messageId` (cache-backed) so SwiftUI re-renders never reshuffle.
    static func resolveKey(
        for input: String,
        context: String?,
        messageId: UUID,
        conversationId: UUID
    ) -> String {
        if let cached = resolvedKeyCache[messageId] {
            return cached
        }

        let recent = Set(recentKeysByConversation[conversationId] ?? [])
        let resolved = resolveKey(
            for: input,
            context: context,
            excluding: recent,
            seed: messageId.hashValue
        )

        resolvedKeyCache[messageId] = resolved

        var list = recentKeysByConversation[conversationId] ?? []
        if !list.contains(resolved) {
            list.append(resolved)
            if list.count > recentWindowSize {
                list.removeFirst(list.count - recentWindowSize)
            }
            recentKeysByConversation[conversationId] = list
        }

        return resolved
    }

    /// Normalizes an AI-emitted key: strips "biblical_" prefix, lowercases,
    /// replaces hyphens/spaces with underscores, removes any remaining junk.
    private static func normalize(_ raw: String) -> String {
        var s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("biblical_") { s.removeFirst("biblical_".count) }
        s = s.replacingOccurrences(of: "-", with: "_")
        s = s.replacingOccurrences(of: " ", with: "_")
        s = s.replacingOccurrences(of: #"[^a-z0-9_]"#, with: "", options: .regularExpression)
        return s
    }

    // MARK: - Default Image (used when nothing else loads)

    /// Returns a guaranteed-loadable bundled artwork. Used as the ultimate
    /// fallback when a requested key has no binary AND the resolver couldn't
    /// substitute a thematic match. Picks deterministically per key so the
    /// same scripture card always shows the same fallback art across renders.
    ///
    /// Walks the small set of bundled "universal" keys — works because these
    /// are guaranteed to exist in the asset catalog (verified at build time).
    static func defaultImage(for key: String) -> UIImage? {
        let universalKeys = [
            "creation_light",      // Creation — works for any beginning/origin
            "sermon_mount",        // Teaching — works for any instruction
            "jesus_calms_storm",   // Peace amid chaos — emotional anchor
            "sacrifice_isaac",     // Faith / surrender
            "nativity",            // Hope / new beginning
            "miraculous_catch",    // Calling / abundance
        ]
        let hash = abs(key.hashValue)
        let pick = universalKeys[hash % universalKeys.count]
        return rawImage(for: pick)
    }

    /// Returns the catalog entry for whichever default image is being shown
    /// for `key`. Lets the bubble's artist credit line stay accurate even when
    /// we're rendering a fallback artwork.
    static func defaultEntry(for key: String) -> ImageEntry? {
        let universalKeys = [
            "creation_light", "sermon_mount", "jesus_calms_storm",
            "sacrifice_isaac", "nativity", "miraculous_catch",
        ]
        let hash = abs(key.hashValue)
        let pick = universalKeys[hash % universalKeys.count]
        return allEntries.first { $0.key == pick }
    }

    // MARK: - Fallback Gradient (legacy — kept for any existing call sites)

    /// Warm-toned wash that matches the chat's design language. Used as a
    /// last-resort when even the default image lookup fails (which should
    /// never happen as long as the bundled set is non-empty). No more
    /// rotating hue chaos — this matches the topGoldGradient elsewhere.
    static func fallbackGradient(for key: String) -> LinearGradient {
        return LinearGradient(
            stops: [
                .init(color: Color(red: 0.79, green: 0.66, blue: 0.43).opacity(0.20), location: 0.0),
                .init(color: Color(red: 0.65, green: 0.48, blue: 0.25).opacity(0.10), location: 0.5),
                .init(color: Color(red: 0.20, green: 0.15, blue: 0.08).opacity(0.18), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Formatted Key List for System Prompt

    /// Returns a tag-rich string of all available images for the AI system prompt.
    /// Format per line: `key — short tag list`. Lets the model pick by meaning,
    /// not just by recognizing the key name.
    ///
    /// Tuned for token economy: 4 tags per entry across 60 entries ≈ 3000 chars
    /// total, comfortably within the edge function's per-message length budget.
    /// Vocabulary exposed to the AI in the system prompt.
    /// **Only includes keys that have a bundled asset** — this prevents the AI
    /// from confidently picking a key the resolver then has to fuzzy-substitute
    /// (which historically led to wrong-subject art, e.g. Daniel-in-lions for an
    /// Elijah story). Catalog entries without bundled assets stay in the catalog
    /// for resolver-internal routing but never reach the model.
    static var imageKeyVocabulary: String {
        catalog.compactMap { category, entries in
            let bundled = entries.filter { hasImage(for: $0.key) }
            guard !bundled.isEmpty else { return nil }
            let lines = bundled.map { entry -> String in
                let topTags = entry.tags.prefix(4).joined(separator: ", ")
                return "  • \(entry.key) — \(topTags)"
            }.joined(separator: "\n")
            return "\(category):\n\(lines)"
        }.joined(separator: "\n")
    }

    // MARK: - Subject Token Extraction (resolver hardening)

    /// Stop tokens that should never be treated as a "subject" — they're either
    /// generic English connectors or generic spiritual themes that match almost
    /// every entry's tags and would defeat subject-based filtering.
    private static let subjectStopwords: Set<String> = [
        // English connectors
        "the", "and", "for", "with", "from", "into", "upon", "this", "that",
        "these", "those", "what", "when", "where", "while", "have", "has",
        "had", "will", "would", "could", "should", "their", "them", "they",
        "your", "yours", "mine", "ours", "after", "before", "about", "than",
        "then", "there", "here", "been", "being", "still", "must", "every",
        "many", "some", "such", "very", "even", "more", "most", "much", "also",
        // Generic spiritual themes (match too many candidates to be useful as subject)
        "faith", "love", "hope", "trust", "peace", "grace", "mercy", "joy",
        "fear", "doubt", "anger", "shame", "guilt", "rest", "comfort",
        "courage", "wisdom", "strength", "patience", "prayer", "praying",
        "healing", "salvation", "kingdom", "spirit", "father", "lord",
        "jesus", "christ", "lord's", "god", "gods", "holy", "sin", "soul",
        "heart", "voice", "story", "scripture", "verse", "narrative",
        "moment", "moments", "today", "world", "people", "person", "life"
    ]

    /// Pulls subject-bearing tokens from a free-form string.
    /// Subject tokens are alphabetic words ≥4 chars, lowercased, excluding
    /// the stopword set above. Used to identify *who/what* a passage is
    /// about so the resolver can require subject overlap before substituting
    /// art (preventing wrong-figure substitutions).
    private static func subjectTokens(from text: String) -> Set<String> {
        let lowered = text
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
        var tokens = Set<String>()
        let scalars = lowered.unicodeScalars
        var current = ""
        for scalar in scalars {
            if CharacterSet.lowercaseLetters.contains(scalar) {
                current.append(Character(scalar))
            } else {
                if current.count >= 4, !subjectStopwords.contains(current) {
                    tokens.insert(current)
                }
                current = ""
            }
        }
        if current.count >= 4, !subjectStopwords.contains(current) {
            tokens.insert(current)
        }
        return tokens
    }

    /// Subject tokens for a candidate entry: union of key, title, and tag tokens.
    private static func candidateSubjectTokens(_ entry: ImageEntry) -> Set<String> {
        var tokens = subjectTokens(from: entry.key)
        tokens.formUnion(subjectTokens(from: entry.title))
        for tag in entry.tags {
            tokens.formUnion(subjectTokens(from: tag))
        }
        return tokens
    }

    /// Designated "subject-neutral" bundled keys, in priority order.
    /// Used as a graceful fallback when the input has clear subject tokens
    /// but no bundled candidate shares any of them — far better to show a
    /// majestic, theme-neutral piece of art than to confidently render a
    /// scene depicting a different biblical figure.
    private static let neutralFallbackKeys: [String] = [
        "creation_light",
        "sermon_mount",
        "ten_commandments",
        "creation_eve"
    ]

    private static func neutralFallback(excluding: Set<String>) -> String? {
        for key in neutralFallbackKeys where hasImage(for: key) && !excluding.contains(key) {
            return key
        }
        // If everything is excluded, return the first available neutral.
        return neutralFallbackKeys.first(where: { hasImage(for: $0) })
    }
}

// MARK: - Image Entry

struct ImageEntry: Identifiable, Decodable {
    let key: String
    let title: String
    let artist: String
    /// Semantic tags for fuzzy resolution. Lowercase, single concepts.
    let tags: [String]

    var id: String { key }
}

// MARK: - Download Checklist

/// Run `BiblicalImageService.printDownloadChecklist()` in debug to get
/// the prioritized list of images to source and add to the asset catalog.
///
/// PRIORITY ORDERING: missing images are grouped into tiers by how often the
/// AI is likely to reach for them and how much visual variety they unlock.
/// Tier 1 = ship these next; Tier 4 = nice to have.
extension BiblicalImageService {

    /// Keys ranked by acquisition priority. Higher tiers should be sourced first.
    /// The ranking reflects: (a) how frequently the AI will route to this theme
    /// in real conversations, and (b) how much variety it adds to the existing
    /// 18-image set.
    static let acquisitionPriority: [(tier: Int, label: String, keys: [String])] = [
        (1, "TIER 1 — ESSENTIAL (massively used themes, biggest visual lift)", [
            "empty_tomb",        // resurrection — central, currently unrepresented
            "last_supper",       // most-referenced communion image
            "prodigal_son",      // most-referenced parable
            "good_samaritan",    // most-referenced parable #2
            "annunciation",      // mary / calling / hidden glory
            "burning_bush",      // calling / vocation / encounter
            "parting_red_sea",   // deliverance / impossible situations
            "gethsemane",        // suffering / submission / agony
            "pentecost",         // spirit / boldness / church
            "lazarus_raised",    // grief / hope / "if you had been here"
        ]),
        (2, "TIER 2 — HIGH IMPACT (broad emotional/teaching coverage)", [
            "jonah_whale",       // running / second chance
            "noah_ark",          // judgment / rescue / covenant
            "joseph_egypt",      // forgiveness / providence
            "ezekiel_bones",     // hopeless situations / revival
            "road_emmaus",       // disappointment / hidden presence
            "walking_water",     // doubt / "save me"
            "elijah_carmel",     // courage / single voice
            "doubting_thomas",   // doubt / wounds / belief
            "feeding_5000",      // small offering / abundance
            "transfiguration",   // glory / vision
        ]),
        (3, "TIER 3 — RICH VARIETY (deepens teaching range)", [
            "jacob_ladder",
            "jacob_wrestling",
            "joseph_dreams",
            "ten_commandments",  // already missing in current 18
            "manna_wilderness",
            "isaiah_seraphim",
            "daniel_furnace",
            "esther_king",
            "ruth_boaz",
            "baptism_jesus",
            "wedding_cana",
            "woman_well",
            "sower_parable",
            "lost_sheep",
            "peter_denial",
            "mary_garden",
            "ascension",
            "paul_damascus",
            "throne_lamb",
            "new_jerusalem",
        ]),
        (4, "TIER 4 — NICE TO HAVE (completes the catalog)", [
            "fall_eden",
            "tower_babel",
            "abraham_promise",
            "golden_calf",
            "brazen_serpent",
            "jericho_walls",
            "gideon_fleece",
            "samson_pillars",
            "david_repents",
            "solomon_temple",
            "solomon_judgment",
            "elijah_chariot",
            "jeremiah_lamenting",
            "magi_journey",
            "pilate_judgment",
            "stoning_stephen",
            "paul_athens",
            "paul_shipwreck",
        ]),
    ]

    static func printDownloadChecklist() {
        print("=== Biblical Art Download Checklist ===")
        print("Add images to: Resources/Assets.xcassets/BiblicalArt/")
        print("Name format: biblical_<key>.imageset")
        print("All listed artists are public domain — source from Wikimedia Commons\n")

        let total = allKeys.count
        let found = allKeys.filter { hasImage(for: $0) }.count
        print("Progress: \(found)/\(total) images bundled\n")

        // Print prioritized missing list first — this is the action list.
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("MISSING IMAGES (sourced in tier order)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        let entryByKey = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.key, $0) })
        var listedKeys: Set<String> = []

        for (_, label, keys) in acquisitionPriority {
            let missing = keys.filter { !hasImage(for: $0) }
            guard !missing.isEmpty else { continue }
            print(label)
            for key in missing {
                guard let entry = entryByKey[key] else { continue }
                print("  ⬜ biblical_\(entry.key)")
                print("     \"\(entry.title)\" — \(entry.artist)")
                listedKeys.insert(key)
            }
            print("")
        }

        // Catch any catalog entries not in the priority list.
        let unlisted = allEntries.filter { !hasImage(for: $0.key) && !listedKeys.contains($0.key) }
        if !unlisted.isEmpty {
            print("UNRANKED — additional missing entries")
            for entry in unlisted {
                print("  ⬜ biblical_\(entry.key) — \"\(entry.title)\" by \(entry.artist)")
            }
            print("")
        }

        // Bundled (✅) section by category for reference.
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("ALREADY BUNDLED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        for (category, entries) in catalog.sorted(by: { $0.key < $1.key }) {
            let bundled = entries.filter { hasImage(for: $0.key) }
            guard !bundled.isEmpty else { continue }
            print("## \(category)")
            for entry in bundled {
                print("  ✅ biblical_\(entry.key) — \"\(entry.title)\" by \(entry.artist)")
            }
            print("")
        }
    }
}
