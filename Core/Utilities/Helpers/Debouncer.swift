import Combine
import Foundation

public class Debouncer {
    // MARK: Lifecycle

    public init(delay: TimeInterval) {
        self.delay = delay
        self.cancellable = subject
            .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink { action in
                action()
            }
    }

    deinit {
        cancellable?.cancel()
    }

    // MARK: Public

    public func call(_ action: @escaping () -> Void) {
        subject.send(action)
    }

    // MARK: Private

    private let delay: TimeInterval
    private var cancellable: AnyCancellable?
    private let subject = PassthroughSubject<() -> Void, Never>()
}
