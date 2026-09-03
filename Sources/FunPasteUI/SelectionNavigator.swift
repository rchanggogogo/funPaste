import Foundation

public enum SelectionNavigator {
    public static func nextIndex(current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((current ?? -1) + 1) % count
    }

    public static func previousIndex(current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((current ?? 0) - 1 + count) % count
    }
}

public enum ClipSelectionAction: Equatable, Sendable {
    case select
    case usePrompt
    case paste
}

public enum ClipSelectionResolver {
    public static func action(
        for category: ClipCategory,
        insertsIntoPrompt: Bool
    ) -> ClipSelectionAction {
        if insertsIntoPrompt { return .paste }
        return category == .prompt ? .usePrompt : .select
    }
}
