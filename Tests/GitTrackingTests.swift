@testable import CodeLooper
import Foundation
import Testing

@Test("GitRepository - Initialization")
func gitRepositoryInitialization() async throws {
    let repo1 = GitRepository(path: "/Users/test/project")
    #expect(repo1.path == "/Users/test/project")
    #expect(repo1.dirtyFileCount == 0)
    #expect(repo1.untrackedFileCount == 0)
    #expect(repo1.currentBranch == nil)
    #expect(repo1.hasChanges == false)
    #expect(repo1.totalChangedFiles == 0)

    let repo2 = GitRepository(
        path: "/Users/test/project2",
        dirtyFileCount: 3,
        untrackedFileCount: 2,
        currentBranch: "main"
    )
    #expect(repo2.path == "/Users/test/project2")
    #expect(repo2.dirtyFileCount == 3)
    #expect(repo2.untrackedFileCount == 2)
    #expect(repo2.currentBranch == "main")
    #expect(repo2.hasChanges == true)
    #expect(repo2.totalChangedFiles == 5)
}

@Test("GitRepository - Change Detection")
func gitRepositoryChangeDetection() async throws {
    // Test repository without changes
    let cleanRepo = GitRepository(path: "/test", dirtyFileCount: 0, untrackedFileCount: 0)
    #expect(cleanRepo.hasChanges == false)
    #expect(cleanRepo.totalChangedFiles == 0)

    // Test repository with dirty files only
    let dirtyRepo = GitRepository(path: "/test", dirtyFileCount: 5, untrackedFileCount: 0)
    #expect(dirtyRepo.hasChanges == true)
    #expect(dirtyRepo.totalChangedFiles == 5)

    // Test repository with untracked files only
    let untrackedRepo = GitRepository(path: "/test", dirtyFileCount: 0, untrackedFileCount: 3)
    #expect(untrackedRepo.hasChanges == true)
    #expect(untrackedRepo.totalChangedFiles == 3)

    // Test repository with both types of changes
    let mixedRepo = GitRepository(path: "/test", dirtyFileCount: 4, untrackedFileCount: 2)
    #expect(mixedRepo.hasChanges == true)
    #expect(mixedRepo.totalChangedFiles == 6)
}

@Test("GitRepository - GitHub URL Parsing")
func gitRepositoryGitHubURLParsing() async throws {
    // Test HTTPS URL parsing
    let httpsURL = "https://github.com/user/repo.git"
    let parsedHTTPS = GitRepository.parseGitHubURL(from: httpsURL)
    #expect(parsedHTTPS?.absoluteString == "https://github.com/user/repo")

    // Test HTTPS URL without .git suffix
    let httpsNoGit = "https://github.com/user/repo"
    let parsedHTTPSNoGit = GitRepository.parseGitHubURL(from: httpsNoGit)
    #expect(parsedHTTPSNoGit?.absoluteString == "https://github.com/user/repo")

    // Test SSH URL parsing
    let sshURL = "git@github.com:user/repo.git"
    let parsedSSH = GitRepository.parseGitHubURL(from: sshURL)
    #expect(parsedSSH?.absoluteString == "https://github.com/user/repo")

    // Test SSH URL without .git suffix
    let sshNoGit = "git@github.com:user/repo"
    let parsedSSHNoGit = GitRepository.parseGitHubURL(from: sshNoGit)
    #expect(parsedSSHNoGit?.absoluteString == "https://github.com/user/repo")

    // Test non-GitHub URLs
    let gitlabURL = "https://gitlab.com/user/repo.git"
    let parsedGitlab = GitRepository.parseGitHubURL(from: gitlabURL)
    #expect(parsedGitlab == nil)

    let invalidURL = "invalid-url"
    let parsedInvalid = GitRepository.parseGitHubURL(from: invalidURL)
    #expect(parsedInvalid == nil)
}

@Test("GitRepository - Branch Names")
func gitRepositoryBranchNames() async throws {
    let branchNames = [
        "main",
        "master",
        "develop",
        "feature/new-feature",
        "bugfix/issue-123",
        "release/v1.0.0",
        "hotfix/critical-fix",
        "feature/user-authentication_with_oauth2",
    ]

    for branchName in branchNames {
        let repo = GitRepository(path: "/test", currentBranch: branchName)
        #expect(repo.currentBranch == branchName)
    }

    // Test repository without branch
    let noBranchRepo = GitRepository(path: "/test", currentBranch: nil)
    #expect(noBranchRepo.currentBranch == nil)
}

@Test("GitRepositoryMonitor - Initialization")
func gitRepositoryMonitorInitialization() async throws {
    let monitor = GitRepositoryMonitor()
    #expect(monitor != nil)
}

@Test("GitRepositoryMonitor - Cache Operations")
func gitRepositoryMonitorCacheOperations() async throws {
    let monitor = GitRepositoryMonitor()

    // Test cache clearing
    await monitor.clearCache()

    // Since we can't easily test internal cache state without exposing internals,
    // we verify that clearCache doesn't crash and the monitor remains functional
    #expect(monitor != nil)
}

@Test("GitRepository - Git Status Parsing")
func gitRepositoryStatusParsing() async throws {
    // Test parsing empty git status output
    let emptyOutput = "## main"
    let emptyRepo = GitRepositoryMonitor.staticParseGitStatus(output: emptyOutput, repoPath: "/test")
    #expect(emptyRepo.currentBranch == "main")
    #expect(emptyRepo.dirtyFileCount == 0)
    #expect(emptyRepo.untrackedFileCount == 0)

    // Test parsing git status with various file statuses
    let complexOutput = """
    ## feature/test-branch...origin/feature/test-branch
     M modified_file.txt
    ?? untracked_file.txt
    A  added_file.txt
     D deleted_file.txt
    ?? another_untracked.txt
    R  renamed_file.txt -> new_name.txt
    """

    let complexRepo = GitRepositoryMonitor.staticParseGitStatus(output: complexOutput, repoPath: "/test")
    #expect(complexRepo.currentBranch == "feature/test-branch")
    #expect(complexRepo.dirtyFileCount == 4) // M, A, D, R
    #expect(complexRepo.untrackedFileCount == 2) // ??
    #expect(complexRepo.totalChangedFiles == 6)
    #expect(complexRepo.hasChanges == true)
}

@Test("GitRepository - Git Status Edge Cases")
func gitRepositoryStatusEdgeCases() async throws {
    // Test parsing with no branch information
    let noBranchOutput = """
     M file1.txt
    ?? file2.txt
    """
    let noBranchRepo = GitRepositoryMonitor.staticParseGitStatus(output: noBranchOutput, repoPath: "/test")
    #expect(noBranchRepo.currentBranch == nil)
    #expect(noBranchRepo.dirtyFileCount == 1)
    #expect(noBranchRepo.untrackedFileCount == 1)

    // Test parsing with branch tracking information
    let trackingOutput = "## main...origin/main [ahead 2, behind 1]"
    let trackingRepo = GitRepositoryMonitor.staticParseGitStatus(output: trackingOutput, repoPath: "/test")
    #expect(trackingRepo.currentBranch == "main")

    // Test parsing with empty output
    let emptyOutput = ""
    let emptyRepo = GitRepositoryMonitor.staticParseGitStatus(output: emptyOutput, repoPath: "/test")
    #expect(emptyRepo.currentBranch == nil)
    #expect(emptyRepo.dirtyFileCount == 0)
    #expect(emptyRepo.untrackedFileCount == 0)

    // Test parsing with only whitespace
    let whitespaceOutput = "   \n  \n   "
    let whitespaceRepo = GitRepositoryMonitor.staticParseGitStatus(output: whitespaceOutput, repoPath: "/test")
    #expect(whitespaceRepo.dirtyFileCount == 0)
    #expect(whitespaceRepo.untrackedFileCount == 0)
}

@Test("GitRepository - Path Handling")
func gitRepositoryPathHandling() async throws {
    let paths = [
        "/Users/test/project",
        "/home/user/workspace/myproject",
        "/tmp/temp-repo",
        "/Applications/MyApp.app/Contents/Resources",
        "relative/path",
        "",
        "/",
        "/Users/test/project with spaces",
        "/Users/test/project-with-dashes",
        "/Users/test/project_with_underscores",
    ]

    for path in paths {
        let repo = GitRepository(path: path)
        #expect(repo.path == path)
    }
}

@Test("GitRepository - File Count Variations")
func gitRepositoryFileCountVariations() async throws {
    let testCases = [
        (dirty: 0, untracked: 0, expectedTotal: 0, expectedHasChanges: false),
        (dirty: 1, untracked: 0, expectedTotal: 1, expectedHasChanges: true),
        (dirty: 0, untracked: 1, expectedTotal: 1, expectedHasChanges: true),
        (dirty: 5, untracked: 3, expectedTotal: 8, expectedHasChanges: true),
        (dirty: 100, untracked: 50, expectedTotal: 150, expectedHasChanges: true),
        (dirty: 0, untracked: 1000, expectedTotal: 1000, expectedHasChanges: true),
    ]

    for testCase in testCases {
        let repo = GitRepository(
            path: "/test",
            dirtyFileCount: testCase.dirty,
            untrackedFileCount: testCase.untracked
        )

        #expect(repo.totalChangedFiles == testCase.expectedTotal)
        #expect(repo.hasChanges == testCase.expectedHasChanges)
    }
}

@Test("GitRepository - Sendable Compliance")
func gitRepositorySendableCompliance() async throws {
    // Test that GitRepository can be used across concurrency boundaries
    let repo = GitRepository(
        path: "/test",
        dirtyFileCount: 5,
        untrackedFileCount: 3,
        currentBranch: "main"
    )

    // Test concurrent access
    await withTaskGroup(of: Bool.self) { group in
        for _ in 0 ..< 10 {
            group.addTask {
                let path = repo.path
                let dirty = repo.dirtyFileCount
                let untracked = repo.untrackedFileCount
                let branch = repo.currentBranch
                let hasChanges = repo.hasChanges
                let total = repo.totalChangedFiles

                return path == "/test" &&
                    dirty == 5 &&
                    untracked == 3 &&
                    branch == "main" &&
                    hasChanges == true &&
                    total == 8
            }
        }

        for await result in group {
            #expect(result == true)
        }
    }
}

@Test("GitRepository - Memory and Performance")
func gitRepositoryMemoryAndPerformance() async throws {
    // Test creating many repository objects
    var repositories: [GitRepository] = []

    let startTime = Date()
    for i in 0 ..< 1000 {
        let repo = GitRepository(
            path: "/test/repo\(i)",
            dirtyFileCount: i % 10,
            untrackedFileCount: i % 5,
            currentBranch: i % 2 == 0 ? "main" : "develop"
        )
        repositories.append(repo)
    }
    let elapsed = Date().timeIntervalSince(startTime)

    #expect(repositories.count == 1000)
    #expect(elapsed < 1.0) // Should complete quickly

    // Verify data integrity
    for (index, repo) in repositories.enumerated() {
        #expect(repo.path == "/test/repo\(index)")
        #expect(repo.dirtyFileCount == index % 10)
        #expect(repo.untrackedFileCount == index % 5)
        #expect(repo.currentBranch == (index % 2 == 0 ? "main" : "develop"))
    }

    // Clear references
    repositories.removeAll()
    #expect(repositories.isEmpty)
}

@Test("GitRepository - Real Git Status Patterns")
func gitRepositoryRealGitStatusPatterns() async throws {
    // Test various real-world git status patterns
    let realWorldPatterns = [
        // Clean repository
        ("## main", 0, 0, "main"),

        // Repository with modifications
        ("## main\n M README.md\n?? newfile.txt", 1, 1, "main"),

        // Repository with staged changes
        ("## develop\nA  staged.txt\nM  modified.txt", 2, 0, "develop"),

        // Repository with deletions
        ("## feature/branch\n D deleted.txt\n?? untracked.txt", 1, 1, "feature/branch"),

        // Repository with renames and copies
        ("## main\nR  old.txt -> new.txt\nC  copied.txt", 2, 0, "main"),

        // Repository with merge conflicts
        ("## main\nU  conflicted.txt\nAA both_added.txt", 2, 0, "main"),

        // Complex repository state
        (
            "## feature/complex-branch...origin/feature/complex-branch [ahead 2]\n M modified1.txt\n?? untracked1.txt\nA  added.txt\n D deleted.txt\n?? untracked2.txt\nR  renamed.txt -> new_name.txt",
            4,
            2,
            "feature/complex-branch"
        ),
    ]

    for (output, expectedDirty, expectedUntracked, expectedBranch) in realWorldPatterns {
        let repo = GitRepositoryMonitor.staticParseGitStatus(output: output, repoPath: "/test")
        #expect(repo.dirtyFileCount == expectedDirty)
        #expect(repo.untrackedFileCount == expectedUntracked)
        #expect(repo.currentBranch == expectedBranch)
    }
}

@Test("GitRepository - URL Edge Cases")
func gitRepositoryURLEdgeCases() async throws {
    let urlTestCases = [
        // Standard cases
        ("https://github.com/user/repo.git", "https://github.com/user/repo"),
        ("https://github.com/user/repo", "https://github.com/user/repo"),
        ("git@github.com:user/repo.git", "https://github.com/user/repo"),
        ("git@github.com:user/repo", "https://github.com/user/repo"),

        // Edge cases that should return nil
        ("https://gitlab.com/user/repo.git", nil),
        ("https://bitbucket.org/user/repo.git", nil),
        ("git@gitlab.com:user/repo.git", nil),
        ("", nil),
        ("invalid-url", nil),
        ("http://github.com/user/repo", nil), // HTTP instead of HTTPS
        ("https://github.com/", nil), // Incomplete URL
        ("git@github.com:", nil), // Incomplete SSH URL
    ]

    for (input, expected) in urlTestCases {
        let result = GitRepository.parseGitHubURL(from: input)
        if let expected {
            #expect(result?.absoluteString == expected)
        } else {
            #expect(result == nil)
        }
    }
}
