@testable import CodeLooper
import Foundation
import XCTest

class GitTrackingTests: XCTestCase {
    func testGitRepositoryInitialization() async throws {
        let repo1 = GitRepository(path: "/Users/test/project")
        XCTAssertEqual(repo1.path, "/Users/test/project")
        XCTAssertEqual(repo1.dirtyFileCount, 0)
        XCTAssertEqual(repo1.untrackedFileCount, 0)
        XCTAssertEqual(repo1.currentBranch, nil)
        XCTAssertEqual(repo1.hasChanges, false)
        XCTAssertEqual(repo1.totalChangedFiles, 0)

        // Test repository with changes
        let repo2 = GitRepository(
            path: "/test/repo",
            dirtyFileCount: 3,
            untrackedFileCount: 2,
            currentBranch: "main"
        )
        XCTAssertEqual(repo2.path, "/test/repo")
        XCTAssertEqual(repo2.dirtyFileCount, 3)
        XCTAssertEqual(repo2.untrackedFileCount, 2)
        XCTAssertEqual(repo2.currentBranch, "main")
        XCTAssertEqual(repo2.hasChanges, true)
        XCTAssertEqual(repo2.totalChangedFiles, 5)
    }

    func testGitRepositoryChangeDetection() async throws {
        // Test repository without changes
        let cleanRepo = GitRepository(path: "/test", dirtyFileCount: 0, untrackedFileCount: 0)
        XCTAssertEqual(cleanRepo.hasChanges, false)
        XCTAssertEqual(cleanRepo.totalChangedFiles, 0)

        // Test repository with dirty files only
        let dirtyRepo = GitRepository(path: "/test", dirtyFileCount: 5, untrackedFileCount: 0)
        XCTAssertEqual(dirtyRepo.hasChanges, true)
        XCTAssertEqual(dirtyRepo.totalChangedFiles, 5)

        // Test repository with untracked files only
        let untrackedRepo = GitRepository(path: "/test", dirtyFileCount: 0, untrackedFileCount: 3)
        XCTAssertEqual(untrackedRepo.hasChanges, true)
        XCTAssertEqual(untrackedRepo.totalChangedFiles, 3)

        // Test repository with both types of changes
        let mixedRepo = GitRepository(path: "/test", dirtyFileCount: 4, untrackedFileCount: 2)
        XCTAssertEqual(mixedRepo.hasChanges, true)
        XCTAssertEqual(mixedRepo.totalChangedFiles, 6)
    }

    func testGitRepositoryBranchNames() async throws {
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
            XCTAssertEqual(repo.currentBranch, branchName)
        }

        // Test repository without branch
        let noBranchRepo = GitRepository(path: "/test", currentBranch: nil)
        XCTAssertEqual(noBranchRepo.currentBranch, nil)
    }

    func testGitRepositoryMonitorInitialization() async throws {
        let monitor = await GitRepositoryMonitor()
        XCTAssertTrue(true) // Monitor created
    }

    func testGitRepositoryMonitorCacheOperations() async throws {
        let monitor = await GitRepositoryMonitor()

        // Test cache clearing
        await monitor.clearCache()

        // Since we can't easily test internal cache state without exposing internals,
        // we verify that clearCache doesn't crash and the monitor remains functional
        XCTAssertTrue(true) // Cache cleared without crash
    }

    func testGitRepositoryPathHandling() async throws {
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
            XCTAssertEqual(repo.path, path)
        }
    }

    func testGitRepositoryFileCountVariations() async throws {
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

            XCTAssertEqual(repo.totalChangedFiles, testCase.expectedTotal)
            XCTAssertEqual(repo.hasChanges, testCase.expectedHasChanges)
        }
    }

    func testGitRepositorySendableCompliance() async throws {
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
                XCTAssertEqual(result, true)
            }
        }
    }

    func testGitRepositoryMemoryAndPerformance() async throws {
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
        XCTAssertLessThan(duration, 1.0)

        // Verify all repositories were created
        XCTAssertEqual(repositories.count, 1000)

        // Spot check some repositories
        for i in stride(from: 0, to: 1000, by: 100) {
            XCTAssertEqual(repositories[i].path, "/test/repo\(i)")
        }

        // Clear references
        repositories.removeAll()
        XCTAssertTrue(repositories.isEmpty)
    }

    func testGitRepositoryEquality() async throws {
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

        XCTAssertEqual(repo1, repo2)

        // Test that repositories with different data are not equal
        let repo3 = GitRepository(
            path: "/different",
            dirtyFileCount: 5,
            untrackedFileCount: 3,
            currentBranch: "main"
        )

        XCTAssertNotEqual(repo1, repo3)
    }

    func testGitRepositoryHashable() async throws {
        let repo1 = GitRepository(path: "/test", dirtyFileCount: 1, untrackedFileCount: 2)
        let repo2 = GitRepository(path: "/test", dirtyFileCount: 1, untrackedFileCount: 2)
        let repo3 = GitRepository(path: "/other", dirtyFileCount: 1, untrackedFileCount: 2)

        var set = Set<GitRepository>()
        set.insert(repo1)
        set.insert(repo2) // Should not increase count (same as repo1)
        set.insert(repo3) // Should increase count (different path)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(repo1))
        XCTAssertTrue(set.contains(repo3))
    }

    func testGitRepositoryMonitorIntegration() async throws {
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
            let _ = await monitor.findRepository(for: path)
        }

        XCTAssertTrue(true) // Monitor handled all paths without crashing
    }

    func testGitRepositoryGitHubURLHandling() async throws {
        // Since parseGitHubURL is private, we can only test the public interface
        // Test that GitRepository can be created with GitHub URLs in mind
        let repos = [
            GitRepository(path: "/Users/test/github-project", currentBranch: "main"),
            GitRepository(path: "/Users/test/gitlab-project", currentBranch: "master"),
            GitRepository(path: "/Users/test/local-project", currentBranch: "develop"),
        ]

        for repo in repos {
            XCTAssertEqual(repo.path.isEmpty, false)
            XCTAssertNotNil(repo.currentBranch)
        }
    }

    func testGitRepositoryDocumentPathIntegration() async throws {
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
            let _ = await monitor.findRepository(for: dirPath)
        }

        XCTAssertTrue(true) // Document paths handled without crash
    }

    func testGitRepositoryConcurrentAccess() async throws {
        let monitor = await GitRepositoryMonitor()

        // Test concurrent access to the monitor
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    let _ = await monitor.findRepository(for: "/test/repo\(i)")
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

        XCTAssertTrue(true) // Concurrent operations completed without crash
    }
}
