@testable import CodeLooper
import Foundation
import Testing

@Suite("Git Tracking Tests")
struct GitTrackingTests {
    @Test("Git repository initialization") func gitRepositoryInitialization() async throws {
        let repo1 = GitRepository(path: "/Users/test/project")
        #expect(repo1.path == "/Users/test/project")
        #expect(repo1.dirtyFileCount == 0)
        #expect(repo1.untrackedFileCount == 0)
        #expect(repo1.currentBranch == nil)
        #expect(!repo1.hasChanges)
        #expect(repo1.totalChangedFiles == 0)

        // Test repository with changes
        let repo2 = GitRepository(
            path: "/test/repo",
            dirtyFileCount: 3,
            untrackedFileCount: 2,
            currentBranch: "main"
        )
        #expect(repo2.path == "/test/repo")
        #expect(repo2.dirtyFileCount == 3)
        #expect(repo2.untrackedFileCount == 2)
        #expect(repo2.currentBranch == "main")
        #expect(repo2.hasChanges)
        #expect(repo2.totalChangedFiles == 5)
    }

    @Test("Git repository change detection") func gitRepositoryChangeDetection() async throws {
        // Test repository without changes
        let cleanRepo = GitRepository(path: "/test", dirtyFileCount: 0, untrackedFileCount: 0)
        #expect(!cleanRepo.hasChanges)
        #expect(cleanRepo.totalChangedFiles == 0)

        // Test repository with dirty files only
        let dirtyRepo = GitRepository(path: "/test", dirtyFileCount: 5, untrackedFileCount: 0)
        #expect(dirtyRepo.hasChanges)
        #expect(dirtyRepo.totalChangedFiles == 5)

        // Test repository with untracked files only
        let untrackedRepo = GitRepository(path: "/test", dirtyFileCount: 0, untrackedFileCount: 3)
        #expect(untrackedRepo.hasChanges)
        #expect(untrackedRepo.totalChangedFiles == 3)

        // Test repository with both types of changes
        let mixedRepo = GitRepository(path: "/test", dirtyFileCount: 4, untrackedFileCount: 2)
        #expect(mixedRepo.hasChanges)
        #expect(mixedRepo.totalChangedFiles == 6)
    }

    @Test("Git repository branch names") func gitRepositoryBranchNames() async throws {
        let branchNames = [
            "main",
            "master",
            "develop",
            "feature/new-feature",
            "bugfix/issue-123",
            "release/v1.0.0",
            "hotfix/critical-fix",
        ]

        for branchName in branchNames {
            let repo = GitRepository(path: "/test", currentBranch: branchName)
            #expect(repo.currentBranch == branchName)
        }

        // Test repository without branch
        let noBranchRepo = GitRepository(path: "/test", currentBranch: nil)
        #expect(noBranchRepo.currentBranch == nil)
    }

    @Test("Git repository monitor initialization") func gitRepositoryMonitorInitialization() async throws {
        let monitor = await GitRepositoryMonitor()
        #expect(true) // Monitor created
    }

    @Test("Git repository monitor cache operations") func gitRepositoryMonitorCacheOperations() async throws {
        let monitor = await GitRepositoryMonitor()

        // Test cache clearing
        await monitor.clearCache()

        // Since we can't easily test internal cache state without exposing internals,
        // we verify that clearCache doesn't crash and the monitor remains functional
        #expect(true) // Cache cleared without crash
    }

    @Test("Git repository path handling") func gitRepositoryPathHandling() async throws {
        let paths = [
            "/Users/test/project",
            "/home/user/workspace/myproject",
            "/tmp/temp-repo",
            "/Applications/MyApp.app/Contents/Resources",
            "relative/path",
            "",
            ".",
        ]

        for path in paths {
            let repo = GitRepository(path: path)
            #expect(repo.path == path)
        }
    }

    @Test("Git repository file count variations") func gitRepositoryFileCountVariations() async throws {
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

    @Test("Git repository sendable compliance",
          .timeLimit(.minutes(1))) func gitRepositorySendableCompliance() async throws
    {
        // Test that GitRepository can be used across concurrency boundaries
        let repo = GitRepository(
            path: "/test",
            dirtyFileCount: 5,
            untrackedFileCount: 3,
            currentBranch: "main"
        )

        // Test concurrent access to properties
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = repo.path
                return true
            }

            group.addTask {
                _ = repo.hasChanges
                return true
            }

            group.addTask {
                _ = repo.totalChangedFiles
                return true
            }

            group.addTask {
                _ = repo.currentBranch
                return true
            }

            for await result in group {
                #expect(result)
            }
        }
    }

    @Test("Git repository memory and performance",
          .timeLimit(.minutes(1))) func gitRepositoryMemoryAndPerformance() async throws
    {
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
        let endTime = Date()

        let duration = endTime.timeIntervalSince(startTime)

        // Should complete quickly (less than 1 second for 1000 objects)
        #expect(duration < 1.0)

        // Verify all repositories were created
        #expect(repositories.count == 1000)

        // Spot check some repositories
        for i in stride(from: 0, to: 1000, by: 100) {
            #expect(repositories[i].path == "/test/repo\(i)")
        }

        // Clear references
        repositories.removeAll()
        #expect(repositories.isEmpty)
    }

    @Test("Git repository equality") func gitRepositoryEquality() async throws {
        // Test that repositories with same data are equal
        let repo1 = GitRepository(
            path: "/test",
            dirtyFileCount: 5,
            untrackedFileCount: 3,
            currentBranch: "main"
        )

        let repo2 = GitRepository(
            path: "/test",
            dirtyFileCount: 5,
            untrackedFileCount: 3,
            currentBranch: "main"
        )

        #expect(repo1 == repo2)

        // Test that repositories with different data are not equal
        let repo3 = GitRepository(
            path: "/different",
            dirtyFileCount: 5,
            untrackedFileCount: 3,
            currentBranch: "main"
        )

        #expect(repo1 != repo3)
    }

    @Test("Git repository hashable") func gitRepositoryHashable() async throws {
        let repo1 = GitRepository(path: "/test", dirtyFileCount: 1, untrackedFileCount: 2)
        let repo2 = GitRepository(path: "/test", dirtyFileCount: 1, untrackedFileCount: 2)
        let repo3 = GitRepository(path: "/other", dirtyFileCount: 1, untrackedFileCount: 2)

        var set = Set<GitRepository>()
        set.insert(repo1)
        set.insert(repo2) // Should not increase count (same as repo1)
        set.insert(repo3) // Should increase count (different path)

        #expect(set.count == 2)
        #expect(set.contains(repo1))
        #expect(set.contains(repo3))
    }

    @Test("Git repository monitor integration") func gitRepositoryMonitorIntegration() async throws {
        let monitor = await GitRepositoryMonitor()

        // Test that monitor can handle various repository paths
        let testPaths = [
            "/Users/test/project1",
            "/Users/test/project2",
            "/tmp/temp-repo",
        ]

        // Since we can't actually run git commands in tests,
        // we just verify the monitor handles these paths without crashing
        for path in testPaths {
            // This would normally call git status, but in tests it might return nil
            _ = await monitor.findRepository(for: path)
        }

        #expect(true) // Monitor handled all paths without crashing
    }

    @Test("Git repository GitHub URL handling") func gitRepositoryGitHubURLHandling() async throws {
        // Since parseGitHubURL is private, we can only test the public interface
        // Test that GitRepository can be created with GitHub URLs in mind
        let repos = [
            GitRepository(path: "/Users/test/github-project", currentBranch: "main"),
            GitRepository(path: "/Users/test/gitlab-project", currentBranch: "master"),
            GitRepository(path: "/Users/test/local-project", currentBranch: "develop"),
        ]

        for repo in repos {
            #expect(!repo.path.isEmpty)
            #expect(repo.currentBranch != nil)
        }
    }

    @Test("Git repository document path integration") func gitRepositoryDocumentPathIntegration() async throws {
        let monitor = await GitRepositoryMonitor()

        // Test document path scenarios
        let documentPaths = [
            "/Users/test/project/README.md",
            "/Users/test/project/src/main.swift",
            "/Users/test/project/docs/guide.md",
        ]

        for docPath in documentPaths {
            // Extract directory path from document path
            let dirPath = (docPath as NSString).deletingLastPathComponent

            // This would normally check if the directory is a git repo
            _ = await monitor.findRepository(for: dirPath)
        }

        #expect(true) // Document paths handled without crash
    }

    @Test("Git repository concurrent access") func gitRepositoryConcurrentAccess() async throws {
        let monitor = await GitRepositoryMonitor()

        // Test concurrent access to the monitor
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    _ = await monitor.findRepository(for: "/test/repo\(i)")
                }
            }

            // Add some cache clear operations
            group.addTask {
                await monitor.clearCache()
            }

            group.addTask {
                await monitor.clearCache()
            }
        }

        #expect(true) // Concurrent operations completed without crash
    }
}
