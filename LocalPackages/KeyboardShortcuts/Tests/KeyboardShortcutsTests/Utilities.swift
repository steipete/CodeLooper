import Foundation

public extension UserDefaults {
    /**
     Remove all entries.

     - Note: This only removes user-defined entries. System-defined entries will remain.
     */
    func removeAll() {
        for key in dictionaryRepresentation().keys {
            removeObject(forKey: key)
        }
    }
}
