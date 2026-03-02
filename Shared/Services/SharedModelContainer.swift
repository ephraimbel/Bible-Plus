import Foundation
import SwiftData

enum SharedModelContainer {
    static func create() throws -> ModelContainer {
        let schema = Schema(versionedSchema: BiblePlusSchemaV1.self)
        let config = ModelConfiguration(
            "BiblePlus",
            schema: schema,
            groupContainer: .identifier("group.io.bibleplus.shared")
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: BiblePlusMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            #if DEBUG
            print("[BiblePlus] ModelContainer failed: \(error). Deleting old store and retrying…")
            #endif
            deleteAllStores()
            return try ModelContainer(
                for: schema,
                migrationPlan: BiblePlusMigrationPlan.self,
                configurations: [config]
            )
        }
    }

    private static func deleteAllStores() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.io.bibleplus.shared"
        ) else { return }

        let fm = FileManager.default
        let appSupport = groupURL.appendingPathComponent("Library/Application Support")

        // SwiftData stores named "BiblePlus" and "default"
        let storeNames = ["BiblePlus", "default"]
        let extensions = ["", ".store", ".sqlite", ".sqlite-wal", ".sqlite-shm",
                          ".store-wal", ".store-shm"]

        for name in storeNames {
            for ext in extensions {
                let url = appSupport.appendingPathComponent("\(name)\(ext)")
                if fm.fileExists(atPath: url.path) {
                    try? fm.removeItem(at: url)
                    #if DEBUG
                    print("[BiblePlus] Deleted: \(url.lastPathComponent)")
                    #endif
                }
            }
        }

        // Also nuke any .store files at the group container root (just in case)
        if let contents = try? fm.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension.contains("store") || url.pathExtension.contains("sqlite") {
                try? fm.removeItem(at: url)
                #if DEBUG
                print("[BiblePlus] Deleted root: \(url.lastPathComponent)")
                #endif
            }
        }

        // And in app support
        if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension.contains("store") || url.pathExtension.contains("sqlite") {
                try? fm.removeItem(at: url)
                #if DEBUG
                print("[BiblePlus] Deleted appSupport: \(url.lastPathComponent)")
                #endif
            }
        }
    }
}
