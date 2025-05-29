import Foundation

/// A utility class that debounces function calls to prevent excessive execution.
///
/// Debouncer is used to limit the rate at which a function can fire by delaying
/// its execution until after a specified time has elapsed since the last call.
/// This is particularly useful for:
/// - Preventing excessive API calls during rapid user input
/// - Reducing UI update frequency for performance
/// - Batching multiple rapid events into a single action
///
/// Example usage:
/// ```swift
/// let debouncer = Debouncer(delay: 0.5)
/// debouncer.call {
///     // This will only execute 0.5 seconds after the last call
///     performExpensiveOperation()
/// }
/// ```
@MainActor
public final class Debouncer {
    // MARK: Lifecycle

    public init(delay: TimeInterval) {
        self.delay = delay

        // Create the stream and capture the continuation
        var streamContinuation: AsyncStream<@Sendable () -> Void>.Continuation?
        let stream = AsyncStream<@Sendable () -> Void> { continuation in
            streamContinuation = continuation
        }
        self.stream = stream
        self.continuation = streamContinuation

        // Start the debouncing task
        self.task = Task { @MainActor in
            var lastAction: (@Sendable () -> Void)?

            for await action in stream {
                lastAction = action

                // Cancel previous delay
                self.delayTask?.cancel()

                // Start new delay
                self.delayTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(delay))

                        // Execute the action if not cancelled
                        if !Task.isCancelled {
                            lastAction?()
                        }
                    } catch {
                        // Task was cancelled, which is expected
                    }
                }
            }
        }
    }

    deinit {
        task?.cancel()
        delayTask?.cancel()
        continuation?.finish()
    }

    // MARK: Public

    public func call(_ action: @escaping @Sendable () -> Void) {
        continuation?.yield(action)
    }

    // MARK: Private

    private let delay: TimeInterval
    private let stream: AsyncStream<@Sendable () -> Void>
    private var continuation: AsyncStream<@Sendable () -> Void>.Continuation?
    private var task: Task<Void, Never>?
    private var delayTask: Task<Void, Never>?
}
