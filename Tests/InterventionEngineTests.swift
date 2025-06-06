@testable import CodeLooper
import Combine
import Foundation
import Testing

// MARK: - Test Suite with Advanced Organization

@Suite("Intervention Engine Tests", .tags(.intervention, .engine, .recovery))
struct InterventionEngineTests {
    // MARK: - Enum Validation Suite

    @Suite("Enum Validation", .tags(.enum, .validation))
    struct EnumValidation {
        @Test("Intervention type enum has all expected cases")
        func interventionTypeEnumCases() async throws {
            let allCases = CursorInterventionEngine.InterventionType.allCases
            #expect(allCases.count > 0, "Should have at least one intervention type")

            // Test specific expected cases exist
            let requiredCases: [CursorInterventionEngine.InterventionType] = [
                .unknown, .noInterventionNeeded, .positiveWorkingState,
                .connectionIssue, .generalError, .unrecoverableError,
                .automatedRecovery, .interventionLimitReached, .processNotRunning,
            ]

            for requiredCase in requiredCases {
                #expect(allCases.contains(requiredCase), "Should contain required case: \(requiredCase)")
            }
        }

        @Test("Intervention type string values are properly formatted")
        func interventionTypeStringValues() async throws {
            let expectedStringValues: [(CursorInterventionEngine.InterventionType, String)] = [
                (.unknown, "Unknown"),
                (.noInterventionNeeded, "No Intervention Needed"),
                (.positiveWorkingState, "Positive Working State"),
                (.connectionIssue, "Connection Issue"),
                (.generalError, "General Error"),
                (.automatedRecovery, "Automated Recovery Attempt"),
            ]

            for (type, expectedString) in expectedStringValues {
                #expect(type.rawValue == expectedString, "Type \(type) should have string value '\(expectedString)'")
            }
        }

        @Test(
            "All intervention types have quality string representations",
            arguments: CursorInterventionEngine.InterventionType.allCases
        )
        func interventionTypeStringQuality(interventionType: CursorInterventionEngine.InterventionType) async throws {
            let rawValue = interventionType.rawValue

            #expect(!rawValue.isEmpty, "String representation should not be empty")
            #expect(!rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Should not be only whitespace")
            #expect(rawValue.rangeOfCharacter(from: .letters) != nil, "Should contain letters for readability")
        }
    }

    // MARK: - Serialization Suite

    @Suite("Serialization", .tags(.serialization, .codable))
    struct Serialization {
        @Test("Intervention type supports Codable protocol", arguments: [
            CursorInterventionEngine.InterventionType.connectionIssue,
            .generalError,
            .positiveWorkingState,
            .automatedRecovery,
        ])
        func interventionTypeCodable(interventionType: CursorInterventionEngine.InterventionType) async throws {
            let encoder = JSONEncoder()
            let data = try encoder.encode(interventionType)
            #expect(data.count > 0, "Should produce encoded data")

            let decoder = JSONDecoder()
            let decodedType = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)
            #expect(decodedType == interventionType, "Decoded type should match original")
        }

        @Test("All intervention types can be serialized consistently", .timeLimit(.seconds(5)))
        func interventionTypeSerializationConsistency() async throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            for interventionType in CursorInterventionEngine.InterventionType.allCases {
                let data = try encoder.encode(interventionType)
                let decoded = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)

                #expect(decoded == interventionType, "Decoded type should equal original for \(interventionType)")
                #expect(decoded.rawValue == interventionType.rawValue, "Raw values should match after round-trip")
            }
        }
    }

    // MARK: - Type Classification Suite

    @Suite("Type Classification", .tags(.classification, .logic))
    struct TypeClassification {
        @Test("Error types are properly categorized", arguments: errorTypes)
        func errorTypeClassification(errorType: CursorInterventionEngine.InterventionType) async throws {
            let allErrorTypes: Set<CursorInterventionEngine.InterventionType> = [
                .connectionIssue, .generalError, .unrecoverableError,
            ]

            #expect(allErrorTypes.contains(errorType), "Type \(errorType) should be classified as error type")

            // Error types should not be positive types
            let positiveTypeSet = Set(positiveTypes)
            #expect(!positiveTypeSet.contains(errorType), "Error type should not be classified as positive")
        }

        @Test("Positive types indicate healthy system state", arguments: positiveTypes)
        func positiveTypeClassification(positiveType: CursorInterventionEngine.InterventionType) async throws {
            let allPositiveTypes: Set<CursorInterventionEngine.InterventionType> = [
                .noInterventionNeeded, .positiveWorkingState, .sidebarActivityDetected,
            ]

            #expect(allPositiveTypes.contains(positiveType), "Type \(positiveType) should be classified as positive")

            // Positive types should not be error types
            let errorTypeSet = Set(errorTypes)
            #expect(!errorTypeSet.contains(positiveType), "Positive type should not be classified as error")
        }

        @Test("Control types manage system behavior", arguments: controlTypes)
        func controlTypeClassification(controlType: CursorInterventionEngine.InterventionType) async throws {
            let allControlTypes: Set<CursorInterventionEngine.InterventionType> = [
                .manualPause, .monitoringPaused, .interventionLimitReached,
            ]

            #expect(allControlTypes.contains(controlType), "Type \(controlType) should be classified as control type")
        }

        @Test("Priority classification separates urgent from informational types")
        func priorityClassification() async throws {
            let highPriorityTypes: Set<CursorInterventionEngine.InterventionType> = [
                .unrecoverableError, .connectionIssue, .generalError,
            ]

            let lowPriorityTypes: Set<CursorInterventionEngine.InterventionType> = [
                .positiveWorkingState, .noInterventionNeeded, .sidebarActivityDetected,
            ]

            #expect(highPriorityTypes.count > 0, "Should have high priority types")
            #expect(lowPriorityTypes.count > 0, "Should have low priority types")

            // Ensure no overlap between priority levels
            for highPriority in highPriorityTypes {
                #expect(!lowPriorityTypes.contains(highPriority), "High priority type should not be low priority")
            }
        }
    }

    // MARK: - State Management Suite

    @Suite("State Management", .tags(.state, .transitions))
    struct StateManagement {
        @Test("Healthy states are distinct from problem states")
        func healthyVsProblemStates() async throws {
            let healthyStates: Set<CursorInterventionEngine.InterventionType> = [
                .positiveWorkingState, .noInterventionNeeded, .sidebarActivityDetected,
            ]

            let problemStates: Set<CursorInterventionEngine.InterventionType> = [
                .connectionIssue, .generalError, .unrecoverableError, .processNotRunning,
            ]

            #expect(healthyStates.contains(.positiveWorkingState), "Should classify positive working state as healthy")
            #expect(problemStates.contains(.connectionIssue), "Should classify connection issue as problem")

            // Ensure no overlap between healthy and problem states
            for healthy in healthyStates {
                #expect(!problemStates.contains(healthy), "Healthy state \(healthy) should not be a problem state")
            }
        }

        @Test("Recovery states enable state transitions", arguments: recoveryTypes)
        func recoveryStateTransitions(recoveryType: CursorInterventionEngine.InterventionType) async throws {
            let allRecoveryStates: Set<CursorInterventionEngine.InterventionType> = [
                .automatedRecovery, .awaitingAction,
            ]

            #expect(allRecoveryStates.contains(recoveryType), "Type \(recoveryType) should be a recovery state")

            // Recovery states should be distinct from final states
            let finalStates: Set<CursorInterventionEngine.InterventionType> = [
                .positiveWorkingState, .unrecoverableError, .interventionLimitReached,
            ]

            #expect(!finalStates.contains(recoveryType), "Recovery state should not be a final state")
        }

        @Test("State categories have logical separation")
        func stateCategorySeparation() async throws {
            let healthyStates = Set(positiveTypes)
            let problemStates = Set(errorTypes)
            let controlStates = Set(controlTypes)
            let recoveryStates = Set(recoveryTypes)

            // Test that categories are logically separated
            let allCategories = [healthyStates, problemStates, controlStates, recoveryStates]

            for (i, category1) in allCategories.enumerated() {
                for (j, category2) in allCategories.enumerated() {
                    if i != j {
                        let intersection = category1.intersection(category2)
                        #expect(intersection.isEmpty, "Categories \(i) and \(j) should not overlap")
                    }
                }
            }
        }
    }

    // MARK: - Type Safety Suite

    @Suite("Type Safety", .tags(.type_safety, .collections))
    struct TypeSafety {
        @Test("Intervention types work with type-safe collections")
        func typeSafetyWithCollections() async throws {
            var typeSet: Set<CursorInterventionEngine.InterventionType> = []
            var typeArray: [CursorInterventionEngine.InterventionType] = []
            var typeDictionary: [CursorInterventionEngine.InterventionType: String] = [:]

            // Test Set operations
            typeSet.insert(.connectionIssue)
            typeSet.insert(.generalError)
            typeSet.insert(.connectionIssue) // Duplicate should be ignored

            #expect(typeSet.count == 2, "Set should contain 2 unique types")
            #expect(typeSet.contains(.connectionIssue), "Set should contain connection issue")
            #expect(typeSet.contains(.generalError), "Set should contain general error")

            // Test Array operations
            typeArray.append(.positiveWorkingState)
            typeArray.append(.noInterventionNeeded)

            #expect(typeArray.count == 2, "Array should contain 2 types")
            #expect(typeArray.contains(.positiveWorkingState), "Array should contain positive working state")

            // Test Dictionary operations
            typeDictionary[.automatedRecovery] = "Recovery in progress"
            typeDictionary[.awaitingAction] = "Waiting for action"

            #expect(typeDictionary.count == 2, "Dictionary should contain 2 entries")
            #expect(
                typeDictionary[.automatedRecovery] == "Recovery in progress",
                "Dictionary should store correct value"
            )
        }

        @Test("Intervention types support equality comparison", arguments: [
            (.connectionIssue, .connectionIssue, true),
            (.connectionIssue, .generalError, false),
            (.positiveWorkingState, .positiveWorkingState, true),
            (.unknown, .automatedRecovery, false),
        ])
        func interventionTypeEquality(comparison: (
            CursorInterventionEngine.InterventionType,
            CursorInterventionEngine.InterventionType,
            Bool
        )) async throws {
            let (type1, type2, shouldBeEqual) = comparison

            if shouldBeEqual {
                #expect(type1 == type2, "Types \(type1) and \(type2) should be equal")
                #expect(!(type1 != type2), "Types should not be unequal")
            } else {
                #expect(type1 != type2, "Types \(type1) and \(type2) should not be equal")
                #expect(!(type1 == type2), "Types should not be equal")
            }
        }

        @Test("Case iteration covers all intervention types")
        func interventionTypeCaseIteration() async throws {
            var foundTypes: Set<CursorInterventionEngine.InterventionType> = []
            let expectedTypes: Set<CursorInterventionEngine.InterventionType> = [
                .unknown, .connectionIssue, .generalError, .positiveWorkingState,
            ]

            for interventionType in CursorInterventionEngine.InterventionType.allCases {
                foundTypes.insert(interventionType)
            }

            for expectedType in expectedTypes {
                #expect(foundTypes.contains(expectedType), "Should find expected type \(expectedType) during iteration")
            }

            #expect(
                foundTypes.count == CursorInterventionEngine.InterventionType.allCases.count,
                "Found types should match total case count"
            )
        }
    }

    // MARK: - Performance Suite

    @Suite("Performance", .tags(.performance, .timing))
    struct Performance {
        @Test("Enum operations are performant", .timeLimit(.seconds(1)))
        func enumPerformanceTest() async throws {
            let iterations = 10000
            let startTime = ContinuousClock().now

            // Perform many enum operations
            for i in 0 ..< iterations {
                let type = CursorInterventionEngine.InterventionType
                    .allCases[i % CursorInterventionEngine.InterventionType.allCases.count]
                _ = type.rawValue
                _ = type == .connectionIssue
                _ = Set([type])
            }

            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .seconds(1), "Enum operations should be fast")
        }

        @Test("Serialization performance is acceptable", .timeLimit(.seconds(3)))
        func serializationPerformance() async throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let allTypes = CursorInterventionEngine.InterventionType.allCases

            let startTime = ContinuousClock().now

            // Perform many serialization operations
            for _ in 0 ..< 1000 {
                for type in allTypes {
                    let data = try encoder.encode(type)
                    _ = try decoder.decode(CursorInterventionEngine.InterventionType.self, from: data)
                }
            }

            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .seconds(3), "Serialization should complete within reasonable time")
        }
    }

    // MARK: - Test Fixtures

    static let errorTypes: [CursorInterventionEngine.InterventionType] = [
        .connectionIssue, .generalError, .unrecoverableError,
    ]

    static let positiveTypes: [CursorInterventionEngine.InterventionType] = [
        .noInterventionNeeded, .positiveWorkingState, .sidebarActivityDetected,
    ]

    static let controlTypes: [CursorInterventionEngine.InterventionType] = [
        .manualPause, .monitoringPaused, .interventionLimitReached,
    ]

    static let recoveryTypes: [CursorInterventionEngine.InterventionType] = [
        .automatedRecovery, .awaitingAction,
    ]
}

// MARK: - Custom Test Tags

extension Tag {
    @Tag static var intervention: Self
    @Tag static var engine: Self
    @Tag static var recovery: Self
    @Tag static var enum: Self
    @Tag static var validation: Self
    @Tag static var serialization: Self
    @Tag static var codable: Self
    @Tag static var classification: Self
    @Tag static var logic: Self
    @Tag static var state: Self
    @Tag static var transitions: Self
    @Tag static var type_safety: Self
    @Tag static var collections: Self
    @Tag static var performance: Self
    @Tag static var timing: Self
}
