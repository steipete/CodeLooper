import Foundation

/// Thread-safe wrapper for values that need to be accessed from multiple concurrent contexts.
///
/// ThreadSafeBox provides a thread-safe container for any Sendable value type using
/// a concurrent DispatchQueue with barrier writes for safe read/write access across
/// multiple threads.
///
/// Usage:
/// ```swift
/// let box = ThreadSafeBox(false)
///
/// // Safe concurrent reads
/// let value = box.get()
///
/// // Safe writes with barrier synchronization
/// box.set(true)
/// ```
///
/// The implementation uses a concurrent queue that allows multiple readers but
/// ensures exclusive access during writes through barrier dispatch.
public final class ThreadSafeBox<T: Sendable>: @unchecked Sendable {
    // MARK: Lifecycle

    /// Creates a new ThreadSafeBox with the specified initial value
    /// - Parameter value: The initial value to store
    public init(_ value: T) {
        _value = value
    }

    // MARK: Public

    /// Safely retrieves the current value
    /// - Returns: The current value stored in the box
    public func get() -> T {
        queue.sync { _value }
    }

    /// Safely updates the stored value
    /// - Parameter value: The new value to store
    public func set(_ value: T) {
        queue.async(flags: .barrier) { [weak self] in
            self?._value = value
        }
    }

    /// Safely updates the value using a transform closure
    /// - Parameter transform: A closure that receives the current value and returns the new value
    public func update(_ transform: @escaping @Sendable (T) -> T) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self._value = transform(self._value)
        }
    }

    /// Safely reads and transforms the value without modifying it
    /// - Parameter transform: A closure that receives the current value and returns a transformed result
    /// - Returns: The result of the transform closure
    public func read<U>(_ transform: @Sendable (T) -> U) -> U {
        queue.sync { transform(_value) }
    }

    // MARK: Private

    private let queue = DispatchQueue(label: "ThreadSafeBox", attributes: .concurrent)
    private var _value: T
}

// MARK: - Convenience Extensions

public extension ThreadSafeBox where T: Equatable {
    /// Safely compares the stored value with another value
    /// - Parameter other: The value to compare against
    /// - Returns: True if the stored value equals the other value
    func equals(_ other: T) -> Bool {
        get() == other
    }
}

public extension ThreadSafeBox where T: Numeric {
    /// Safely increments a numeric value
    /// - Parameter amount: The amount to increment by (default: 1)
    func increment(by amount: T = 1) {
        update { $0 + amount }
    }

    /// Safely decrements a numeric value
    /// - Parameter amount: The amount to decrement by (default: 1)
    func decrement(by amount: T = 1) {
        update { $0 - amount }
    }
}

public extension ThreadSafeBox where T == Bool {
    /// Safely toggles a boolean value
    func toggle() {
        update { !$0 }
    }

    /// Safely sets the value to true
    func setTrue() {
        set(true)
    }

    /// Safely sets the value to false
    func setFalse() {
        set(false)
    }
}
