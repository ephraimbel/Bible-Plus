import Foundation
import SwiftData

enum SharedModelContainer {
    static func create() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            PrayerContent.self,
            ContentCollection.self,
            ChatMessage.self,
            Conversation.self,
            SavedBibleVerse.self,
        ])
        let config = ModelConfiguration(
            "BiblePlus",
            schema: schema,
            groupContainer: .identifier("group.io.bibleplus.shared")
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
