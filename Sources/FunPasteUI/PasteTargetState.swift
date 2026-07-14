import Foundation

public struct PasteTargetState: Equatable, Sendable {
    public private(set) var processIdentifier: pid_t?

    public init() {}

    public mutating func remember(processIdentifier: pid_t?, ownProcessIdentifier: pid_t) {
        guard let processIdentifier, processIdentifier != ownProcessIdentifier else { return }
        self.processIdentifier = processIdentifier
    }

    public func isFrontmost(processIdentifier: pid_t?) -> Bool {
        self.processIdentifier == processIdentifier
    }
}
