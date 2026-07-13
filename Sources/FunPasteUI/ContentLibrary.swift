import Foundation

public struct ContentLibrary: Sendable, Codable {
    public private(set) var items: [Clip]

    public init(items: [Clip] = []) {
        self.items = items.filter { $0.category == .prompt || $0.category == .pinned }
    }

    public static var seeded: ContentLibrary {
        ContentLibrary(items: Clip.demo.filter { $0.category == .prompt || $0.category == .pinned })
    }

    @discardableResult
    public mutating func create(category: ClipCategory, title: String, content: String) -> Clip {
        precondition(category == .prompt || category == .pinned)
        let clip = Clip(
            id: UUID().uuidString,
            category: category,
            title: title,
            content: content,
            source: category == .prompt ? "自定义 Prompt" : "收藏"
        )
        items.insert(clip, at: 0)
        return clip
    }

    public mutating func update(id: Clip.ID, title: String, content: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        items[index] = Clip(
            id: item.id,
            category: item.category,
            title: title,
            content: content,
            source: item.source,
            imageData: item.imageData
        )
    }

    public mutating func delete(id: Clip.ID) {
        items.removeAll { $0.id == id }
    }

    @discardableResult
    public mutating func pin(_ clip: Clip) -> Clip {
        if let existing = items.first(where: { $0.category == .pinned && $0.content == clip.content }) {
            return existing
        }

        let pinned = Clip(
            id: UUID().uuidString,
            category: .pinned,
            title: clip.title,
            content: clip.content,
            source: "收藏",
            imageData: clip.imageData
        )
        items.insert(pinned, at: 0)
        return pinned
    }
}
