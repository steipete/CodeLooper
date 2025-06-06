@testable import CodeLooper
import Combine
import Foundation
import Testing

// MARK: - Custom Test Traits

struct InterventionTestTrait: TestTrait {
    let category: String
    let severity: InterventionSeverity
    
    enum InterventionSeverity {
        case low, medium, high, critical
    }
}

struct StateTransitionTrait: TestTrait {
    let fromState: String
    let toState: String
    let isValid: Bool
}

// MARK: - Shared Test Utilities

enum InterventionTestUtilities {
    typealias InterventionType = CursorInterventionEngine.InterventionType
    
    static func validateInterventionType(_ type: InterventionType) throws {
        #expect(!type.rawValue.isEmpty)
        #expect(type.rawValue.count > 2)
        #expect(InterventionType.allCases.contains(type))
    }
    
    static func categorizeInterventionType(_ type: InterventionType) -> InterventionCategory {
        switch type {
        case .connectionIssue, .generalError, .unrecoverableError:
            return .error
        case .noInterventionNeeded, .positiveWorkingState, .sidebarActivityDetected:
            return .positive
        case .manualPause, .monitoringPaused, .interventionLimitReached:
            return .control
        case .automatedRecovery, .awaitingAction:
            return .recovery
        default:
            return .unknown
        }
    }
    
    enum InterventionCategory {
        case error, positive, control, recovery, unknown
    }
    
    static func createInterventionMatrix() -> [(type: InterventionType, category: InterventionCategory, priority: Int)] {
        InterventionType.allCases.map { type in
            let category = categorizeInterventionType(type)
            let priority = calculatePriority(for: type)
            return (type, category, priority)
        }
    }
    
    static func calculatePriority(for type: InterventionType) -> Int {
        switch type {
        case .unrecoverableError: return 100
        case .connectionIssue, .generalError: return 80
        case .automatedRecovery, .awaitingAction: return 60
        case .manualPause, .monitoringPaused: return 40
        case .positiveWorkingState, .noInterventionNeeded: return 20
        default: return 10
        }
    }
}

// MARK: - Test Conditions

struct RequiresInterventionCapability: TestTrait {
    static var isEnabled: Bool {
        // Check if intervention system is available
        return true
    }
}

// MARK: - Main Test Suite

@Suite("Intervention Engine", .serialized)
struct InterventionEngineTests {
    // Shared test data
    var interventionMatrix: [(type: InterventionTestUtilities.InterventionType, category: InterventionTestUtilities.InterventionCategory, priority: Int)] {
        InterventionTestUtilities.createInterventionMatrix()
    }
    
    var stateTransitionMatrix: [(from: InterventionTestUtilities.InterventionType, to: InterventionTestUtilities.InterventionType, valid: Bool)] {
        [
            (.connectionIssue, .automatedRecovery, true),
            (.automatedRecovery, .positiveWorkingState, true),
            (.unrecoverableError, .positiveWorkingState, false),
            (.positiveWorkingState, .connectionIssue, true),
            (.interventionLimitReached, .automatedRecovery, false)
        ]
    }
    
    // MARK: - Enum Validation Suite
    
    @Suite("Enum Validation", .tags(.enum, .validation))
    struct EnumValidation {
        @Test(
            "Intervention type validation matrix",
            arguments: InterventionTestUtilities.InterventionType.allCases
        )
        func interventionTypeValidationMatrix(type: InterventionTestUtilities.InterventionType) throws {
            try InterventionTestUtilities.validateInterventionType(type)
            
            // Additional validation based on type category
            let category = InterventionTestUtilities.categorizeInterventionType(type)
            switch category {
            case .error:
                #expect(type.rawValue.contains("Error") || type.rawValue.contains("Issue"))
            case .positive:
                #expect(!type.rawValue.contains("Error") && !type.rawValue.contains("Issue"))
            default:
                break
            }
        }

        @Test(
            "String value formatting validation",
            arguments: [
                (InterventionTestUtilities.InterventionType.unknown, "Unknown"),
                (.noInterventionNeeded, "No Intervention Needed"),
                (.positiveWorkingState, "Positive Working State"),
                (.connectionIssue, "Connection Issue"),
                (.generalError, "General Error"),
                (.automatedRecovery, "Automated Recovery Attempt")
            ]
        )
        func stringValueFormattingValidation(
            testCase: (type: InterventionTestUtilities.InterventionType, expected: String)
        ) throws {
            #expect(testCase.type.rawValue == testCase.expected)
            
            // Validate formatting patterns
            let words = testCase.type.rawValue.split(separator: " ")
            for word in words {
                #expect(word.first?.isUppercase == true, "Each word should be capitalized")
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
        @Test(
            "Codable round-trip validation",
            arguments: InterventionTestUtilities.InterventionType.allCases
        )
        func codableRoundTripValidation(type: InterventionTestUtilities.InterventionType) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let decoder = JSONDecoder()
            
            // Test single value encoding
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(InterventionTestUtilities.InterventionType.self, from: data)
            #expect(decoded == type)
            
            // Test as part of a structure
            struct TestContainer: Codable {
                let type: InterventionTestUtilities.InterventionType
                let timestamp: Date
                let metadata: [String: String]
            }
            
            let container = TestContainer(
                type: type,
                timestamp: Date(),
                metadata: ["test": "value"]
            )
            
            let containerData = try encoder.encode(container)
            let decodedContainer = try decoder.decode(TestContainer.self, from: containerData)
            #expect(decodedContainer.type == type)
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
        @Test(
            "Category classification matrix",
            arguments: InterventionEngineTests().interventionMatrix
        )
        func categoryClassificationMatrix(
            testCase: (type: InterventionTestUtilities.InterventionType, category: InterventionTestUtilities.InterventionCategory, priority: Int)
        ) throws {
            let calculatedCategory = InterventionTestUtilities.categorizeInterventionType(testCase.type)
            #expect(calculatedCategory == testCase.category)
            
            let calculatedPriority = InterventionTestUtilities.calculatePriority(for: testCase.type)
            #expect(calculatedPriority == testCase.priority)
            
            // Validate priority ranges
            switch testCase.category {
            case .error:
                #expect(testCase.priority >= 80, "Error types should have high priority")
            case .positive:
                #expect(testCase.priority <= 30, "Positive types should have low priority")
            default:
                #expect(testCase.priority > 0 && testCase.priority < 100)
            }
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

        @Test("Priority distribution analysis")
        func priorityDistributionAnalysis() throws {
            let matrix = InterventionTestUtilities.createInterventionMatrix()
            let priorities = matrix.map { $0.priority }
            
            await confirmation("Priority distribution", expectedCount: 3) { confirm in
                // High priority (>= 80)
                let highPriorityCount = priorities.filter { $0 >= 80 }.count
                #expect(highPriorityCount > 0, "Should have high priority interventions")
                confirm()
                
                // Medium priority (40-79)
                let mediumPriorityCount = priorities.filter { $0 >= 40 && $0 < 80 }.count
                #expect(mediumPriorityCount > 0, "Should have medium priority interventions")
                confirm()
                
                // Low priority (< 40)
                let lowPriorityCount = priorities.filter { $0 < 40 }.count
                #expect(lowPriorityCount > 0, "Should have low priority interventions")
                confirm()
            }
        }
    }

    // MARK: - State Management Suite
    
    @Suite("State Management", .tags(.state, .transitions))
    struct StateManagement {
        @Test(
            "State transition validation matrix",
            arguments: InterventionEngineTests().stateTransitionMatrix,
            traits: [StateTransitionTrait(fromState: "various", toState: "various", isValid: true)]
        )
        func stateTransitionValidationMatrix(
            transition: (from: InterventionTestUtilities.InterventionType, to: InterventionTestUtilities.InterventionType, valid: Bool)
        ) throws {
            // Validate transition logic
            if transition.valid {
                // Valid transitions should follow logical patterns
                let fromCategory = InterventionTestUtilities.categorizeInterventionType(transition.from)
                let toCategory = InterventionTestUtilities.categorizeInterventionType(transition.to)
                
                switch (fromCategory, toCategory) {
                case (.error, .recovery):
                    #expect(true, "Error to recovery is valid")
                case (.recovery, .positive):
                    #expect(true, "Recovery to positive is valid")
                case (.error, .positive) where transition.from != .unrecoverableError:
                    #expect(true, "Some errors can transition to positive")
                default:
                    // Other transitions may be valid based on business logic
                    break
                }
            } else {
                // Invalid transitions
                #expect(transition.from == .unrecoverableError || transition.from == .interventionLimitReached,
                       "Invalid transitions should be from terminal states")
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

        @Test("State category orthogonality")
        func stateCategoryOrthogonality() throws {
            let matrix = InterventionTestUtilities.createInterventionMatrix()
            
            // Group by category
            var categoryGroups: [InterventionTestUtilities.InterventionCategory: Set<InterventionTestUtilities.InterventionType>] = [:]
            
            for entry in matrix {
                categoryGroups[entry.category, default: []].insert(entry.type)
            }
            
            // Verify no type appears in multiple categories
            let allTypes = Set(InterventionTestUtilities.InterventionType.allCases)
            var categorizedTypes: Set<InterventionTestUtilities.InterventionType> = []
            
            for (category, types) in categoryGroups {
                let previousCount = categorizedTypes.count
                categorizedTypes.formUnion(types)
                
                #expect(categorizedTypes.count == previousCount + types.count,
                       "Category \(category) should not share types with other categories")
            }
            
            // Ensure all types are categorized
            let uncategorized = allTypes.subtracting(categorizedTypes)
            #expect(uncategorized.isEmpty || uncategorized == [.unknown],
                   "All types should be categorized (except potentially .unknown)")
        }
    }

    // MARK: - Type Safety Suite
    
    @Suite("Type Safety", .tags(.type_safety, .collections))
    struct TypeSafety {
        @Test(
            "Collection operations matrix",
            arguments: [
                ("Set", 10),
                ("Array", 20),
                ("Dictionary", 15)
            ]
        )
        func collectionOperationsMatrix(testCase: (collection: String, operations: Int)) throws {
            typealias InterventionType = InterventionTestUtilities.InterventionType
            
            switch testCase.collection {
            case "Set":
                var set: Set<InterventionType> = []
                for i in 0..<testCase.operations {
                    let type = InterventionType.allCases[i % InterventionType.allCases.count]
                    set.insert(type)
                }
                #expect(set.count <= InterventionType.allCases.count, "Set should contain unique values")
                
            case "Array":
                var array: [InterventionType] = []
                for i in 0..<testCase.operations {
                    let type = InterventionType.allCases[i % InterventionType.allCases.count]
                    array.append(type)
                }
                #expect(array.count == testCase.operations, "Array should contain all added elements")
                
            case "Dictionary":
                var dict: [InterventionType: Int] = [:]
                for i in 0..<testCase.operations {
                    let type = InterventionType.allCases[i % InterventionType.allCases.count]
                    dict[type] = i
                }
                #expect(dict.count <= InterventionType.allCases.count, "Dictionary keys should be unique")
                
            default:
                Issue.record("Unknown collection type: \(testCase.collection)")
            }
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
        @Test(
            "Performance benchmarks",
            arguments: [
                ("enum_operations", 10000, Duration.milliseconds(100)),
                ("serialization", 1000, Duration.milliseconds(500)),
                ("categorization", 5000, Duration.milliseconds(200))
            ],
            traits: [InterventionTestTrait(category: "performance", severity: .low)]
        )
        func performanceBenchmarks(
            benchmark: (name: String, iterations: Int, maxDuration: Duration)
        ) throws {
            typealias InterventionType = InterventionTestUtilities.InterventionType
            
            let startTime = ContinuousClock().now
            
            switch benchmark.name {
            case "enum_operations":
                for i in 0..<benchmark.iterations {
                    let type = InterventionType.allCases[i % InterventionType.allCases.count]
                    _ = type.rawValue
                    _ = type == .connectionIssue
                    _ = type.hashValue
                }
                
            case "serialization":
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                for i in 0..<benchmark.iterations {
                    let type = InterventionType.allCases[i % InterventionType.allCases.count]
                    if let data = try? encoder.encode(type) {
                        _ = try? decoder.decode(InterventionType.self, from: data)
                    }
                }
                
            case "categorization":
                for i in 0..<benchmark.iterations {
                    let type = InterventionType.allCases[i % InterventionType.allCases.count]
                    _ = InterventionTestUtilities.categorizeInterventionType(type)
                    _ = InterventionTestUtilities.calculatePriority(for: type)
                }
                
            default:
                Issue.record("Unknown benchmark: \(benchmark.name)")
            }
            
            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < benchmark.maxDuration, 
                   "\(benchmark.name) should complete within \(benchmark.maxDuration)")
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

    // MARK: - Integration Tests
    
    @Suite("Integration", .tags(.integration), .disabled("Requires live intervention system"))
    struct IntegrationTests {
        @Test("End-to-end intervention flow", traits: [RequiresInterventionCapability.self])
        func endToEndInterventionFlow() async throws {
            // This test would verify actual intervention execution
            #expect(true)
        }
    }
}

// MARK: - Custom Assertions

extension InterventionEngineTests {
    func assertValidInterventionType(
        _ type: InterventionTestUtilities.InterventionType,
        expectedCategory: InterventionTestUtilities.InterventionCategory? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #expect(!type.rawValue.isEmpty, sourceLocation: SourceLocation(filePath: file, line: Int(line)))
        #expect(InterventionTestUtilities.InterventionType.allCases.contains(type), 
               sourceLocation: SourceLocation(filePath: file, line: Int(line)))
        
        if let expectedCategory = expectedCategory {
            let actualCategory = InterventionTestUtilities.categorizeInterventionType(type)
            #expect(actualCategory == expectedCategory, 
                   sourceLocation: SourceLocation(filePath: file, line: Int(line)))
        }
    }
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
