import Diagnostics
import Foundation

/// Manages structured concurrency and task lifecycle for the application.
///
/// This coordinator provides consistent patterns for async task management,
/// cancellation, timeout handling, and error recovery to improve reliability
/// and prevent common concurrency issues.
@MainActor
public final class TaskManager {
    // MARK: - Singleton
    
    public static let shared = TaskManager()
    
    private init() {
        logger.info("TaskManager initialized")
    }
    
    deinit {
        // Cleanup handled externally to avoid actor isolation issues
    }
    
    // MARK: - Public API
    
    /// Execute a task with automatic error handling and timeout
    @discardableResult
    public func execute<T: Sendable>(
        name: String,
        timeout: TimeInterval? = nil,
        priority: TaskPriority = .medium,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        let taskId = generateTaskId(name: name)
        logger.debug("🚀 Starting task '\(name)' (ID: \(taskId))")
        
        let task = Task(priority: priority) {
            do {
                let result: T
                
                if let timeout = timeout {
                    result = try await withTimeout(timeout) {
                        try await operation()
                    }
                } else {
                    result = try await operation()
                }
                
                logger.debug("✅ Task '\(name)' completed successfully")
                return result
                
            } catch {
                await ErrorHandler.shared.handleAsync(
                    error,
                    context: .backgroundOperation,
                    showAlert: false
                )
                logger.error("❌ Task '\(name)' failed: \(error)")
                throw error
            }
        }
        
        // Track the task
        activeTasks[taskId] = TaskInfo(
            id: taskId,
            name: name,
            task: task,
            startTime: Date()
        )
        
        defer {
            activeTasks.removeValue(forKey: taskId)
        }
        
        do {
            return try await task.value
        } catch {
            return nil
        }
    }
    
    /// Execute a detached task that runs independently
    @discardableResult
    public func executeDetached<T: Sendable>(
        name: String,
        timeout: TimeInterval? = nil,
        priority: TaskPriority = .low,
        operation: @escaping @Sendable () async throws -> T
    ) -> Task<T?, Never> {
        Task.detached(priority: priority) { [weak self] in
            await self?.execute(
                name: name,
                timeout: timeout,
                priority: priority,
                operation: operation
            )
        }
    }
    
    /// Execute a task group for concurrent operations
    public func executeGroup<T: Sendable>(
        name: String,
        operations: [(String, @Sendable () async throws -> T)]
    ) async -> [T] {
        logger.debug("🔄 Starting task group '\(name)' with \(operations.count) operations")
        
        return await withTaskGroup(of: T?.self) { group in
            for (operationName, operation) in operations {
                group.addTask { [weak self] in
                    await self?.execute(
                        name: "\(name).\(operationName)",
                        operation: operation
                    )
                }
            }
            
            var results: [T] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            logger.debug("✅ Task group '\(name)' completed with \(results.count) successful operations")
            return results
        }
    }
    
    /// Execute a repeating task with interval
    @discardableResult
    public func executeRepeating(
        name: String,
        interval: TimeInterval,
        maxIterations: Int? = nil,
        operation: @escaping @Sendable () async throws -> Void
    ) -> Task<Void, Never> {
        let taskId = generateTaskId(name: name)
        logger.debug("🔁 Starting repeating task '\(name)' (interval: \(interval)s)")
        
        let task = Task {
            var iteration = 0
            
            while !Task.isCancelled {
                // Check max iterations
                if let maxIterations = maxIterations, iteration >= maxIterations {
                    logger.debug("🏁 Repeating task '\(name)' reached max iterations (\(maxIterations))")
                    break
                }
                
                do {
                    try await operation()
                    iteration += 1
                } catch {
                    await ErrorHandler.shared.handleAsync(
                        error,
                        context: .backgroundOperation,
                        showAlert: false
                    )
                    
                    // Continue on error unless it's a cancellation
                    if error is CancellationError {
                        break
                    }
                }
                
                // Wait for interval
                try? await Task.sleep(for: .seconds(interval))
            }
            
            logger.debug("🛑 Repeating task '\(name)' stopped after \(iteration) iterations")
        }
        
        activeTasks[taskId] = TaskInfo(
            id: taskId,
            name: name,
            task: task,
            startTime: Date()
        )
        
        return task
    }
    
    /// Cancel all active tasks
    public func cancelAllTasks() {
        let taskCount = activeTasks.count
        logger.debug("🛑 Cancelling \(taskCount) active tasks")
        
        for taskInfo in activeTasks.values {
            taskInfo.cancel()
        }
        
        activeTasks.removeAll()
        logger.debug("✅ All tasks cancelled")
    }
    
    /// Cancel a specific task by name
    public func cancelTask(named name: String) {
        let matchingTasks = activeTasks.values.filter { $0.name == name }
        
        for taskInfo in matchingTasks {
            logger.debug("🛑 Cancelling task '\(name)' (ID: \(taskInfo.id))")
            taskInfo.cancel()
            activeTasks.removeValue(forKey: taskInfo.id)
        }
    }
    
    /// Get status of active tasks
    public func getActiveTasksStatus() -> [TaskStatus] {
        activeTasks.values.map { taskInfo in
            TaskStatus(
                id: taskInfo.id,
                name: taskInfo.name,
                startTime: taskInfo.startTime,
                duration: Date().timeIntervalSince(taskInfo.startTime),
                isCancelled: taskInfo.isCancelled()
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private let logger = Logger(category: .general)
    private var activeTasks: [String: TaskInfo] = [:]
    private var taskCounter: UInt64 = 0
    
    private func generateTaskId(name: String) -> String {
        taskCounter += 1
        return "\(name)_\(taskCounter)"
    }
    
    /// Execute operation with timeout
    private func withTimeout<T: Sendable>(
        _ timeout: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw TaskError.timeout(duration: timeout)
            }
            
            // Return first result and cancel remaining
            defer { group.cancelAll() }
            
            if let result = try await group.next() {
                return result
            } else {
                throw TaskError.noResult
            }
        }
    }
}

// MARK: - Supporting Types

/// Internal structure for tracking active tasks with metadata
private struct TaskInfo {
    let id: String
    let name: String
    let startTime: Date
    let cancel: () -> Void
    let isCancelled: () -> Bool
    
    init<T, F>(id: String, name: String, task: Task<T, F>, startTime: Date) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.cancel = { task.cancel() }
        self.isCancelled = { task.isCancelled }
    }
}

/// Represents the status of a managed task
///
/// TaskStatus provides metadata about a task's execution including
/// timing information and completion state.
public struct TaskStatus {
    public let id: String
    public let name: String
    public let startTime: Date
    public let duration: TimeInterval
    public let isCancelled: Bool
}

/// Errors that can occur during task execution
///
/// TaskError provides specific error cases for managed task operations
/// with descriptive error messages for each failure mode.
public enum TaskError: Error, LocalizedError {
    /// Task exceeded its timeout duration
    case timeout(duration: TimeInterval)
    /// Task was cancelled before completion
    case cancelled
    /// Task completed but produced no result
    case noResult
    
    public var errorDescription: String? {
        switch self {
        case let .timeout(duration):
            return "Task timed out after \(duration) seconds"
        case .cancelled:
            return "Task was cancelled"
        case .noResult:
            return "Task completed without result"
        }
    }
}


