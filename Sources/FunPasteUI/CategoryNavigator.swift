import Foundation

public enum CategoryNavigator {
    public static func next(after category: ClipCategory) -> ClipCategory {
        let categories = ClipCategory.defaultOrder
        guard let index = categories.firstIndex(of: category) else { return categories[0] }
        return categories[(index + 1) % categories.count]
    }

    public static func previous(before category: ClipCategory) -> ClipCategory {
        let categories = ClipCategory.defaultOrder
        guard let index = categories.firstIndex(of: category) else { return categories[0] }
        return categories[(index - 1 + categories.count) % categories.count]
    }
}
