import SwiftData

extension ModelContext {
    /// Saves with error logging instead of silently swallowing failures.
    func safeSave(_ label: String = #function) {
        do {
            try save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save failed in \(label): \(error)")
            #endif
        }
    }
}
