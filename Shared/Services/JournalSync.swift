import Foundation
import SwiftData

// MARK: - Journal Sync
//
// Bridges devotional/plan reflections into the Journal. When a user writes a
// reflection inside a Daily Path day or a Reading Plan day, that text should
// also live on the Journal page — automatically, with no duplicate entries and
// no orphans left behind if they clear it.
//
// Keyed on `sourceKey` so the link is idempotent: the same reflection always
// maps to the same JournalEntry. One-way (reflection → Journal): the reflection
// is the source of truth for its linked entry; the user can still freely edit
// or delete it in the Journal afterward.
enum JournalSync {

    /// Create, update, or remove the Journal entry linked to a reflection.
    /// - Empty text removes the linked entry (nothing to keep).
    /// - First non-empty text creates the entry with `title`.
    /// - Later edits sync the body only, preserving any title the user changed
    ///   in the Journal and only bumping `updatedAt` when the text truly changed
    ///   (so re-saving an unchanged reflection doesn't reorder the list).
    ///
    /// Does not call `save()` — the caller owns the transaction.
    @MainActor
    static func upsertReflection(
        sourceKey: String,
        title: String,
        text: String,
        in context: ModelContext
    ) {
        guard !sourceKey.isEmpty else { return }
        let key = sourceKey
        let existing = (try? context.fetch(
            FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.sourceKey == key })
        ))?.first

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if let existing { context.delete(existing) }
            return
        }

        if let existing {
            if existing.text != text {
                existing.text = text
                existing.updatedAt = Date()
            }
        } else {
            let entry = JournalEntry(title: title, text: text, sourceKey: key)
            context.insert(entry)
        }
    }
}
