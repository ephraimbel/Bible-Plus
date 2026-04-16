import Foundation
import SwiftData

extension ModelContext {
    /// Saves with error logging. Logs in both DEBUG and production via NSLog
    /// so save failures are visible in device logs and crash reporters.
    func safeSave(_ label: String = #function) {
        do {
            try save()
        } catch {
            NSLog("[SwiftData] Save failed in %@: %@", label, error.localizedDescription)
        }
    }
}
