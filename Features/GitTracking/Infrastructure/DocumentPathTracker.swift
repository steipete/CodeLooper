import Diagnostics
import Foundation

/// Tracks document paths across windows to provide stable Git repository detection
@MainActor
final class DocumentPathTracker {
    // MARK: Lifecycle

    public init(gitRepositoryMonitor: GitRepositoryMonitor) {
        self.gitRepositoryMonitor = gitRepositoryMonitor
    }

    // MARK: Public

    /// Record that a document path was accessed
    public func recordDocumentAccess(_ documentPath: String) async {
        // Check if this is a new document
        let isNewDocument = !allDocumentPaths.contains(documentPath)

        // Add to all paths
        allDocumentPaths.insert(documentPath)

        // Find repository for this path
        if let repository = await gitRepositoryMonitor.findRepository(for: documentPath) {
            // Track this document under its repository
            var paths = repositoryDocumentPaths[repository.path] ?? Set<String>()
            let isNewDocumentInRepo = !paths.contains(documentPath)
            paths.insert(documentPath)
            repositoryDocumentPaths[repository.path] = paths

            // Increment access count
            repositoryAccessCount[repository.path] = (repositoryAccessCount[repository.path] ?? 0) + 1

            // Only log when we first encounter this document in this repository
            if isNewDocumentInRepo {
                logger.debug("Recorded new document: \(documentPath) in repository: \(repository.path)")
            }
        } else if isNewDocument {
            logger.debug("Document path has no Git repository: \(documentPath)")
        }
    }

    /// Get the most frequently accessed repository
    public func getMostFrequentRepository() async -> GitRepository? {
        guard let mostFrequentRepoPath = repositoryAccessCount.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        // Get fresh repository status
        return await gitRepositoryMonitor.findRepository(for: mostFrequentRepoPath)
    }

    /// Get repository for a specific document path, with fallback to most frequent
    public func getRepositoryForDocument(_ documentPath: String?) async -> GitRepository? {
        // First try the specific document path
        if let path = documentPath,
           let repository = await gitRepositoryMonitor.findRepository(for: path)
        {
            return repository
        }

        // Fall back to most frequent repository
        return await getMostFrequentRepository()
    }

    /// Check if a document path exists
    public func documentPathExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Get statistics about tracked paths
    public func getStatistics() -> (totalPaths: Int, repositoryCount: Int, mostFrequent: String?) {
        let mostFrequent = repositoryAccessCount.max(by: { $0.value < $1.value })?.key
        return (
            totalPaths: allDocumentPaths.count,
            repositoryCount: repositoryDocumentPaths.count,
            mostFrequent: mostFrequent
        )
    }

    /// Clear all tracking data
    public func clearTracking() {
        repositoryDocumentPaths.removeAll()
        repositoryAccessCount.removeAll()
        allDocumentPaths.removeAll()
    }

    // MARK: Private

    private let logger = Logger(category: .supervision)

    /// Track document paths and their access frequency
    /// Key: Repository path, Value: Set of document paths
    private var repositoryDocumentPaths: [String: Set<String>] = [:]

    /// Track access count for each repository path
    private var repositoryAccessCount: [String: Int] = [:]

    /// All document paths we've seen (including non-repository files)
    private var allDocumentPaths: Set<String> = []

    /// Cache for repository lookups
    private let gitRepositoryMonitor: GitRepositoryMonitor
}
