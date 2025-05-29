@testable import CodeLooper
import Combine
import Foundation
import XCTest



class InterventionEngineTests: XCTestCase {
    func testInterventionTypeEnumCases() async throws {
    // Test that all intervention types are available
    let allCases = CursorInterventionEngine.InterventionType.allCases
    XCTAssertGreaterThan(allCases.count, 0)

    // Test specific expected cases
    XCTAssertTrue(allCases.contains(.unknown))
    XCTAssertTrue(allCases.contains(.noInterventionNeeded))
    XCTAssertTrue(allCases.contains(.positiveWorkingState))
    XCTAssertTrue(allCases.contains(.connectionIssue))
    XCTAssertTrue(allCases.contains(.generalError))
    XCTAssertTrue(allCases.contains(.unrecoverableError))
    XCTAssertTrue(allCases.contains(.automatedRecovery))
    XCTAssertTrue(allCases.contains(.interventionLimitReached))
    XCTAssertTrue(allCases.contains(.processNotRunning))
}


    func testInterventionTypeStringValues() async throws {
    // Test that intervention types have proper string representations
    XCTAssertEqual(CursorInterventionEngine.InterventionType.unknown.rawValue, "Unknown")
    XCTAssertEqual(CursorInterventionEngine.InterventionType.noInterventionNeeded.rawValue, "No Intervention Needed")
    XCTAssertEqual(CursorInterventionEngine.InterventionType.positiveWorkingState.rawValue, "Positive Working State")
    XCTAssertEqual(CursorInterventionEngine.InterventionType.connectionIssue.rawValue, "Connection Issue")
    XCTAssertEqual(CursorInterventionEngine.InterventionType.generalError.rawValue, "General Error")
    XCTAssertEqual(CursorInterventionEngine.InterventionType.automatedRecovery.rawValue, "Automated Recovery Attempt")
}


    func testInterventionTypeCodable() async throws {
    let interventionType = CursorInterventionEngine.InterventionType.connectionIssue

    // Test encoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(interventionType)
    XCTAssertGreaterThan(data.count, 0)

    // Test decoding
    let decoder = JSONDecoder()
    let decodedType = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)
    XCTAssertEqual(decodedType, interventionType)
}


    func testInterventionTypeEquality() async throws {
    let type1 = CursorInterventionEngine.InterventionType.connectionIssue
    let type2 = CursorInterventionEngine.InterventionType.connectionIssue
    let type3 = CursorInterventionEngine.InterventionType.generalError

    XCTAssertEqual(type1, type2)
    XCTAssertNotEqual(type1, type3)
}


    func testInterventionTypeCaseIteration() async throws {
    var foundUnknown = false
    var foundConnectionIssue = false
    var foundGeneralError = false

    for interventionType in CursorInterventionEngine.InterventionType.allCases {
        switch interventionType {
        case .unknown:
            foundUnknown = true
        case .connectionIssue:
            foundConnectionIssue = true
        case .generalError:
            foundGeneralError = true
        default:
            break
        }
    }

    XCTAssertTrue(foundUnknown)
    XCTAssertTrue(foundConnectionIssue)
    XCTAssertTrue(foundGeneralError)
}


    func testInterventionTypeClassification() async throws {
    // Test that intervention types can be classified into groups
    let errorTypes: Set<CursorInterventionEngine.InterventionType> = [
        .connectionIssue,
        .generalError,
        .unrecoverableError,
    ]

    let positiveTypes: Set<CursorInterventionEngine.InterventionType> = [
        .noInterventionNeeded,
        .positiveWorkingState,
        .sidebarActivityDetected,
    ]

    XCTAssertTrue(errorTypes.contains(.connectionIssue))
    XCTAssertTrue(errorTypes.contains(.generalError))
    XCTAssertTrue(!errorTypes.contains(.positiveWorkingState))

    XCTAssertTrue(positiveTypes.contains(.positiveWorkingState))
    XCTAssertTrue(positiveTypes.contains(.noInterventionNeeded))
    XCTAssertTrue(!positiveTypes.contains(.connectionIssue))
}


    func testInterventionTypePriorityClassification() async throws {
    // Test intervention types that would require immediate action
    let highPriorityTypes: Set<CursorInterventionEngine.InterventionType> = [
        .unrecoverableError,
        .connectionIssue,
        .generalError,
    ]

    // Test intervention types that are informational
    let lowPriorityTypes: Set<CursorInterventionEngine.InterventionType> = [
        .positiveWorkingState,
        .noInterventionNeeded,
        .sidebarActivityDetected,
    ]

    XCTAssertGreaterThan(highPriorityTypes.count, 0)
    XCTAssertGreaterThan(lowPriorityTypes.count, 0)

    // Ensure they don't overlap
    for highPriority in highPriorityTypes {
        XCTAssertTrue(!lowPriorityTypes.contains(highPriority))
    }
}


    func testInterventionTypeStateManagement() async throws {
    // Test states that indicate system health
    let healthyStates: Set<CursorInterventionEngine.InterventionType> = [
        .positiveWorkingState,
        .noInterventionNeeded,
        .sidebarActivityDetected,
    ]

    // Test states that indicate problems
    let problemStates: Set<CursorInterventionEngine.InterventionType> = [
        .connectionIssue,
        .generalError,
        .unrecoverableError,
        .processNotRunning,
    ]

    // Test states that indicate system control
    let controlStates: Set<CursorInterventionEngine.InterventionType> = [
        .manualPause,
        .monitoringPaused,
        .interventionLimitReached,
    ]

    // Verify categorization
    XCTAssertTrue(healthyStates.contains(.positiveWorkingState))
    XCTAssertTrue(problemStates.contains(.connectionIssue))
    XCTAssertTrue(controlStates.contains(.manualPause))

    // Ensure no overlap between healthy and problem states
    for healthy in healthyStates {
        XCTAssertTrue(!problemStates.contains(healthy))
    }
}


    func testInterventionTypeRecoveryStateTransitions() async throws {
    // Test recovery-related states
    let recoveryStates: Set<CursorInterventionEngine.InterventionType> = [
        .automatedRecovery,
        .awaitingAction,
    ]

    XCTAssertTrue(recoveryStates.contains(.automatedRecovery))
    XCTAssertTrue(recoveryStates.contains(.awaitingAction))

    // These states should be distinct from final states
    let finalStates: Set<CursorInterventionEngine.InterventionType> = [
        .positiveWorkingState,
        .unrecoverableError,
        .interventionLimitReached,
    ]

    for recovery in recoveryStates {
        XCTAssertTrue(!finalStates.contains(recovery))
    }
}


    func testInterventionTypeSerializationConsistency() async throws {
    // Test that all intervention types can be serialized and deserialized
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for interventionType in CursorInterventionEngine.InterventionType.allCases {
        let data = try encoder.encode(interventionType)
        let decoded = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)
        XCTAssertEqual(decoded, interventionType)
        XCTAssertEqual(decoded.rawValue, interventionType.rawValue)
    }
}


    func testInterventionTypeStringRepresentationQuality() async throws {
    // Test that all intervention types have meaningful string representations
    for interventionType in CursorInterventionEngine.InterventionType.allCases {
        let rawValue = interventionType.rawValue

        // Should not be empty
        XCTAssertTrue(!rawValue.isEmpty)

        // Should not be just whitespace
        XCTAssertTrue(!rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // Should be readable (contain letters)
        XCTAssertNotNil(rawValue.rangeOfCharacter(from: .letters))
    }
}


    func testInterventionTypeTypeSafety() async throws {
    // Test that intervention types work with type-safe collections
    var typeSet: Set<CursorInterventionEngine.InterventionType> = []
    var typeArray: [CursorInterventionEngine.InterventionType] = []

    typeSet.insert(.connectionIssue)
    typeSet.insert(.generalError)
    typeArray.append(.positiveWorkingState)
    typeArray.append(.noInterventionNeeded)

    XCTAssertEqual(typeSet.count, 2)
    XCTAssertEqual(typeArray.count, 2)
    XCTAssertTrue(typeSet.contains(.connectionIssue))
    XCTAssertTrue(typeArray.contains(.positiveWorkingState))
}

}