import AppKit
@testable import CodeLooper
import Foundation
import Testing

@Test("ProcessMonitoring - RecoveryType Enum Cases")
func recoveryTypeEnumCases() async throws {
    // Test that all recovery types are available
    let allCases = RecoveryType.allCases
    #expect(allCases.count == 4)

    // Test specific expected cases
    #expect(allCases.contains(.connection))
    #expect(allCases.contains(.stopGenerating))
    #expect(allCases.contains(.stuck))
    #expect(allCases.contains(.forceStop))
}

@Test("ProcessMonitoring - RecoveryType String Values")
func recoveryTypeStringValues() async throws {
    #expect(RecoveryType.connection.rawValue == "connection")
    #expect(RecoveryType.stopGenerating.rawValue == "stopGenerating")
    #expect(RecoveryType.stuck.rawValue == "stuck")
    #expect(RecoveryType.forceStop.rawValue == "forceStop")
}

@Test("ProcessMonitoring - RecoveryType Codable")
func recoveryTypeCodable() async throws {
    let recoveryType = RecoveryType.connection

    // Test encoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(recoveryType)
    #expect(data.count > 0)

    // Test decoding
    let decoder = JSONDecoder()
    let decodedType = try decoder.decode(RecoveryType.self, from: data)
    #expect(decodedType == recoveryType)
}

@Test("ProcessMonitoring - RecoveryType Hashable")
func recoveryTypeHashable() async throws {
    var recoverySet: Set<RecoveryType> = []

    recoverySet.insert(.connection)
    recoverySet.insert(.stopGenerating)
    recoverySet.insert(.connection) // Duplicate

    #expect(recoverySet.count == 2) // Should contain only unique values
    #expect(recoverySet.contains(.connection))
    #expect(recoverySet.contains(.stopGenerating))
}

@Test("ProcessMonitoring - CursorInstanceStatus Unknown")
func cursorInstanceStatusUnknown() async throws {
    let status = CursorInstanceStatus.unknown
    #expect(status == .unknown)

    // Test equality
    let anotherUnknown = CursorInstanceStatus.unknown
    #expect(status == anotherUnknown)
}

@Test("ProcessMonitoring - CursorInstanceStatus Working")
func cursorInstanceStatusWorking() async throws {
    let status1 = CursorInstanceStatus.working(detail: "Generating")
    let status2 = CursorInstanceStatus.working(detail: "Generating")
    let status3 = CursorInstanceStatus.working(detail: "Different detail")

    // Test equality
    #expect(status1 == status2)
    #expect(status1 != status3)

    // Test different working states
    let generating = CursorInstanceStatus.working(detail: "Generating")
    let sidebarActivity = CursorInstanceStatus.working(detail: "Recent Sidebar Activity")
    #expect(generating != sidebarActivity)
}

@Test("ProcessMonitoring - CursorInstanceStatus Idle")
func cursorInstanceStatusIdle() async throws {
    let status = CursorInstanceStatus.idle
    #expect(status == .idle)

    // Test that idle is different from other states
    #expect(status != .unknown)
    #expect(status != .working(detail: "test"))
}

@Test("ProcessMonitoring - CursorInstanceStatus Recovering")
func cursorInstanceStatusRecovering() async throws {
    let status1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let status2 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let status3 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
    let status4 = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)

    // Test equality
    #expect(status1 == status2)
    #expect(status1 != status3) // Different attempt
    #expect(status1 != status4) // Different type

    // Test all recovery types in recovering state
    let connectionRecovery = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let stopGeneratingRecovery = CursorInstanceStatus.recovering(type: .stopGenerating, attempt: 1)
    let stuckRecovery = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)
    let forceStopRecovery = CursorInstanceStatus.recovering(type: .forceStop, attempt: 1)

    #expect(connectionRecovery != stopGeneratingRecovery)
    #expect(stuckRecovery != forceStopRecovery)
}

@Test("ProcessMonitoring - CursorInstanceStatus Error")
func cursorInstanceStatusError() async throws {
    let status1 = CursorInstanceStatus.error(reason: "Connection failed")
    let status2 = CursorInstanceStatus.error(reason: "Connection failed")
    let status3 = CursorInstanceStatus.error(reason: "Different error")

    // Test equality
    #expect(status1 == status2)
    #expect(status1 != status3)

    // Test that error is different from unrecoverable
    let errorStatus = CursorInstanceStatus.error(reason: "Test error")
    let unrecoverableStatus = CursorInstanceStatus.unrecoverable(reason: "Test error")
    #expect(errorStatus != unrecoverableStatus)
}

@Test("ProcessMonitoring - CursorInstanceStatus Unrecoverable")
func cursorInstanceStatusUnrecoverable() async throws {
    let status1 = CursorInstanceStatus.unrecoverable(reason: "Complete failure")
    let status2 = CursorInstanceStatus.unrecoverable(reason: "Complete failure")
    let status3 = CursorInstanceStatus.unrecoverable(reason: "Different failure")

    // Test equality
    #expect(status1 == status2)
    #expect(status1 != status3)
}

@Test("ProcessMonitoring - CursorInstanceStatus Paused")
func cursorInstanceStatusPaused() async throws {
    let status = CursorInstanceStatus.paused
    #expect(status == .paused)

    // Test that paused is unique
    #expect(status != .unknown)
    #expect(status != .idle)
    #expect(status != .error(reason: "test"))
}

@Test("ProcessMonitoring - CursorInstanceStatus Hashable")
func cursorInstanceStatusHashable() async throws {
    var statusSet: Set<CursorInstanceStatus> = []

    // Add different statuses
    statusSet.insert(.unknown)
    statusSet.insert(.idle)
    statusSet.insert(.paused)
    statusSet.insert(.working(detail: "test"))
    statusSet.insert(.working(detail: "test")) // Duplicate
    statusSet.insert(.working(detail: "different"))
    statusSet.insert(.error(reason: "test error"))
    statusSet.insert(.recovering(type: .connection, attempt: 1))

    // Should contain unique statuses only
    #expect(statusSet.count == 7) // No duplicates
    #expect(statusSet.contains(.unknown))
    #expect(statusSet.contains(.idle))
    #expect(statusSet.contains(.working(detail: "test")))
}

@Test("ProcessMonitoring - CursorInstanceStatus State Transitions")
func cursorInstanceStatusStateTransitions() async throws {
    // Test logical state transitions
    let initialStatus = CursorInstanceStatus.unknown
    let workingStatus = CursorInstanceStatus.working(detail: "Generating")
    let recoveringStatus = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let errorStatus = CursorInstanceStatus.error(reason: "Connection lost")
    let unrecoverableStatus = CursorInstanceStatus.unrecoverable(reason: "Fatal error")

    // These should all be different states
    #expect(initialStatus != workingStatus)
    #expect(workingStatus != recoveringStatus)
    #expect(recoveringStatus != errorStatus)
    #expect(errorStatus != unrecoverableStatus)

    // Test progression through recovery attempts
    let recovery1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
    let recovery2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
    let recovery3 = CursorInstanceStatus.recovering(type: .connection, attempt: 3)

    #expect(recovery1 != recovery2)
    #expect(recovery2 != recovery3)
    #expect(recovery1 != recovery3)
}

@Test("ProcessMonitoring - Recovery Type Priority")
func recoveryTypePriority() async throws {
    // Test that different recovery types can be prioritized
    let recoveryTypes = RecoveryType.allCases

    // Connection issues are typically high priority
    #expect(recoveryTypes.contains(.connection))

    // Force stop is typically for severe issues
    #expect(recoveryTypes.contains(.forceStop))

    // Stuck and stop generating are intermediate
    #expect(recoveryTypes.contains(.stuck))
    #expect(recoveryTypes.contains(.stopGenerating))
}

@Test("ProcessMonitoring - Status Error vs Unrecoverable")
func statusErrorVsUnrecoverable() async throws {
    // Test distinction between recoverable errors and unrecoverable ones
    let recoverableError = CursorInstanceStatus.error(reason: "Temporary connection issue")
    let unrecoverableError = CursorInstanceStatus.unrecoverable(reason: "Process crashed")

    #expect(recoverableError != unrecoverableError)

    // Test that both can have the same reason but different types
    let error1 = CursorInstanceStatus.error(reason: "Same reason")
    let error2 = CursorInstanceStatus.unrecoverable(reason: "Same reason")
    #expect(error1 != error2)
}

@Test("ProcessMonitoring - Status Working Detail Variations")
func statusWorkingDetailVariations() async throws {
    // Test various working detail strings
    let detailVariations = [
        "Generating",
        "Recent Sidebar Activity",
        "Processing request",
        "Analyzing code",
        "Waiting for response",
    ]

    var workingStatuses: [CursorInstanceStatus] = []
    for detail in detailVariations {
        workingStatuses.append(.working(detail: detail))
    }

    // All should be different
    for i in 0 ..< workingStatuses.count {
        for j in (i + 1) ..< workingStatuses.count {
            #expect(workingStatuses[i] != workingStatuses[j])
        }
    }
}

@Test("ProcessMonitoring - Recovery Attempt Progression")
func recoveryAttemptProgression() async throws {
    // Test recovery attempt counting
    var recoveryAttempts: [CursorInstanceStatus] = []

    for attempt in 1 ... 5 {
        recoveryAttempts.append(.recovering(type: .connection, attempt: attempt))
    }

    // All attempts should be different
    for i in 0 ..< recoveryAttempts.count {
        for j in (i + 1) ..< recoveryAttempts.count {
            #expect(recoveryAttempts[i] != recoveryAttempts[j])
        }
    }

    // Test specific attempt numbers
    let attempt1 = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)
    let attempt5 = CursorInstanceStatus.recovering(type: .stuck, attempt: 5)
    #expect(attempt1 != attempt5)
}

@Test("ProcessMonitoring - Status Type Safety")
func statusTypeSafety() async throws {
    // Test that the status enum works with type-safe collections
    let statuses: [CursorInstanceStatus] = [
        .unknown,
        .working(detail: "test"),
        .idle,
        .recovering(type: .connection, attempt: 1),
        .error(reason: "test"),
        .unrecoverable(reason: "test"),
        .paused,
    ]

    #expect(statuses.count == 7)

    // Test filtering by status type
    let workingStatuses = statuses.compactMap { status in
        if case .working = status { return status }
        return nil
    }
    #expect(workingStatuses.count == 1)

    let recoveringStatuses = statuses.compactMap { status in
        if case .recovering = status { return status }
        return nil
    }
    #expect(recoveringStatuses.count == 1)
}
