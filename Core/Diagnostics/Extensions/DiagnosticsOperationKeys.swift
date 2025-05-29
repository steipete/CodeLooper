import Foundation

/// Extension for String keys used in diagnostics
extension String {
    // Upload operations
    static let uploadContacts = "UploadContacts"
    static let exportContacts = "ExportContacts"
    static let uploadFile = "UploadFile"
    static let downloadProfilePic = "DownloadProfilePic"

    // Authentication operations
    static let authentication = "Authentication"
    static let tokenRefresh = "TokenRefresh"

    // Settings operations
    static let saveSettings = "SaveSettings"
    static let loadSettings = "LoadSettings"

    // App lifecycle operations
    static let appLaunch = "AppLaunch"
    static let appTerminate = "AppTerminate"
    static let windowOpen = "WindowOpen"
    static let windowClose = "WindowClose"

    // Menu operations
    static let menuRefresh = "MenuRefresh"
    static let menuAction = "MenuAction"
}
