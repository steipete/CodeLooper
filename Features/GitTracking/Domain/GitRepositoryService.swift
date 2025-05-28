import Diagnostics
import Foundation

/// Monitors Git repositories and provides status information
public final class GitRepositoryMonitor: Sendable {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    /// Find Git repository for a given file path and return its status
    /// - Parameter filePath: Path to a file within a potential Git repository
    /// - Returns: GitRepository information if found, nil otherwise
    @MainActor
    public func findRepository(for filePath: String) async -> GitRepository? {
        // Check cache first
        if let cached = getCachedRepository(for: filePath) {
            return cached
        }

        // Find the Git repository root
        guard let repoPath = await findGitRoot(from: filePath) else {
            return nil
        }

        // Get repository status
        let repository = await getRepositoryStatus(at: repoPath)

        // Cache the result
        if let repository {
            cacheRepository(repository, for: filePath)
        }

        return repository
    }

    /// Clear the repository cache
    @MainActor
    public func clearCache() {
        repositoryCache.removeAll()
        cacheTimestamps.removeAll()
    }

    // MARK: Private

    nonisolated private let logger = Logger(category: .supervision)

    /// Cache for repository information to avoid repeated lookups
    @MainActor private var repositoryCache: [String: GitRepository] = [:]

    /// Cache timeout interval (5 seconds)
    private let cacheTimeout: TimeInterval = 5.0

    /// Timestamps for cached entries
    @MainActor private var cacheTimestamps: [String: Date] = [:]

    // MARK: - Private Methods

    @MainActor
    private func getCachedRepository(for filePath: String) -> GitRepository? {
        guard let timestamp = cacheTimestamps[filePath],
              Date().timeIntervalSince(timestamp) < cacheTimeout,
              let cached = repositoryCache[filePath]
        else {
            return nil
        }
        return cached
    }

    @MainActor
    private func cacheRepository(_ repository: GitRepository, for filePath: String) {
        repositoryCache[filePath] = repository
        cacheTimestamps[filePath] = Date()
    }

    /// Find the Git repository root starting from a given path
    nonisolated private func findGitRoot(from path: String) async -> String? {
        var currentPath = URL(fileURLWithPath: path)

        // If it's a file, start from its directory
        if !currentPath.hasDirectoryPath {
            currentPath = currentPath.deletingLastPathComponent()
        }

        // Get home directory path to stop searching
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path

        // Search up the directory tree
        while currentPath.path != "/", currentPath.path.hasPrefix(homeDirectory) {
            let gitPath = currentPath.appendingPathComponent(".git")

            if FileManager.default.fileExists(atPath: gitPath.path) {
                return currentPath.path
            }

            currentPath = currentPath.deletingLastPathComponent()
        }

        return nil
    }

    /// Get repository status by running git status
    nonisolated private func getRepositoryStatus(at repoPath: String) async -> GitRepository? {
        // Run git command in a detached task to avoid blocking main thread
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["status", "--porcelain", "--branch"]
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe() // Suppress error output

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    Logger(category: .supervision).debug("Git status failed with exit code: \(process.terminationStatus)")
                    return nil
                }

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                return GitRepositoryMonitor.staticParseGitStatus(output: output, repoPath: repoPath)
            } catch {
                Logger(category: .supervision).error("Failed to run git status: \(error.localizedDescription)")
                return nil
            }
        }.value
    }

    /// Parse git status --porcelain output
    nonisolated private static func staticParseGitStatus(output: String, repoPath: String) -> GitRepository {
        let lines = output.split(separator: "\n")
        var currentBranch: String?
        var modifiedCount = 0
        var untrackedCount = 0

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Parse branch information (first line with --branch flag)
            if trimmedLine.hasPrefix("##") {
                let branchInfo = trimmedLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                // Extract branch name (format: "branch...tracking" or just "branch")
                if let branchEndIndex = branchInfo.firstIndex(of: ".") {
                    currentBranch = String(branchInfo[..<branchEndIndex])
                } else {
                    currentBranch = branchInfo
                }
                continue
            }

            // Skip empty lines
            guard trimmedLine.count >= 2 else { continue }

            // Get status code (first two characters)
            let statusCode = trimmedLine.prefix(2)

            // Count files based on status codes
            // ?? = untracked
            // M = modified in working tree
            // A = added to index
            // D = deleted
            // R = renamed
            // C = copied
            // U = unmerged
            if statusCode == "??" {
                untrackedCount += 1
            } else if statusCode.contains("M") || statusCode.contains("A") ||
                statusCode.contains("D") || statusCode.contains("R") ||
                statusCode.contains("C") || statusCode.contains("U")
            {
                modifiedCount += 1
            }
        }

        return GitRepository(
            path: repoPath,
            dirtyFileCount: modifiedCount,
            untrackedFileCount: untrackedCount,
            currentBranch: currentBranch
        )
    }
}
