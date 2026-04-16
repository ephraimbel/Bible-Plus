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
            NSLog("[BiblePlus] ModelContainer failed: \(error). Backing up store and retrying…")

            // Back up the existing store before deleting so user data can
            // potentially be recovered if the fresh container also works.
            backupStores()
            deleteAllStores()

            return try ModelContainer(
                for: schema,
                migrationPlan: BiblePlusMigrationPlan.self,
                configurations: [config]
            )
        }
    }

    /// Copies existing store files to a timestamped backup directory
    /// so data is not irreversibly lost if the fresh container succeeds.
    private static func backupStores() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.io.bibleplus.shared"
        ) else { return }

        let fm = FileManager.default
        let appSupport = groupURL.appendingPathComponent("Library/Application Support")
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = appSupport.appendingPathComponent("Backups/\(timestamp)")

        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        } catch {
            NSLog("[BiblePlus] Could not create backup directory: \(error)")
            return
        }

        let storeNames = ["BiblePlus", "default"]
        let extensions = ["", ".store", ".sqlite", ".sqlite-wal", ".sqlite-shm",
                          ".store-wal", ".store-shm"]

        for name in storeNames {
            for ext in extensions {
                let source = appSupport.appendingPathComponent("\(name)\(ext)")
                guard fm.fileExists(atPath: source.path) else { continue }
                let dest = backupDir.appendingPathComponent("\(name)\(ext)")
                do {
                    try fm.copyItem(at: source, to: dest)
                    NSLog("[BiblePlus] Backed up: \(source.lastPathComponent)")
                } catch {
                    NSLog("[BiblePlus] Backup copy failed for \(source.lastPathComponent): \(error)")
                }
            }
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
                    NSLog("[BiblePlus] Deleted: \(url.lastPathComponent)")
                }
            }
        }

        // Also nuke any .store files at the group container root (just in case)
        if let contents = try? fm.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension.contains("store") || url.pathExtension.contains("sqlite") {
                try? fm.removeItem(at: url)
                NSLog("[BiblePlus] Deleted root: \(url.lastPathComponent)")
            }
        }

        // And in app support (excluding Backups directory)
        if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for url in contents where (url.pathExtension.contains("store") || url.pathExtension.contains("sqlite"))
                && !url.path.contains("Backups") {
                try? fm.removeItem(at: url)
                NSLog("[BiblePlus] Deleted appSupport: \(url.lastPathComponent)")
            }
        }
    }
}
