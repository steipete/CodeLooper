import Foundation
import Combine

public class Debouncer {
    private let delay: TimeInterval
    private var cancellable: AnyCancellable?
    private let subject = PassthroughSubject<() -> Void, Never>()

    public init(delay: TimeInterval) {
        self.delay = delay
        self.cancellable = subject
            .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink { action in
                action()
            }
    }

    public func call(_ action: @escaping () -> Void) {
        subject.send(action)
    }

    deinit {
        cancellable?.cancel()
    }
} 