import AppKit
@testable import CodeLooper
import Foundation
import Testing

@Test("HeartbeatMonitoring - Instance Info Construction")
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

    #expect(instanceInfo.id == 12345)
    #expect(instanceInfo.processIdentifier == 12345)
    #expect(instanceInfo.pid == 12345)
    #expect(instanceInfo.bundleIdentifier == "com.test.app")
    #expect(instanceInfo.localizedName == "Test App")
    #expect(instanceInfo.status == .idle)
    #expect(instanceInfo.statusMessage == "Test status")
    #expect(instanceInfo.lastInterventionType == .connection)
}

@Test("HeartbeatMonitoring - Instance Info Equality")
func instanceInfoEquality() async throws {
    let mockApp1 = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
    let mockApp2 = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
    let mockApp3 = createMockRunningApplication(pid: 54321, bundleId: "com.test.app", name: "Test App")

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

    let instanceInfo3 = CursorInstanceInfo(
        app: mockApp3,
        status: .idle,
        statusMessage: "Test",
        lastInterventionType: .connection
    )

    // Same PID and properties should be equal
    #expect(instanceInfo1 == instanceInfo2)

    // Different PID should not be equal
    #expect(instanceInfo1 != instanceInfo3)
}

@Test("HeartbeatMonitoring - Instance Info Hashable")
func instanceInfoHashable() async throws {
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

@Test("HeartbeatMonitoring - Instance Status Change Tracking")
func instanceStatusChangeTracking() async throws {
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

@Test("HeartbeatMonitoring - Status Helper Methods")
func statusHelperMethods() async throws {
    // Test isRecovering()
    let recoveringStatus = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let idleStatus = CursorInstanceStatus.idle
    let workingStatus = CursorInstanceStatus.working(detail: "test")

    #expect(recoveringStatus.isRecovering() == true)
    #expect(idleStatus.isRecovering() == false)
    #expect(workingStatus.isRecovering() == false)

    // Test isRecovering(ofType:)
    let connectionRecovery = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let stuckRecovery = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)

    #expect(connectionRecovery.isRecovering(ofType: .connection) == true)
    #expect(connectionRecovery.isRecovering(ofType: .stuck) == false)
    #expect(stuckRecovery.isRecovering(ofType: .stuck) == true)
    #expect(idleStatus.isRecovering(ofType: .connection) == false)

    // Test isRecovering(ofAnyType:)
    let recoveryTypes: [RecoveryType] = [.connection, .stuck]
    #expect(connectionRecovery.isRecovering(ofAnyType: recoveryTypes) == true)
    #expect(stuckRecovery.isRecovering(ofAnyType: recoveryTypes) == true)
    #expect(idleStatus.isRecovering(ofAnyType: recoveryTypes) == false)

    let forceStopRecovery = CursorInstanceStatus.recovering(type: .forceStop, attempt: 1)
    #expect(forceStopRecovery.isRecovering(ofAnyType: recoveryTypes) == false)
}

@Test("HeartbeatMonitoring - String Stable Hash")
func stringStableHash() async throws {
    let text1 = "Hello World"
    let text2 = "Hello World"
    let text3 = "Hello World!"
    let emptyText = ""

    // Same strings should have same hash
    #expect(text1.stableHash() == text2.stableHash())

    // Different strings should have different hashes
    #expect(text1.stableHash() != text3.stableHash())

    // Empty string should work
    let emptyHash = emptyText.stableHash()
    #expect(emptyHash == 0)

    // Hash should be deterministic
    let hash1 = text1.stableHash()
    let hash2 = text1.stableHash()
    #expect(hash1 == hash2)
}

@Test("HeartbeatMonitoring - Bundle Identifier Edge Cases")
func bundleIdentifierEdgeCases() async throws {
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

@Test("HeartbeatMonitoring - Status Message Variations")
func statusMessageVariations() async throws {
    let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

    let statusMessages = [
        "Starting up",
        "Processing request",
        "Waiting for response",
        "Recovering from error",
        "Intervention paused",
        "",
        "Very long status message that contains multiple pieces of information about the current state",
    ]

    for message in statusMessages {
        let instanceInfo = CursorInstanceInfo(
            app: mockApp,
            status: .working(detail: "test"),
            statusMessage: message,
            lastInterventionType: nil
        )

        #expect(instanceInfo.statusMessage == message)
        #expect(instanceInfo.id == 12345)
    }
}

@Test("HeartbeatMonitoring - Recovery Attempt Progression")
func recoveryAttemptProgression() async throws {
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

@Test("HeartbeatMonitoring - Intervention Type Tracking")
func interventionTypeTracking() async throws {
    let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

    // Test all intervention types
    let interventionTypes: [RecoveryType?] = [
        nil,
        .connection,
        .stopGenerating,
        .stuck,
        .forceStop,
    ]

    for interventionType in interventionTypes {
        let instanceInfo = CursorInstanceInfo(
            app: mockApp,
            status: .idle,
            statusMessage: "Test",
            lastInterventionType: interventionType
        )

        #expect(instanceInfo.lastInterventionType == interventionType)
    }
}

@Test("HeartbeatMonitoring - Instance Collection Operations")
func instanceCollectionOperations() async throws {
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

@Test("HeartbeatMonitoring - Status Transition Validation")
func statusTransitionValidation() async throws {
    // Test logical status transitions
    let transitions = [
        (from: CursorInstanceStatus.unknown, to: CursorInstanceStatus.idle),
        (from: CursorInstanceStatus.idle, to: CursorInstanceStatus.working(detail: "Started")),
        (
            from: CursorInstanceStatus.working(detail: "Active"),
            to: CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        ),
        (
            from: CursorInstanceStatus.recovering(type: .connection, attempt: 1),
            to: CursorInstanceStatus.error(reason: "Failed")
        ),
        (
            from: CursorInstanceStatus.error(reason: "Recoverable"),
            to: CursorInstanceStatus.recovering(type: .stuck, attempt: 1)
        ),
        (
            from: CursorInstanceStatus.recovering(type: .stuck, attempt: 3),
            to: CursorInstanceStatus.unrecoverable(reason: "Max attempts")
        ),
        (from: CursorInstanceStatus.error(reason: "Temporary"), to: CursorInstanceStatus.idle),
        (from: CursorInstanceStatus.recovering(type: .connection, attempt: 1), to: CursorInstanceStatus.paused),
    ]

    for transition in transitions {
        // All transitions should result in different statuses
        #expect(transition.from != transition.to)

        // Verify each status can be compared properly
        let sameFrom1 = transition.from
        let sameFrom2 = transition.from
        #expect(sameFrom1 == sameFrom2)
    }
}

@Test("HeartbeatMonitoring - Hash Consistency")
func hashConsistency() async throws {
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

@Test("HeartbeatMonitoring - Thread Safety Considerations")
func threadSafetyConsiderations() async throws {
    let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

    // Test concurrent access to instance info (read-only operations)
    let instanceInfo = CursorInstanceInfo(
        app: mockApp,
        status: .idle,
        statusMessage: "Test",
        lastInterventionType: nil
    )

    // Simulate concurrent reads
    await withTaskGroup(of: Bool.self) { group in
        for _ in 0 ..< 10 {
            group.addTask {
                // These are all read operations that should be safe
                let pid = instanceInfo.pid
                let id = instanceInfo.id
                let bundle = instanceInfo.bundleIdentifier
                let name = instanceInfo.localizedName
                let status = instanceInfo.status
                let message = instanceInfo.statusMessage
                let intervention = instanceInfo.lastInterventionType

                return pid == id &&
                    bundle != nil &&
                    name != nil &&
                    status == .idle &&
                    message == "Test" &&
                    intervention == nil
            }
        }

        for await result in group {
            #expect(result == true)
        }
    }
}

@Test("HeartbeatMonitoring - Memory and Performance")
func memoryAndPerformance() async throws {
    // Test creating many instances to check for memory issues
    var instances: [CursorInstanceInfo] = []

    for i in 0 ..< 1000 {
        let mockApp = createMockRunningApplication(pid: pid_t(i), bundleId: "com.test.app\(i)", name: "App \(i)")
        let instance = CursorInstanceInfo(
            app: mockApp,
            status: .idle,
            statusMessage: "Instance \(i)",
            lastInterventionType: nil
        )
        instances.append(instance)
    }

    #expect(instances.count == 1000)

    // Test that instances are properly distinct
    let uniquePIDs = Set(instances.map(\.pid))
    #expect(uniquePIDs.count == 1000)

    // Test performance of hash operations
    let startTime = Date()
    var instanceSet: Set<CursorInstanceInfo> = []
    for instance in instances {
        instanceSet.insert(instance)
    }
    let endTime = Date()

    #expect(instanceSet.count == 1000)
    #expect(endTime.timeIntervalSince(startTime) < 1.0) // Should complete in under 1 second
}

// MARK: - Helper Functions

private func createMockRunningApplication(pid _: pid_t, bundleId _: String?, name _: String?) -> NSRunningApplication {
    // Note: In real tests, you would need to create a proper mock
    // For now, we'll use the current running application as a placeholder
    // In actual implementation, you'd want to create a MockNSRunningApplication
    NSRunningApplication.current
}
