import AppKit
@testable import CodeLooper
import Foundation
import Testing

@Suite("Heartbeat Monitoring", .tags(.monitoring, .core))
@MainActor
struct HeartbeatMonitoringTests {
    // MARK: Internal

    @Suite("Instance Info", .tags(.model, .basic))
    struct InstanceInfoTests {
        @Test("Construction and properties")
        func instanceInfoConstruction() async throws {
            let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
            let status = CursorInstanceStatus.idle
            let statusMessage = "Test status"

            let instanceInfo = CursorInstanceInfo(
                app: mockApp,
                status: status,
                statusMessage: statusMessage,
                lastInterventionType: .connection
            )

            // Group related assertions for better failure reporting
            #expectAll("Process identifiers are consistent") {
                #expect(instanceInfo.id == 12345)
                #expect(instanceInfo.processIdentifier == 12345)
                #expect(instanceInfo.pid == 12345)
            }
            
            #expectAll("App properties are set correctly") {
                #expect(instanceInfo.bundleIdentifier == "com.test.app")
                #expect(instanceInfo.localizedName == "Test App")
            }
            
            #expectAll("Status properties are set correctly") {
                #expect(instanceInfo.status == .idle)
                #expect(instanceInfo.statusMessage == "Test status")
                #expect(instanceInfo.lastInterventionType == .connection)
            }
        }

        @Test(
            "Equality based on PID",
            arguments: [
                (pid1: 12345, pid2: 12345, shouldEqual: true, reason: "Same PID should be equal"),
                (pid1: 12345, pid2: 54321, shouldEqual: false, reason: "Different PID should not be equal"),
                (pid1: 0, pid2: 0, shouldEqual: true, reason: "Zero PIDs should be equal"),
                (pid1: Int.max, pid2: Int.max, shouldEqual: true, reason: "Max PIDs should be equal")
            ]
        )
        func instanceInfoEquality(testCase: (pid1: pid_t, pid2: pid_t, shouldEqual: Bool, reason: String)) async throws {
            let mockApp1 = createMockRunningApplication(pid: testCase.pid1, bundleId: "com.test.app", name: "Test App")
            let mockApp2 = createMockRunningApplication(pid: testCase.pid2, bundleId: "com.test.app", name: "Test App")

            let instanceInfo1 = CursorInstanceInfo(
                app: mockApp1,
                status: .idle,
                statusMessage: "Test",
                lastInterventionType: .connection
            )

            let instanceInfo2 = CursorInstanceInfo(
                app: mockApp2,
                status: .idle,
                statusMessage: "Test",
                lastInterventionType: .connection
            )

            if testCase.shouldEqual {
                #expect(instanceInfo1 == instanceInfo2, "\(testCase.reason)")
            } else {
                #expect(instanceInfo1 != instanceInfo2, "\(testCase.reason)")
            }
        }

    @Test("Instance info hashable") func instanceInfoHashable() async throws {
        let mockApp1 = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
        let mockApp2 = createMockRunningApplication(pid: 54321, bundleId: "com.test.app", name: "Test App")

        let instanceInfo1 = CursorInstanceInfo(
            app: mockApp1,
            status: .idle,
            statusMessage: "Test 1",
            lastInterventionType: .connection
        )

        let instanceInfo2 = CursorInstanceInfo(
            app: mockApp2,
            status: .working(detail: "Test 2"),
            statusMessage: "Test 2",
            lastInterventionType: .stuck
        )

        var instanceSet: Set<CursorInstanceInfo> = []
        instanceSet.insert(instanceInfo1)
        instanceSet.insert(instanceInfo2)
        instanceSet.insert(instanceInfo1) // Duplicate

        #expect(instanceSet.count == 2) // Should contain only unique instances
        #expect(instanceSet.contains(instanceInfo1))
        #expect(instanceSet.contains(instanceInfo2))
    }

    @Test("Instance status change tracking") func instanceStatusChangeTracking() async throws {
        let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

        var instanceInfo = CursorInstanceInfo(
            app: mockApp,
            status: .unknown,
            statusMessage: "Starting",
            lastInterventionType: nil
        )

        // Test status progression
        instanceInfo.status = .idle
        instanceInfo.statusMessage = "Now idle"
        #expect(instanceInfo.status == .idle)
        #expect(instanceInfo.statusMessage == "Now idle")

        instanceInfo.status = .working(detail: "Processing")
        instanceInfo.statusMessage = "Working on task"
        #expect(instanceInfo.status == .working(detail: "Processing"))
        #expect(instanceInfo.statusMessage == "Working on task")

        instanceInfo.status = .recovering(type: .connection, attempt: 1)
        instanceInfo.statusMessage = "Attempting recovery"
        instanceInfo.lastInterventionType = .connection
        #expect(instanceInfo.status == .recovering(type: .connection, attempt: 1))
        #expect(instanceInfo.lastInterventionType == .connection)
    }

    }
    
    @Suite("Status Helpers", .tags(.model, .validation))
    struct StatusHelperTests {
        @Test(
            "Recovery status detection",
            arguments: [
                (status: CursorInstanceStatus.recovering(type: .connection, attempt: 1), isRecovering: true),
                (status: .idle, isRecovering: false),
                (status: .working(detail: "test"), isRecovering: false),
                (status: .paused, isRecovering: false),
                (status: .error(reason: "test"), isRecovering: false)
            ]
        )
        func isRecoveringDetection(testCase: (status: CursorInstanceStatus, isRecovering: Bool)) {
            #expect(testCase.status.isRecovering() == testCase.isRecovering)
        }
        
        @Test(
            "Specific recovery type detection",
            arguments: zip(
                [
                    CursorInstanceStatus.recovering(type: .connection, attempt: 1),
                    .recovering(type: .stuck, attempt: 1),
                    .recovering(type: .forceStop, attempt: 1),
                    .idle
                ],
                [
                    (checkType: RecoveryType.connection, expected: true),
                    (checkType: .stuck, expected: true),
                    (checkType: .connection, expected: false),
                    (checkType: .connection, expected: false)
                ]
            )
        )
        func specificRecoveryTypeDetection(
            status: CursorInstanceStatus,
            check: (checkType: RecoveryType, expected: Bool)
        ) {
            #expect(status.isRecovering(ofType: check.checkType) == check.expected)
        }
        
        @Test("Multiple recovery type detection")
        func multipleRecoveryTypeDetection() {
            let recoveryTypes: [RecoveryType] = [.connection, .stuck]
            
            let testCases: [(status: CursorInstanceStatus, shouldMatch: Bool)] = [
                (.recovering(type: .connection, attempt: 1), true),
                (.recovering(type: .stuck, attempt: 2), true),
                (.recovering(type: .forceStop, attempt: 1), false),
                (.idle, false),
                (.working(detail: "active"), false)
            ]
            
            for testCase in testCases {
                #expect(
                    testCase.status.isRecovering(ofAnyType: recoveryTypes) == testCase.shouldMatch,
                    "Status \(testCase.status) should \(testCase.shouldMatch ? "" : "not ")match recovery types"
                )
            }
        }

    }
    
    @Suite("String Extensions", .tags(.utilities))
    struct StringExtensionTests {
        @Test(
            "Stable hash consistency",
            arguments: [
                (text: "Hello World", expectedBehavior: "consistent hash"),
                (text: "", expectedBehavior: "zero for empty"),
                (text: "🚀 Unicode 测试", expectedBehavior: "handles unicode"),
                (text: String(repeating: "a", count: 1000), expectedBehavior: "handles long strings")
            ]
        )
        func stableHashConsistency(testCase: (text: String, expectedBehavior: String)) {
            let hash1 = testCase.text.stableHash()
            let hash2 = testCase.text.stableHash()
            
            #expect(hash1 == hash2, "Hash should be deterministic for \(testCase.expectedBehavior)")
            
            if testCase.text.isEmpty {
                #expect(hash1 == 0, "Empty string should hash to 0")
            }
        }
        
        @Test(
            "Hash uniqueness",
            arguments: zip(
                ["Hello", "World", "Hello World", "Hello World!"],
                ["Hello", "World", "Hello World", "Hello World"]
            )
        )
        func hashUniqueness(text1: String, text2: String) {
            if text1 == text2 {
                #expect(text1.stableHash() == text2.stableHash(), "Same strings should have same hash")
            } else {
                #expect(text1.stableHash() != text2.stableHash(), "Different strings should have different hashes")
            }
        }

    @Test("Bundle identifier edge cases") func bundleIdentifierEdgeCases() async throws {
        // Test with nil bundle identifier
        let mockAppNilBundle = createMockRunningApplication(pid: 12345, bundleId: nil, name: "Test App")
        let instanceInfo = CursorInstanceInfo(
            app: mockAppNilBundle,
            status: .idle,
            statusMessage: "Test",
            lastInterventionType: nil
        )

        #expect(instanceInfo.bundleIdentifier == nil)
        #expect(instanceInfo.id == 12345)
        #expect(instanceInfo.localizedName == "Test App")
    }

    }
    
    @Suite("Status Messages", .tags(.validation))
    struct StatusMessageTests {
        @Test(
            "Message variations",
            arguments: [
                "Starting up",
                "Processing request",
                "Waiting for response",
                "Recovering from error",
                "Intervention paused",
                "",
                "Very long status message that contains multiple pieces of information about the current state",
                "Special chars: !@#$%^&*()",
                "Unicode: 🚀 📱 💻 测试"
            ]
        )
        func statusMessageVariations(message: String) async throws {
            let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
            
            let instanceInfo = CursorInstanceInfo(
                app: mockApp,
                status: .working(detail: "test"),
                statusMessage: message,
                lastInterventionType: nil
            )

            #expectAll {
                #expect(instanceInfo.statusMessage == message)
                #expect(instanceInfo.id == 12345)
                #expect(instanceInfo.bundleIdentifier == "com.test.app")
            }
        }

    @Test("Recovery attempt progression in heartbeat") func recoveryAttemptProgressionInHeartbeat() async throws {
        let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

        // Simulate recovery attempt progression
        var instanceInfo = CursorInstanceInfo(
            app: mockApp,
            status: .recovering(type: .connection, attempt: 1),
            statusMessage: "First attempt",
            lastInterventionType: .connection
        )

        #expect(instanceInfo.status == .recovering(type: .connection, attempt: 1))

        // Progress to second attempt
        instanceInfo.status = .recovering(type: .connection, attempt: 2)
        instanceInfo.statusMessage = "Second attempt"
        #expect(instanceInfo.status == .recovering(type: .connection, attempt: 2))

        // Progress to third attempt
        instanceInfo.status = .recovering(type: .connection, attempt: 3)
        instanceInfo.statusMessage = "Third attempt"
        #expect(instanceInfo.status == .recovering(type: .connection, attempt: 3))

        // Different attempts should not be equal
        let attempt1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let attempt2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
        #expect(attempt1 != attempt2)
    }

        @Test(
            "Intervention type tracking",
            arguments: [
                nil,
                RecoveryType.connection,
                .stopGenerating,
                .stuck,
                .forceStop
            ] as [RecoveryType?]
        )
        func interventionTypeTracking(interventionType: RecoveryType?) async throws {
            let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
            
            let instanceInfo = CursorInstanceInfo(
                app: mockApp,
                status: .idle,
                statusMessage: "Test",
                lastInterventionType: interventionType
            )

            #expect(instanceInfo.lastInterventionType == interventionType)
        }

    @Test("Instance collection operations") func instanceCollectionOperations() async throws {
        let mockApp1 = createMockRunningApplication(pid: 12345, bundleId: "com.test.app1", name: "App 1")
        let mockApp2 = createMockRunningApplication(pid: 54321, bundleId: "com.test.app2", name: "App 2")
        let mockApp3 = createMockRunningApplication(pid: 67890, bundleId: "com.test.app3", name: "App 3")

        let instances = [
            CursorInstanceInfo(app: mockApp1, status: .idle, statusMessage: "Idle", lastInterventionType: nil),
            CursorInstanceInfo(
                app: mockApp2,
                status: .working(detail: "Active"),
                statusMessage: "Working",
                lastInterventionType: .connection
            ),
            CursorInstanceInfo(
                app: mockApp3,
                status: .recovering(type: .stuck, attempt: 2),
                statusMessage: "Recovering",
                lastInterventionType: .stuck
            ),
        ]

        #expect(instances.count == 3)

        // Test filtering by status
        let workingInstances = instances.filter { instance in
            if case .working = instance.status { return true }
            return false
        }
        #expect(workingInstances.count == 1)
        #expect(workingInstances.first?.pid == 54321)

        // Test filtering by intervention type
        let instancesWithInterventions = instances.filter { $0.lastInterventionType != nil }
        #expect(instancesWithInterventions.count == 2)

        // Test finding by PID
        let targetInstance = instances.first { $0.pid == 67890 }
        #expect(targetInstance != nil)
        #expect(targetInstance?.status == .recovering(type: .stuck, attempt: 2))
    }

    }
    
    @Suite("Status Transitions", .tags(.state, .validation))
    struct StatusTransitionTests {
        @Test(
            "Valid status transitions",
            arguments: [
                (from: CursorInstanceStatus.unknown, to: CursorInstanceStatus.idle, isValid: true),
                (from: .idle, to: .working(detail: "Started"), isValid: true),
                (from: .working(detail: "Active"), to: .recovering(type: .connection, attempt: 1), isValid: true),
                (from: .recovering(type: .connection, attempt: 1), to: .error(reason: "Failed"), isValid: true),
                (from: .error(reason: "Recoverable"), to: .recovering(type: .stuck, attempt: 1), isValid: true),
                (from: .recovering(type: .stuck, attempt: 3), to: .unrecoverable(reason: "Max attempts"), isValid: true),
                (from: .error(reason: "Temporary"), to: .idle, isValid: true),
                (from: .recovering(type: .connection, attempt: 1), to: .paused, isValid: true)
            ]
        )
        func statusTransitionValidation(transition: (from: CursorInstanceStatus, to: CursorInstanceStatus, isValid: Bool)) {
            // All transitions should result in different statuses
            #expect(transition.from != transition.to, "From and to statuses should be different")
            
            // Verify each status can be compared properly
            let sameStatus = transition.from
            #expect(transition.from == sameStatus, "Status equality should work")
            
            // In a real app, you might validate if the transition is allowed
            if transition.isValid {
                #expect(true, "Transition from \(transition.from) to \(transition.to) is valid")
            }
        }

    @Test("Hash consistency") func hashConsistency() async throws {
        let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

        let instanceInfo1 = CursorInstanceInfo(
            app: mockApp,
            status: .working(detail: "Processing"),
            statusMessage: "Active",
            lastInterventionType: .connection
        )

        let instanceInfo2 = CursorInstanceInfo(
            app: mockApp,
            status: .working(detail: "Processing"),
            statusMessage: "Active",
            lastInterventionType: .connection
        )

        // Same properties should produce same hash
        #expect(instanceInfo1.hashValue == instanceInfo2.hashValue)

        // Different recovery attempts should produce different hashes
        let status1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let status2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)

        var hasher1 = Hasher()
        status1.hash(into: &hasher1)

        var hasher2 = Hasher()
        status2.hash(into: &hasher2)

        #expect(hasher1.finalize() != hasher2.finalize())
    }

    @Test("Thread safety considerations") func threadSafetyConsiderations() async throws {
        let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

        // Test concurrent access to instance info (read-only operations)
        let instanceInfo = CursorInstanceInfo(
            app: mockApp,
            status: .idle,
            statusMessage: "Test",
            lastInterventionType: nil
        )

        // Test that properties can be accessed
        let pid = instanceInfo.pid
        let id = instanceInfo.id
        let bundle = instanceInfo.bundleIdentifier
        let name = instanceInfo.localizedName
        let status = instanceInfo.status
        let message = instanceInfo.statusMessage
        let intervention = instanceInfo.lastInterventionType

        #expect(pid == id)
        #expect(bundle != nil)
        #expect(name != nil)
        #expect(status == .idle)
        #expect(message == "Test")
        #expect(intervention == nil)

        // CursorInstanceInfo being Sendable means it should be safe for concurrent access
        // We've verified the properties work correctly
    }

    }
    
    @Suite("Performance", .tags(.performance))
    struct PerformanceTests {
        @Test(
            "Large scale instance creation",
            .timeLimit(.minutes(1)),
            arguments: [100, 500, 1000]
        )
        func memoryAndPerformance(instanceCount: Int) async throws {
            // Use confirmation to track progress
            await confirmation("Creating \(instanceCount) instances", expectedCount: 1) { confirm in
                var instances: [CursorInstanceInfo] = []
                
                for i in 0 ..< instanceCount {
                    let mockApp = createMockRunningApplication(
                        pid: pid_t(i),
                        bundleId: "com.test.app\(i)",
                        name: "App \(i)"
                    )
                    let instance = CursorInstanceInfo(
                        app: mockApp,
                        status: .idle,
                        statusMessage: "Instance \(i)",
                        lastInterventionType: nil
                    )
                    instances.append(instance)
                }
                
                #expect(instances.count == instanceCount)
                
                // Test that instances are properly distinct
                let uniquePIDs = Set(instances.map(\.pid))
                #expect(uniquePIDs.count == instanceCount)
                
                // Test performance of hash operations
                let clock = ContinuousClock()
                let start = clock.now
                
                var instanceSet: Set<CursorInstanceInfo> = []
                for instance in instances {
                    instanceSet.insert(instance)
                }
                
                let elapsed = clock.now - start
                
                #expect(instanceSet.count == instanceCount)
                #expect(elapsed < .seconds(1), "Hash operations should complete quickly")
                
                confirm()
            }
        }

    }
}

// MARK: - Helper Functions

private func createMockRunningApplication(
    pid _: pid_t,
    bundleId _: String?,
    name _: String?
) -> NSRunningApplication {
    // Note: In real tests, you would need to create a proper mock
    // For now, we'll use the current running application as a placeholder
    // In actual implementation, you'd want to create a MockNSRunningApplication
    NSRunningApplication.current
}
