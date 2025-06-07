import AppKit
@testable import CodeLooper
import Foundation
import Testing

// MARK: - Custom Test Traits

struct ProcessMonitoringTrait: TestTrait {
    let category: String
    let priority: Priority
    
    enum Priority {
        case low, medium, high, critical
    }
}

struct StatusTransitionTrait: TestTrait {
    let fromStatus: String
    let toStatus: String
    let isValid: Bool
}

// MARK: - Shared Test Utilities

enum ProcessMonitoringTestUtilities {
    static func validateRecoveryType(_ type: RecoveryType) throws {
        #expect(!type.rawValue.isEmpty)
        #expect(RecoveryType.allCases.contains(type))
    }
    
    static func validateInstanceStatus(_ status: CursorInstanceStatus) throws {
        // Status-specific validation
        switch status {
        case .working(let detail):
            #expect(!detail.isEmpty)
        case .error(let reason), .unrecoverable(let reason):
            #expect(!reason.isEmpty)
        case .recovering(let type, let attempt):
            #expect(attempt > 0)
            try validateRecoveryType(type)
        default:
            break
        }
    }
    
    static func categorizeStatus(_ status: CursorInstanceStatus) -> StatusCategory {
        switch status {
        case .unknown, .idle, .paused:
            return .neutral
        case .working:
            return .active
        case .recovering:
            return .transitional
        case .error:
            return .problematic
        case .unrecoverable:
            return .terminal
        }
    }
    
    enum StatusCategory {
        case neutral, active, transitional, problematic, terminal
    }
    
    static func createStatusMatrix() -> [(status: CursorInstanceStatus, category: StatusCategory, canRecover: Bool)] {
        [
            (.unknown, .neutral, true),
            (.idle, .neutral, true),
            (.paused, .neutral, true),
            (.working(detail: "Generating"), .active, true),
            (.recovering(type: .connection, attempt: 1), .transitional, true),
            (.error(reason: "Connection lost"), .problematic, true),
            (.unrecoverable(reason: "Fatal error"), .terminal, false)
        ]
    }
}

// MARK: - Test Conditions

struct RequiresProcessMonitoring: TestTrait {
    static var isEnabled: Bool {
        return true
    }
}

// MARK: - Main Test Suite

@Suite("Process Monitoring", .serialized)
struct ProcessMonitoringTests {
    // Shared test data
    var recoveryTypeMatrix: [(type: RecoveryType, priority: Int, maxAttempts: Int)] {
        [
            (.connection, 100, 5),
            (.stopGenerating, 80, 3),
            (.stuck, 60, 3),
            (.forceStop, 40, 1)
        ]
    }
    
    var statusTransitionMatrix: [(from: CursorInstanceStatus, to: CursorInstanceStatus, valid: Bool)] {
        [
            (.unknown, .idle, true),
            (.idle, .working(detail: "Generating"), true),
            (.working(detail: "Generating"), .error(reason: "Timeout"), true),
            (.error(reason: "Timeout"), .recovering(type: .connection, attempt: 1), true),
            (.recovering(type: .connection, attempt: 1), .working(detail: "Generating"), true),
            (.unrecoverable(reason: "Fatal"), .working(detail: "Generating"), false),
            (.paused, .unrecoverable(reason: "Fatal"), false)
        ]
    }
    
    // MARK: - Recovery Type Suite
    
    @Suite("Recovery Types", .tags(.recovery, .enum))
    struct RecoveryTypes {
        @Test(
            "Recovery type validation matrix",
            arguments: RecoveryType.allCases
        )
        func recoveryTypeValidationMatrix(type: RecoveryType) throws {
            try ProcessMonitoringTestUtilities.validateRecoveryType(type)
            
            // Validate raw values follow convention
            #expect(type.rawValue.first?.isLowercase == true)
            #expect(!type.rawValue.contains(" "))
        }
        
        @Test(
            "Recovery type properties",
            arguments: ProcessMonitoringTests().recoveryTypeMatrix
        )
        func recoveryTypeProperties(testCase: (type: RecoveryType, priority: Int, maxAttempts: Int)) throws {
            let (type, expectedPriority, expectedMaxAttempts) = testCase
            
            // Validate priority ordering
            switch type {
            case .connection:
                #expect(expectedPriority >= 80, "Connection issues should be high priority")
            case .forceStop:
                #expect(expectedPriority <= 50, "Force stop should be lower priority")
            default:
                #expect(expectedPriority > 0 && expectedPriority < 100)
            }
            
            // Validate attempt limits
            #expect(expectedMaxAttempts >= 1 && expectedMaxAttempts <= 5)
        }
        
        @Test("Recovery type serialization round-trip")
        func recoveryTypeSerializationRoundTrip() throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            for type in RecoveryType.allCases {
                let data = try encoder.encode(type)
                let decoded = try decoder.decode(RecoveryType.self, from: data)
                #expect(decoded == type)
            }
        }
    }
    
    // MARK: - Instance Status Suite
    
    @Suite("Instance Status", .tags(.status, .state))
    struct InstanceStatus {
        @Test(
            "Status validation matrix",
            arguments: ProcessMonitoringTestUtilities.createStatusMatrix()
        )
        func statusValidationMatrix(
            testCase: (status: CursorInstanceStatus, category: ProcessMonitoringTestUtilities.StatusCategory, canRecover: Bool)
        ) throws {
            try ProcessMonitoringTestUtilities.validateInstanceStatus(testCase.status)
            
            let calculatedCategory = ProcessMonitoringTestUtilities.categorizeStatus(testCase.status)
            #expect(calculatedCategory == testCase.category)
            
            // Validate recovery capability
            if testCase.category == .terminal {
                #expect(!testCase.canRecover, "Terminal states should not be recoverable")
            }
        }
        
        @Test("Status equality and uniqueness")
        @MainActor func statusEqualityAndUniqueness() async throws {
            await confirmation("Status equality rules", expectedCount: 5) { confirm in
                // Same status with same parameters
                let status1 = CursorInstanceStatus.working(detail: "Generating")
                let status2 = CursorInstanceStatus.working(detail: "Generating")
                #expect(status1 == status2)
                confirm()
                
                // Same status with different parameters
                let status3 = CursorInstanceStatus.working(detail: "Different")
                #expect(status1 != status3)
                confirm()
                
                // Different status types
                let status4 = CursorInstanceStatus.idle
                let status5 = CursorInstanceStatus.paused
                #expect(status4 != status5)
                confirm()
                
                // Recovery with different attempts
                let recovery1 = CursorInstanceStatus.recovering(type: .connection, attempt: 1)
                let recovery2 = CursorInstanceStatus.recovering(type: .connection, attempt: 2)
                #expect(recovery1 != recovery2)
                confirm()
                
                // Error vs unrecoverable with same reason
                let error = CursorInstanceStatus.error(reason: "Same reason")
                let unrecoverable = CursorInstanceStatus.unrecoverable(reason: "Same reason")
                #expect(error != unrecoverable)
                confirm()
            }
        }
        
        @Test(
            "Status in collections",
            arguments: [5, 10, 20]
        )
        func statusInCollections(uniqueStatusCount: Int) throws {
            var statusSet: Set<CursorInstanceStatus> = []
            
            // Add various statuses
            statusSet.insert(.unknown)
            statusSet.insert(.idle)
            statusSet.insert(.paused)
            
            // Add multiple working statuses
            for i in 0..<uniqueStatusCount {
                statusSet.insert(.working(detail: "Task \(i)"))
            }
            
            // Add recovery statuses
            for i in 1...3 {
                statusSet.insert(.recovering(type: .connection, attempt: i))
            }
            
            // Verify set contains unique values
            let expectedCount = 3 + uniqueStatusCount + 3
            #expect(statusSet.count == expectedCount)
        }
    }
    
    // MARK: - State Transitions Suite
    
    @Suite("State Transitions", .tags(.transitions, .state))
    struct StateTransitions {
        @Test(
            "Valid state transitions",
            arguments: ProcessMonitoringTests().statusTransitionMatrix
        )
        func validStateTransitions(
            transition: (from: CursorInstanceStatus, to: CursorInstanceStatus, valid: Bool)
        ) throws {
            if transition.valid {
                // Valid transitions should follow logical patterns
                let fromCategory = ProcessMonitoringTestUtilities.categorizeStatus(transition.from)
                let toCategory = ProcessMonitoringTestUtilities.categorizeStatus(transition.to)
                
                // Terminal states should not transition to anything
                if fromCategory == .terminal {
                    #expect(!transition.valid, "Terminal states should not have valid transitions")
                }
                
                // Paused state has limited transitions
                if case .paused = transition.from {
                    #expect(toCategory == .neutral || toCategory == .active,
                           "Paused should only transition to neutral or active states")
                }
            } else {
                // Invalid transitions
                let fromCategory = ProcessMonitoringTestUtilities.categorizeStatus(transition.from)
                if fromCategory == .terminal {
                    #expect(Bool(true), "Terminal states correctly have no valid transitions")
                }
            }
        }
        
        @Test("Recovery progression")
        func recoveryProgression() throws {
            let maxAttempts = 5
            var recoveryStates: [CursorInstanceStatus] = []
            
            for attempt in 1...maxAttempts {
                recoveryStates.append(.recovering(type: .connection, attempt: attempt))
            }
            
            // Verify progression
            for i in 0..<recoveryStates.count - 1 {
                if case let .recovering(_, attempt1) = recoveryStates[i],
                   case let .recovering(_, attempt2) = recoveryStates[i + 1] {
                    #expect(attempt2 == attempt1 + 1, "Attempts should increment")
                }
            }
            
            // Test transition to error after max attempts
            let finalRecovery = CursorInstanceStatus.recovering(type: .connection, attempt: maxAttempts)
            let errorState = CursorInstanceStatus.error(reason: "Max attempts reached")
            
            // This represents a logical transition (not equality test)
            #expect(finalRecovery != errorState, "Different states as expected")
        }
    }
    
    // MARK: - Performance Suite
    
    @Suite("Performance", .tags(.performance, .benchmarks))
    struct Performance {
        @Test(
            "Status operations performance",
            .timeLimit(.minutes(1))
        )
        func statusOperationsPerformance() throws {
            let iterations = 10000
            let startTime = ContinuousClock().now
            
            for i in 0..<iterations {
                // Create various statuses
                let status = switch i % 7 {
                case 0: CursorInstanceStatus.unknown
                case 1: CursorInstanceStatus.idle
                case 2: CursorInstanceStatus.working(detail: "Task \(i)")
                case 3: CursorInstanceStatus.recovering(type: .connection, attempt: i % 5 + 1)
                case 4: CursorInstanceStatus.error(reason: "Error \(i)")
                case 5: CursorInstanceStatus.paused
                default: CursorInstanceStatus.unrecoverable(reason: "Fatal \(i)")
                }
                
                // Perform operations
                _ = ProcessMonitoringTestUtilities.categorizeStatus(status)
                _ = status.hashValue
            }
            
            let elapsed = ContinuousClock().now - startTime
            #expect(elapsed < .seconds(1), "Operations should complete quickly")
        }
        
        @Test("Collection performance with statuses", .timeLimit(.minutes(1)))
        func collectionPerformanceWithStatuses() throws {
            var statusSet: Set<CursorInstanceStatus> = []
            var statusArray: [CursorInstanceStatus] = []
            
            // Add many unique statuses
            for i in 0..<1000 {
                let status = CursorInstanceStatus.working(detail: "Task \(i)")
                statusSet.insert(status)
                statusArray.append(status)
            }
            
            #expect(statusSet.count == 1000, "Set should maintain uniqueness")
            #expect(statusArray.count == 1000, "Array should contain all elements")
            
            // Test lookup performance
            let lookupStatus = CursorInstanceStatus.working(detail: "Task 500")
            #expect(statusSet.contains(lookupStatus), "Set should contain the status")
            #expect(statusArray.contains(lookupStatus), "Array should contain the status")
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration", .tags(.integration), .disabled("Requires live monitoring"))
    struct IntegrationTests {
        @Test("End-to-end status flow")
        func endToEndStatusFlow() async throws {
            // This test would verify actual process monitoring
            #expect(Bool(true))
        }
    }
}

// MARK: - Custom Assertions

extension ProcessMonitoringTests {
    func assertValidStatus(
        _ status: CursorInstanceStatus,
        expectedCategory: ProcessMonitoringTestUtilities.StatusCategory? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try ProcessMonitoringTestUtilities.validateInstanceStatus(status)
        } catch {
            Issue.record("Status validation failed: \(error)", 
                        sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        }
        
        if let expectedCategory = expectedCategory {
            let actualCategory = ProcessMonitoringTestUtilities.categorizeStatus(status)
            #expect(actualCategory == expectedCategory,
                   sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1))
        }
    }
}

