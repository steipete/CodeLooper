import Diagnostics
import Foundation

/// Collection of improved async/await patterns for common use cases.
///
/// These patterns provide structured approaches to common async scenarios
/// like retries, debouncing, batching, and resource management.
public enum AsyncPatterns {
    
    // MARK: - Retry Patterns
    
    /// Execute operation with exponential backoff retry
    public static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffFactor: Double = 2.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't delay on the last attempt
                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(delay))
                    delay *= backoffFactor
                }
            }
        }
        
        throw lastError ?? TaskError.noResult
    }
    
    /// Execute operation with retry on specific error conditions
    public static func withConditionalRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        shouldRetry: @escaping (Error) -> Bool,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Only retry if condition is met and we have attempts left
                if attempt < maxAttempts && shouldRetry(error) {
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    throw error
                }
            }
        }
        
        throw lastError ?? TaskError.noResult
    }
    
    // MARK: - Resource Management
    
    /// Execute operation with automatic resource cleanup
    public static func withResource<Resource, T>(
        acquire: @escaping () async throws -> Resource,
        release: @escaping (Resource) async throws -> Void,
        operation: @escaping (Resource) async throws -> T
    ) async throws -> T {
        let resource = try await acquire()
        
        do {
            let result = try await operation(resource)
            try await release(resource)
            return result
        } catch {
            try? await release(resource)
            throw error
        }
    }
    
    /// Execute operation with lock-like resource protection
    public static func withLock<T: Sendable>(
        lock: AsyncLock,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        await lock.acquire()
        defer { 
            Task { await lock.release() }
        }
        
        return try await operation()
    }
    
    // MARK: - Debouncing and Throttling
    
    /// Debounce async operations to prevent excessive calls
    public static func debounced<T: Sendable>(
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) -> @Sendable () async throws -> T? {
        let debouncer = AsyncDebouncer(delay: delay)
        
        return {
            try await debouncer.execute(operation)
        }
    }
    
    // MARK: - Batching Operations
    
    /// Execute operations in batches with controlled concurrency
    public static func batchExecute<T: Sendable, U: Sendable>(
        items: [T],
        batchSize: Int = 10,
        operation: @escaping @Sendable (T) async throws -> U
    ) async -> [U] {
        var results: [U] = []
        
        for batch in items.chunked(into: batchSize) {
            let batchResults = await withTaskGroup(of: U?.self) { group in
                for item in batch {
                    group.addTask {
                        do {
                            return try await operation(item)
                        } catch {
                            return nil
                        }
                    }
                }
                
                var batchResults: [U] = []
                for await result in group {
                    if let result = result {
                        batchResults.append(result)
                    }
                }
                return batchResults
            }
            
            results.append(contentsOf: batchResults)
        }
        
        return results
    }
    
    // MARK: - Stream Processing
    
    /// Process async sequence with error handling and backpressure
    public static func processSequence<S, T: Sendable>(
        sequence: S,
        bufferSize: Int = 100,
        processor: @escaping @Sendable (S.Element) async throws -> T
    ) async -> AsyncStream<Result<T, Error>> where S: AsyncSequence & Sendable, S.Element: Sendable {
        AsyncStream { continuation in
            Task {
                var buffer: [S.Element] = []
                
                do {
                    for try await element in sequence {
                        buffer.append(element)
                        
                        // Process buffer when it reaches capacity
                        if buffer.count >= bufferSize {
                            await processBatch(buffer, processor: processor, continuation: continuation)
                            buffer.removeAll()
                        }
                    }
                    
                    // Process remaining items
                    if !buffer.isEmpty {
                        await processBatch(buffer, processor: processor, continuation: continuation)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.yield(.failure(error))
                    continuation.finish()
                }
            }
        }
    }
    
    private static func processBatch<T: Sendable, U: Sendable>(
        _ batch: [T],
        processor: @escaping @Sendable (T) async throws -> U,
        continuation: AsyncStream<Result<U, Error>>.Continuation
    ) async {
        await withTaskGroup(of: Result<U, Error>.self) { group in
            for item in batch {
                group.addTask {
                    do {
                        let result = try await processor(item)
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            for await result in group {
                continuation.yield(result)
            }
        }
    }
}

// MARK: - Supporting Types

/// Simple async lock for resource protection
public actor AsyncLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    public init() {}
    
    public func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    public func release() {
        isLocked = false
        
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            isLocked = true
            waiter.resume()
        }
    }
}

/// Async debouncer to prevent excessive operations
public actor AsyncDebouncer {
    private let delay: TimeInterval
    private var currentTask: Task<Void, Never>?
    
    public init(delay: TimeInterval) {
        self.delay = delay
    }
    
    public func execute<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T? {
        // Cancel previous task
        currentTask?.cancel()
        
        // Create new debounced task
        currentTask = Task {
            try? await Task.sleep(for: .seconds(delay))
        }
        
        await currentTask?.value
        
        // If task was cancelled, return nil
        guard currentTask?.isCancelled == false else {
            return nil
        }
        
        return try await operation()
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// Split collection into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: Swift.min($0 + size, count))])
        }
    }
}

// MARK: - Timeout Utilities

/// Execute operation with timeout
public func withTimeout<T: Sendable>(
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

/// Execute operation with cancellation support
public func withCancellation<T: Sendable>(
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withTaskCancellationHandler {
        try await operation()
    } onCancel: {
        // Custom cancellation cleanup can go here
    }
}