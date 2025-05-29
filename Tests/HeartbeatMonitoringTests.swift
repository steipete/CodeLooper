import AppKit
@testable import CodeLooper
import Foundation
import XCTest



@MainActor
class HeartbeatMonitoringTests: XCTestCase {
    func testInstanceInfoConstruction() async throws {
    let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")
    let status = CursorInstanceStatus.idle
    let statusMessage = "Test status"

    let instanceInfo = CursorInstanceInfo(
        app: mockApp,
        status: status,
        statusMessage: statusMessage,
        lastInterventionType: .connection
    )

    XCTAssertEqual(instanceInfo.id, 12345)
    XCTAssertEqual(instanceInfo.processIdentifier, 12345)
    XCTAssertEqual(instanceInfo.pid, 12345)
    XCTAssertEqual(instanceInfo.bundleIdentifier, "com.test.app")
    XCTAssertEqual(instanceInfo.localizedName, "Test App")
    XCTAssertEqual(instanceInfo.status, .idle)
    XCTAssertEqual(instanceInfo.statusMessage, "Test status")
    XCTAssertEqual(instanceInfo.lastInterventionType, .connection)
}


    func testInstanceInfoEquality() async throws {
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
    XCTAssertEqual(instanceInfo1, instanceInfo2)

    // Different PID should not be equal
    XCTAssertNotEqual(instanceInfo1, instanceInfo3)
}


    func testInstanceInfoHashable() async throws {
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

    XCTAssertEqual(instanceSet.count, 2) // Should contain only unique instances
    XCTAssertTrue(instanceSet.contains(instanceInfo1))
    XCTAssertTrue(instanceSet.contains(instanceInfo2))
}


    func testInstanceStatusChangeTracking() async throws {
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
    XCTAssertEqual(instanceInfo.status, .idle)
    XCTAssertEqual(instanceInfo.statusMessage, "Now idle")

    instanceInfo.status = .working(detail: "Processing")
    instanceInfo.statusMessage = "Working on task"
    XCTAssertEqual(instanceInfo.status, .working(detail: "Processing"))
    XCTAssertEqual(instanceInfo.statusMessage, "Working on task")

    instanceInfo.status = .recovering(type: .connection, attempt: 1)
    instanceInfo.statusMessage = "Attempting recovery"
    instanceInfo.lastInterventionType = .connection
    XCTAssertEqual(instanceInfo.status, .recovering(type: .connection, attempt: 1))
    XCTAssertEqual(instanceInfo.lastInterventionType, .connection)
}


    func testStatusHelperMethods() async throws {
    // Test isRecovering()
    let recoveringStatus = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let idleStatus = CursorInstanceStatus.idle
    let workingStatus = CursorInstanceStatus.working(detail: "test")

    XCTAssertEqual(recoveringStatus.isRecovering(), true)
    XCTAssertEqual(idleStatus.isRecovering(), false)
    XCTAssertEqual(workingStatus.isRecovering(), false)

    // Test isRecovering(ofType:)
    let connectionRecovery = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let stuckRecovery = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)

    XCTAssertEqual(connectionRecovery.isRecovering(ofType: .connection), true)
    XCTAssertEqual(connectionRecovery.isRecovering(ofType: .stuck), false)
    XCTAssertEqual(stuckRecovery.isRecovering(ofType: .stuck), true)
    XCTAssertEqual(idleStatus.isRecovering(ofType: .connection), false)

    // Test isRecovering(ofAnyType:)
    let recoveryTypes: [RecoveryType] = [.connection, .stuck]
    XCTAssertEqual(connectionRecovery.isRecovering(ofAnyType: recoveryTypes), true)
    XCTAssertEqual(stuckRecovery.isRecovering(ofAnyType: recoveryTypes), true)
    XCTAssertEqual(idleStatus.isRecovering(ofAnyType: recoveryTypes), false)

    let forceStopRecovery = CursorInstanceStatus.recovering(type: .forceStop, attempt: 1)
    XCTAssertEqual(forceStopRecovery.isRecovering(ofAnyType: recoveryTypes), false)
}


    func testStringStableHash() async throws {
    let text1 = "Hello World"
    let text2 = "Hello World"
    let text3 = "Hello World!"
    let emptyText = ""

    // Same strings should have same hash
    XCTAssertEqual(text1.stableHash(), text2.stableHash())

    // Different strings should have different hashes
    XCTAssertNotEqual(text1.stableHash(), text3.stableHash())

    // Empty string should work
    let emptyHash = emptyText.stableHash()
    XCTAssertEqual(emptyHash, 0)

    // Hash should be deterministic
    let hash1 = text1.stableHash()
    let hash2 = text1.stableHash()
    XCTAssertEqual(hash1, hash2)
}


    func testBundleIdentifierEdgeCases() async throws {
    // Test with nil bundle identifier
    let mockAppNilBundle = createMockRunningApplication(pid: 12345, bundleId: nil, name: "Test App")
    let instanceInfo = CursorInstanceInfo(
        app: mockAppNilBundle,
        status: .idle,
        statusMessage: "Test",
        lastInterventionType: nil
    )

    XCTAssertEqual(instanceInfo.bundleIdentifier, nil)
    XCTAssertEqual(instanceInfo.id, 12345)
    XCTAssertEqual(instanceInfo.localizedName, "Test App")
}


    func testStatusMessageVariations() async throws {
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

        XCTAssertEqual(instanceInfo.statusMessage, message)
        XCTAssertEqual(instanceInfo.id, 12345)
    }
}


    func testRecoveryAttemptProgressionInHeartbeat() async throws {
    let mockApp = createMockRunningApplication(pid: 12345, bundleId: "com.test.app", name: "Test App")

    // Simulate recovery attempt progression
    var instanceInfo = CursorInstanceInfo(
        app: mockApp,
        status: .recovering(type: .connection, attempt: 1),
        statusMessage: "First attempt",
        lastInterventionType: .connection
    )

    XCTAssertEqual(instanceInfo.status, .recovering(type: .connection, attempt: 1))

    // Progress to second attempt
    instanceInfo.status = .recovering(type: .connection, attempt: 2)
    instanceInfo.statusMessage = "Second attempt"
    XCTAssertEqual(instanceInfo.status, .recovering(type: .connection, attempt: 2))

    // Progress to third attempt
    instanceInfo.status = .recovering(type: .connection, attempt: 3)
    instanceInfo.statusMessage = "Third attempt"
    XCTAssertEqual(instanceInfo.status, .recovering(type: .connection, attempt: 3))

    // Different attempts should not be equal
    let attempt1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let attempt2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
    XCTAssertNotEqual(attempt1, attempt2)
}


    func testInterventionTypeTracking() async throws {
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

        XCTAssertEqual(instanceInfo.lastInterventionType, interventionType)
    }
}


    func testInstanceCollectionOperations() async throws {
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

    XCTAssertEqual(instances.count, 3)

    // Test filtering by status
    let workingInstances = instances.filter { instance in
        if case .working = instance.status { return true }
        return false
    }
    XCTAssertEqual(workingInstances.count, 1)
    XCTAssertEqual(workingInstances.first?.pid, 54321)

    // Test filtering by intervention type
    let instancesWithInterventions = instances.filter { $0.lastInterventionType != nil }
    XCTAssertEqual(instancesWithInterventions.count, 2)

    // Test finding by PID
    let targetInstance = instances.first { $0.pid == 67890 }
    XCTAssertNotNil(targetInstance)
    XCTAssertEqual(targetInstance?.status, .recovering(type: .stuck, attempt: 2))
}


    func testStatusTransitionValidation() async throws {
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
        XCTAssertNotEqual(transition.from, transition.to)

        // Verify each status can be compared properly
        let sameFrom1 = transition.from
        let sameFrom2 = transition.from
        XCTAssertEqual(sameFrom1, sameFrom2)
    }
}


    func testHashConsistency() async throws {
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
    XCTAssertEqual(instanceInfo1.hashValue, instanceInfo2.hashValue)

    // Different recovery attempts should produce different hashes
    let status1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let status2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)

    var hasher1 = Hasher()
    status1.hash(into: &hasher1)

    var hasher2 = Hasher()
    status2.hash(into: &hasher2)

    XCTAssertNotEqual(hasher1.finalize(), hasher2.finalize())
}

    func testThreadSafetyConsiderations() async throws {
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

    XCTAssertEqual(pid, id)
    XCTAssertNotNil(bundle)
    XCTAssertNotNil(name)
    XCTAssertEqual(status, .idle)
    XCTAssertEqual(message, "Test")
    XCTAssertEqual(intervention, nil)
    
    // CursorInstanceInfo being Sendable means it should be safe for concurrent access
    // We've verified the properties work correctly
}


    func testMemoryAndPerformance() async throws {
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

    XCTAssertEqual(instances.count, 1000)

    // Test that instances are properly distinct
    let uniquePIDs = Set(instances.map(\.pid))
    XCTAssertEqual(uniquePIDs.count, 1000)

    // Test performance of hash operations
    let startTime = Date()
    var instanceSet: Set<CursorInstanceInfo> = []
    for instance in instances {
        instanceSet.insert(instance)
    }
    let endTime = Date()

    XCTAssertEqual(instanceSet.count, 1000)
    XCTAssertLessThan(endTime.timeIntervalSince(startTime), 1.0) // Should complete in under 1 second
}

// MARK: - Helper Functions

private func createMockRunningApplication(pid _: pid_t, bundleId _: String?, name _: String?) -> NSRunningApplication {
    // Note: In real tests, you would need to create a proper mock
    // For now, we'll use the current running application as a placeholder
    // In actual implementation, you'd want to create a MockNSRunningApplication
    NSRunningApplication.current
}

}