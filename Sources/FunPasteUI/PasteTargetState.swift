import Foundation

public enum PasteTargetActivationAction: Equatable, Sendable {
    case paste
    case retryActivation
    case wait
    case fail
}

public enum PasteTargetActivationCoordinator {
    public static func nextAction(
        isFrontmost: Bool,
        attemptsRemaining: Int,
        retryInterval: Int
    ) -> PasteTargetActivationAction {
        if isFrontmost { return .paste }
        guard attemptsRemaining > 0 else { return .fail }
        guard retryInterval > 0 else { return .retryActivation }
        return attemptsRemaining.isMultiple(of: retryInterval) ? .retryActivation : .wait
    }
}

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
