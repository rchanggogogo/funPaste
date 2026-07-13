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
