import AppKit
@testable import CodeLooper
import Foundation
import XCTest

class ProcessMonitoringTests: XCTestCase {
    func testRecoveryTypeEnumCases() async throws {
        // Test that all recovery types are available
        let allCases = RecoveryType.allCases
        XCTAssertEqual(allCases.count, 4)

        // Test specific expected cases
        XCTAssertTrue(allCases.contains(.connection))
        XCTAssertTrue(allCases.contains(.stopGenerating))
        XCTAssertTrue(allCases.contains(.stuck))
        XCTAssertTrue(allCases.contains(.forceStop))
    }

    func testRecoveryTypeStringValues() async throws {
        XCTAssertEqual(RecoveryType.connection.rawValue, "connection")
        XCTAssertEqual(RecoveryType.stopGenerating.rawValue, "stopGenerating")
        XCTAssertEqual(RecoveryType.stuck.rawValue, "stuck")
        XCTAssertEqual(RecoveryType.forceStop.rawValue, "forceStop")
    }

    func testRecoveryTypeCodable() async throws {
        let recoveryType = RecoveryType.connection

        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(recoveryType)
        XCTAssertGreaterThan(data.count, 0)

        // Test decoding
        let decoder = JSONDecoder()
        let decodedType = try decoder.decode(RecoveryType.self, from: data)
        XCTAssertEqual(decodedType, recoveryType)
    }

    func testRecoveryTypeHashable() async throws {
        var recoverySet: Set<RecoveryType> = []

        recoverySet.insert(.connection)
        recoverySet.insert(.stopGenerating)
        recoverySet.insert(.connection) // Duplicate

        XCTAssertEqual(recoverySet.count, 2) // Should contain only unique values
        XCTAssertTrue(recoverySet.contains(.connection))
        XCTAssertTrue(recoverySet.contains(.stopGenerating))
    }

    func testCursorInstanceStatusUnknown() async throws {
        let status = CursorInstanceStatus.unknown
        XCTAssertEqual(status, .unknown)

        // Test equality
        let anotherUnknown = CursorInstanceStatus.unknown
        XCTAssertEqual(status, anotherUnknown)
    }

    func testCursorInstanceStatusWorking() async throws {
        let status1 = CursorInstanceStatus.working(detail: "Generating")
        let status2 = CursorInstanceStatus.working(detail: "Generating")
        let status3 = CursorInstanceStatus.working(detail: "Different detail")

        // Test equality
        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)

        // Test different working states
        let generating = CursorInstanceStatus.working(detail: "Generating")
        let sidebarActivity = CursorInstanceStatus.working(detail: "Recent Sidebar Activity")
        XCTAssertNotEqual(generating, sidebarActivity)
    }

    func testCursorInstanceStatusIdle() async throws {
        let status = CursorInstanceStatus.idle
        XCTAssertEqual(status, .idle)

        // Test that idle is different from other states
        XCTAssertNotEqual(status, .unknown)
        XCTAssertNotEqual(status, .working(detail: "test"))
    }

    func testCursorInstanceStatusRecovering() async throws {
        let status1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let status2 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let status3 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
        let status4 = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)

        // Test equality
        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3) // Different attempt
        XCTAssertNotEqual(status1, status4) // Different type

        // Test all recovery types in recovering state
        let connectionRecovery = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let stopGeneratingRecovery = CursorInstanceStatus.recovering(type: .stopGenerating, attempt: 1)
        let stuckRecovery = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)
        let forceStopRecovery = CursorInstanceStatus.recovering(type: .forceStop, attempt: 1)

        XCTAssertNotEqual(connectionRecovery, stopGeneratingRecovery)
        XCTAssertNotEqual(stuckRecovery, forceStopRecovery)
    }

    func testCursorInstanceStatusError() async throws {
        let status1 = CursorInstanceStatus.error(reason: "Connection failed")
        let status2 = CursorInstanceStatus.error(reason: "Connection failed")
        let status3 = CursorInstanceStatus.error(reason: "Different error")

        // Test equality
        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)

        // Test that error is different from unrecoverable
        let errorStatus = CursorInstanceStatus.error(reason: "Test error")
        let unrecoverableStatus = CursorInstanceStatus.unrecoverable(reason: "Test error")
        XCTAssertNotEqual(errorStatus, unrecoverableStatus)
    }

    func testCursorInstanceStatusUnrecoverable() async throws {
        let status1 = CursorInstanceStatus.unrecoverable(reason: "Complete failure")
        let status2 = CursorInstanceStatus.unrecoverable(reason: "Complete failure")
        let status3 = CursorInstanceStatus.unrecoverable(reason: "Different failure")

        // Test equality
        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)
    }

    func testCursorInstanceStatusPaused() async throws {
        let status = CursorInstanceStatus.paused
        XCTAssertEqual(status, .paused)

        // Test that paused is unique
        XCTAssertNotEqual(status, .unknown)
        XCTAssertNotEqual(status, .idle)
        XCTAssertNotEqual(status, .error(reason: "test"))
    }

    func testCursorInstanceStatusHashable() async throws {
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
        XCTAssertEqual(statusSet.count, 7) // No duplicates
        XCTAssertTrue(statusSet.contains(.unknown))
        XCTAssertTrue(statusSet.contains(.idle))
        XCTAssertTrue(statusSet.contains(.working(detail: "test")))
    }

    func testCursorInstanceStatusStateTransitions() async throws {
        // Test logical state transitions
        let initialStatus = CursorInstanceStatus.unknown
        let workingStatus = CursorInstanceStatus.working(detail: "Generating")
        let recoveringStatus = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let errorStatus = CursorInstanceStatus.error(reason: "Connection lost")
        let unrecoverableStatus = CursorInstanceStatus.unrecoverable(reason: "Fatal error")

        // These should all be different states
        XCTAssertNotEqual(initialStatus, workingStatus)
        XCTAssertNotEqual(workingStatus, recoveringStatus)
        XCTAssertNotEqual(recoveringStatus, errorStatus)
        XCTAssertNotEqual(errorStatus, unrecoverableStatus)

        // Test progression through recovery attempts
        let recovery1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
        let recovery2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
        let recovery3 = CursorInstanceStatus.recovering(type: .connection, attempt: 3)

        XCTAssertNotEqual(recovery1, recovery2)
        XCTAssertNotEqual(recovery2, recovery3)
        XCTAssertNotEqual(recovery1, recovery3)
    }

    func testRecoveryTypePriority() async throws {
        // Test that different recovery types can be prioritized
        let recoveryTypes = RecoveryType.allCases

        // Connection issues are typically high priority
        XCTAssertTrue(recoveryTypes.contains(.connection))

        // Force stop is typically for severe issues
        XCTAssertTrue(recoveryTypes.contains(.forceStop))

        // Stuck and stop generating are intermediate
        XCTAssertTrue(recoveryTypes.contains(.stuck))
        XCTAssertTrue(recoveryTypes.contains(.stopGenerating))
    }

    func testStatusErrorVsUnrecoverable() async throws {
        // Test distinction between recoverable errors and unrecoverable ones
        let recoverableError = CursorInstanceStatus.error(reason: "Temporary connection issue")
        let unrecoverableError = CursorInstanceStatus.unrecoverable(reason: "Process crashed")

        XCTAssertNotEqual(recoverableError, unrecoverableError)

        // Test that both can have the same reason but different types
        let error1 = CursorInstanceStatus.error(reason: "Same reason")
        let error2 = CursorInstanceStatus.unrecoverable(reason: "Same reason")
        XCTAssertNotEqual(error1, error2)
    }

    func testStatusWorkingDetailVariations() async throws {
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
                XCTAssertNotEqual(workingStatuses[i], workingStatuses[j])
            }
        }
    }

    func testRecoveryAttemptProgression() async throws {
        // Test recovery attempt counting
        var recoveryAttempts: [CursorInstanceStatus] = []

        for attempt in 1 ... 5 {
            recoveryAttempts.append(.recovering(type: .connection, attempt: attempt))
        }

        // All attempts should be different
        for i in 0 ..< recoveryAttempts.count {
            for j in (i + 1) ..< recoveryAttempts.count {
                XCTAssertNotEqual(recoveryAttempts[i], recoveryAttempts[j])
            }
        }

        // Test specific attempt numbers
        let attempt1 = CursorInstanceStatus.recovering(type: .stuck, attempt: 1)
        let attempt5 = CursorInstanceStatus.recovering(type: .stuck, attempt: 5)
        XCTAssertNotEqual(attempt1, attempt5)
    }

    func testStatusTypeSafety() async throws {
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

        XCTAssertEqual(statuses.count, 7)

        // Test filtering by status type
        let workingStatuses = statuses.compactMap { status in
            if case .working = status { return status }
            return nil
        }
        XCTAssertEqual(workingStatuses.count, 1)

        let recoveringStatuses = statuses.compactMap { status in
            if case .recovering = status { return status }
            return nil
        }
        XCTAssertEqual(recoveringStatuses.count, 1)
    }
}
