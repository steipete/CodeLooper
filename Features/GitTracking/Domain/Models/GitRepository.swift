import Foundation

/// Represents information about a Git repository
public struct GitRepository: Sendable {
    // MARK: Lifecycle

    public init(
        path: String,
        dirtyFileCount: Int = 0,
        untrackedFileCount: Int = 0,
        currentBranch: String? = nil
    ) {
        self.path = path
        self.dirtyFileCount = dirtyFileCount
        self.untrackedFileCount = untrackedFileCount
        self.currentBranch = currentBranch
    }

    // MARK: Public

    /// The root path of the Git repository (.git directory's parent)
    public let path: String

    /// Number of modified files (staged and unstaged)
    public let dirtyFileCount: Int

    /// Number of untracked files
    public let untrackedFileCount: Int

    /// Current branch name
    public let currentBranch: String?

    /// Whether the repository has uncommitted changes
    public var hasChanges: Bool {
        dirtyFileCount > 0 || untrackedFileCount > 0
    }

    /// Total number of files with changes (dirty + untracked)
    public var totalChangedFiles: Int {
        dirtyFileCount + untrackedFileCount
    }
}
