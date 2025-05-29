import Diagnostics
import Foundation

/// Tracks document paths per window to provide stable Git repository detection
@MainActor
final class DocumentPathTracker {
    // MARK: Lifecycle

    public init(gitRepositoryMonitor: GitRepositoryMonitor) {
        self.gitRepositoryMonitor = gitRepositoryMonitor
    }

    // MARK: Public

    /// Record that a document path was accessed by a specific window
    public func recordDocumentAccess(_ documentPath: String, forWindow windowId: String) async {
        // Check if this is a new document globally
        let isNewDocument = !allDocumentPaths.contains(documentPath)

        // Add to all paths
        allDocumentPaths.insert(documentPath)

        // Find repository for this path
        if let repository = await gitRepositoryMonitor.findRepository(for: documentPath) {
            // Track this document under its repository for this specific window
            var windowRepoAccess = windowRepositoryAccessCount[windowId] ?? [:]
            windowRepoAccess[repository.path] = (windowRepoAccess[repository.path] ?? 0) + 1
            windowRepositoryAccessCount[windowId] = windowRepoAccess

            // Track document paths per window per repository
            var windowRepoPaths = windowRepositoryDocumentPaths[windowId] ?? [:]
            var paths = windowRepoPaths[repository.path] ?? Set<String>()
            let isNewDocumentInRepoForWindow = !paths.contains(documentPath)
            paths.insert(documentPath)
            windowRepoPaths[repository.path] = paths
            windowRepositoryDocumentPaths[windowId] = windowRepoPaths

            // Only log when we first encounter this document in this repository for this window
            if isNewDocumentInRepoForWindow {
                logger
                    .debug(
                        "Recorded new document for window \(windowId): \(documentPath) in repository: \(repository.path)"
                    )
            }
        } else if isNewDocument {
            logger.debug("Document path has no Git repository: \(documentPath)")
        }
    }

    /// Get the most frequently accessed repository for a specific window
    public func getMostFrequentRepository(forWindow windowId: String) async -> GitRepository? {
        guard let windowAccess = windowRepositoryAccessCount[windowId],
              let mostFrequentRepoPath = windowAccess.max(by: { $0.value < $1.value })?.key
        else {
            return nil
        }

        // Get fresh repository status
        return await gitRepositoryMonitor.findRepository(for: mostFrequentRepoPath)
    }

    /// Get repository for a specific document path, with fallback to most frequent for that window
    public func getRepositoryForDocument(_ documentPath: String?, forWindow windowId: String) async -> GitRepository? {
        // First try the specific document path
        if let path = documentPath,
           let repository = await gitRepositoryMonitor.findRepository(for: path)
        {
            return repository
        }

        // Fall back to most frequent repository for this specific window
        return await getMostFrequentRepository(forWindow: windowId)
    }

    /// Check if a document path exists
    public func documentPathExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Get statistics about tracked paths for a specific window
    public func getStatistics(forWindow windowId: String)
        -> (totalPaths: Int, repositoryCount: Int, mostFrequent: String?)
    {
        let windowRepoPaths = windowRepositoryDocumentPaths[windowId] ?? [:]
        let windowRepoAccess = windowRepositoryAccessCount[windowId] ?? [:]
        let mostFrequent = windowRepoAccess.max { $0.value < $1.value }?.key
        let totalPathsForWindow = windowRepoPaths.values.reduce(0) { $0 + $1.count }

        return (
            totalPaths: totalPathsForWindow,
            repositoryCount: windowRepoPaths.count,
            mostFrequent: mostFrequent
        )
    }

    /// Get statistics about all tracked paths across all windows
    public func getGlobalStatistics() -> (totalPaths: Int, windowCount: Int, repositoryCount: Int) {
        let uniqueRepositories = Set(windowRepositoryDocumentPaths.values.flatMap(\.keys))

        return (
            totalPaths: allDocumentPaths.count,
            windowCount: windowRepositoryDocumentPaths.count,
            repositoryCount: uniqueRepositories.count
        )
    }

    /// Clear all tracking data
    public func clearTracking() {
        windowRepositoryDocumentPaths.removeAll()
        windowRepositoryAccessCount.removeAll()
        allDocumentPaths.removeAll()
    }

    /// Clear tracking data for a specific window
    public func clearTracking(forWindow windowId: String) {
        windowRepositoryDocumentPaths.removeValue(forKey: windowId)
        windowRepositoryAccessCount.removeValue(forKey: windowId)
    }

    // MARK: Private

    private let logger = Logger(category: .supervision)

    /// Track document paths per window per repository
    /// Key: Window ID, Value: [Repository path: Set of document paths]
    private var windowRepositoryDocumentPaths: [String: [String: Set<String>]] = [:]

    /// Track access count for each repository path per window
    /// Key: Window ID, Value: [Repository path: Access count]
    private var windowRepositoryAccessCount: [String: [String: Int]] = [:]

    /// All document paths we've seen (including non-repository files)
    private var allDocumentPaths: Set<String> = []

    /// Cache for repository lookups
    private let gitRepositoryMonitor: GitRepositoryMonitor
}
