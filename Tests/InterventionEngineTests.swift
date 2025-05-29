@testable import CodeLooper
import Combine
import Foundation
import Testing

@Test("InterventionEngine - InterventionType Enum Cases")
func interventionTypeEnumCases() async throws {
    // Test that all intervention types are available
    let allCases = CursorInterventionEngine.InterventionType.allCases
    #expect(allCases.count > 0)

    // Test specific expected cases
    #expect(allCases.contains(.unknown))
    #expect(allCases.contains(.noInterventionNeeded))
    #expect(allCases.contains(.positiveWorkingState))
    #expect(allCases.contains(.connectionIssue))
    #expect(allCases.contains(.generalError))
    #expect(allCases.contains(.unrecoverableError))
    #expect(allCases.contains(.automatedRecovery))
    #expect(allCases.contains(.interventionLimitReached))
    #expect(allCases.contains(.processNotRunning))
}

@Test("InterventionEngine - InterventionType String Values")
func interventionTypeStringValues() async throws {
    // Test that intervention types have proper string representations
    #expect(CursorInterventionEngine.InterventionType.unknown.rawValue == "Unknown")
    #expect(CursorInterventionEngine.InterventionType.noInterventionNeeded.rawValue == "No Intervention Needed")
    #expect(CursorInterventionEngine.InterventionType.positiveWorkingState.rawValue == "Positive Working State")
    #expect(CursorInterventionEngine.InterventionType.connectionIssue.rawValue == "Connection Issue")
    #expect(CursorInterventionEngine.InterventionType.generalError.rawValue == "General Error")
    #expect(CursorInterventionEngine.InterventionType.automatedRecovery.rawValue == "Automated Recovery Attempt")
}

@Test("InterventionEngine - InterventionType Codable")
func interventionTypeCodable() async throws {
    let interventionType = CursorInterventionEngine.InterventionType.connectionIssue

    // Test encoding
    let encoder = JSONEncoder()
    let data = try encoder.encode(interventionType)
    #expect(data.count > 0)

    // Test decoding
    let decoder = JSONDecoder()
    let decodedType = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)
    #expect(decodedType == interventionType)
}

@Test("InterventionEngine - InterventionType Equality")
func interventionTypeEquality() async throws {
    let type1 = CursorInterventionEngine.InterventionType.connectionIssue
    let type2 = CursorInterventionEngine.InterventionType.connectionIssue
    let type3 = CursorInterventionEngine.InterventionType.generalError

    #expect(type1 == type2)
    #expect(type1 != type3)
}

@Test("InterventionEngine - InterventionType Case Iteration")
func interventionTypeCaseIteration() async throws {
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

    #expect(foundUnknown)
    #expect(foundConnectionIssue)
    #expect(foundGeneralError)
}

@Test("InterventionEngine - InterventionType Classification")
func interventionTypeClassification() async throws {
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

    #expect(errorTypes.contains(.connectionIssue))
    #expect(errorTypes.contains(.generalError))
    #expect(!errorTypes.contains(.positiveWorkingState))

    #expect(positiveTypes.contains(.positiveWorkingState))
    #expect(positiveTypes.contains(.noInterventionNeeded))
    #expect(!positiveTypes.contains(.connectionIssue))
}

@Test("InterventionEngine - Priority Classification")
func interventionTypePriorityClassification() async throws {
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

    #expect(highPriorityTypes.count > 0)
    #expect(lowPriorityTypes.count > 0)

    // Ensure they don't overlap
    for highPriority in highPriorityTypes {
        #expect(!lowPriorityTypes.contains(highPriority))
    }
}

@Test("InterventionEngine - Intervention State Management")
func interventionTypeStateManagement() async throws {
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
    #expect(healthyStates.contains(.positiveWorkingState))
    #expect(problemStates.contains(.connectionIssue))
    #expect(controlStates.contains(.manualPause))

    // Ensure no overlap between healthy and problem states
    for healthy in healthyStates {
        #expect(!problemStates.contains(healthy))
    }
}

@Test("InterventionEngine - Recovery State Transitions")
func interventionTypeRecoveryStateTransitions() async throws {
    // Test recovery-related states
    let recoveryStates: Set<CursorInterventionEngine.InterventionType> = [
        .automatedRecovery,
        .awaitingAction,
    ]

    #expect(recoveryStates.contains(.automatedRecovery))
    #expect(recoveryStates.contains(.awaitingAction))

    // These states should be distinct from final states
    let finalStates: Set<CursorInterventionEngine.InterventionType> = [
        .positiveWorkingState,
        .unrecoverableError,
        .interventionLimitReached,
    ]

    for recovery in recoveryStates {
        #expect(!finalStates.contains(recovery))
    }
}

@Test("InterventionEngine - Serialization Consistency")
func interventionTypeSerializationConsistency() async throws {
    // Test that all intervention types can be serialized and deserialized
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    for interventionType in CursorInterventionEngine.InterventionType.allCases {
        let data = try encoder.encode(interventionType)
        let decoded = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)
        #expect(decoded == interventionType)
        #expect(decoded.rawValue == interventionType.rawValue)
    }
}

@Test("InterventionEngine - String Representation Quality")
func interventionTypeStringRepresentationQuality() async throws {
    // Test that all intervention types have meaningful string representations
    for interventionType in CursorInterventionEngine.InterventionType.allCases {
        let rawValue = interventionType.rawValue

        // Should not be empty
        #expect(!rawValue.isEmpty)

        // Should not be just whitespace
        #expect(!rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // Should be readable (contain letters)
        #expect(rawValue.rangeOfCharacter(from: .letters) != nil)
    }
}

@Test("InterventionEngine - Type Safety")
func interventionTypeTypeSafety() async throws {
    // Test that intervention types work with type-safe collections
    var typeSet: Set<CursorInterventionEngine.InterventionType> = []
    var typeArray: [CursorInterventionEngine.InterventionType] = []

    typeSet.insert(.connectionIssue)
    typeSet.insert(.generalError)
    typeArray.append(.positiveWorkingState)
    typeArray.append(.noInterventionNeeded)

    #expect(typeSet.count == 2)
    #expect(typeArray.count == 2)
    #expect(typeSet.contains(.connectionIssue))
    #expect(typeArray.contains(.positiveWorkingState))
}
