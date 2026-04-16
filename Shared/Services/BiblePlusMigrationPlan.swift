import Foundation
import SwiftData

// MARK: - Schema V1 (Initial Release)
//
// This establishes the baseline schema for Bible Plus v1.
// SwiftData handles lightweight migrations automatically (adding new properties
// with default values, adding optional properties). For complex migrations
// (renaming, type changes, deletions), add a new schema version and migration stage.

enum BiblePlusSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            PrayerContent.self,
            ContentCollection.self,
            ChatMessage.self,
            Conversation.self,
            ConversationTopic.self,
            SavedBibleVerse.self,
            ReadingPlan.self,
            UserPlanProgress.self,
            ActivityEvent.self,
        ]
    }
}

// MARK: - Migration Plan

enum BiblePlusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BiblePlusSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migration stages yet — V1 is the baseline.
        // When V2 is added, create a lightweight or custom migration stage:
        //
        //   .lightweight(fromVersion: BiblePlusSchemaV1.self,
        //                toVersion: BiblePlusSchemaV2.self)
        //
        // or for complex migrations:
        //
        //   .custom(fromVersion: BiblePlusSchemaV1.self,
        //           toVersion: BiblePlusSchemaV2.self,
        //           willMigrate: { context in ... },
        //           didMigrate: { context in ... })
        []
    }
}
