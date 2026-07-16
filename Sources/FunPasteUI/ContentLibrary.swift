import Foundation

public struct ContentLibrary: Sendable, Codable {
    public private(set) var items: [Clip]

    public init(items: [Clip] = []) {
        self.items = items.filter { $0.category == .prompt || $0.category == .pinned }
    }

    public static var seeded: ContentLibrary {
        let enrichedItems = Clip.demo
            .filter { $0.category == .prompt || $0.category == .pinned }
            .enumerated()
            .map { index, item in
                guard item.category == .prompt else { return item }
                var metadata = builtInPromptMetadata[item.id] ?? PromptMetadata(collection: .inbox)
                metadata.manualOrder = index
                return item
                    .replacingContent(Clip.formattedBuiltInPromptContent(id: item.id, content: item.content))
                    .replacingPromptMetadata(metadata)
            }
        return ContentLibrary(items: enrichedItems)
    }

    static let builtInPromptMetadata: [Clip.ID: PromptMetadata] = {
        let claudeURL = "https://code.claude.com/docs/en/best-practices"
        let openAIURL = "https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6"
        return [
            "development-prompt": PromptMetadata(collection: .development, tags: ["功能开发", "实现"]),
            "plain-language-prompt": PromptMetadata(collection: .writing, tags: ["解释", "初学者"]),
            "effective-ai-collaboration-prompt": PromptMetadata(collection: .development, tags: ["协作", "验收"], sourceURL: claudeURL),
            "requirements-interview-prompt": PromptMetadata(collection: .productDesign, tags: ["需求", "访谈"], sourceURL: claudeURL),
            "explore-plan-implement-prompt": PromptMetadata(collection: .development, tags: ["规划", "实现"], sourceURL: claudeURL),
            "root-cause-debugging-prompt": PromptMetadata(collection: .development, tags: ["调试", "根因"], sourceURL: claudeURL),
            "code-review-prompt": PromptMetadata(collection: .development, tags: ["代码审查", "质量"]),
            "test-generation-prompt": PromptMetadata(collection: .development, tags: ["测试", "回归"]),
            "behavior-preserving-refactor-prompt": PromptMetadata(collection: .development, tags: ["重构", "兼容性"]),
            "gpt-5p6-outcome-contract-prompt": PromptMetadata(collection: .development, tags: ["结果契约", "交付"], sourceURL: openAIURL),
            "gpt-5p6-prompt-audit-prompt": PromptMetadata(collection: .development, tags: ["Prompt 优化", "评估"], sourceURL: openAIURL),
            "gpt-5p6-grounded-research-prompt": PromptMetadata(collection: .research, tags: ["研究", "证据"], sourceURL: openAIURL)
        ]
    }()

    @discardableResult
    public mutating func create(
        category: ClipCategory,
        title: String,
        content: String,
        promptMetadata: PromptMetadata? = nil
    ) -> Clip {
        precondition(category == .prompt || category == .pinned)
        let clip = Clip(
            id: UUID().uuidString,
            category: category,
            title: title,
            content: content,
            source: category == .prompt ? "自定义 Prompt" : "收藏",
            promptMetadata: category == .prompt ? (promptMetadata ?? PromptMetadata()) : nil
        )
        items.insert(clip, at: 0)
        return clip
    }

    public mutating func update(
        id: Clip.ID,
        title: String,
        content: String,
        promptMetadata: PromptMetadata? = nil
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        items[index] = Clip(
            id: item.id,
            category: item.category,
            title: title,
            content: content,
            source: item.source,
            imageData: item.imageData,
            fileURLs: item.fileURLs,
            promptMetadata: promptMetadata ?? item.promptMetadata
        )
    }

    public mutating func delete(id: Clip.ID) {
        items.removeAll { $0.id == id }
    }

    mutating func addMissing(_ newItems: [Clip]) {
        let existingIDs = Set(items.map(\.id))
        items.append(contentsOf: newItems.filter { !existingIDs.contains($0.id) })
    }

    mutating func migratePromptMetadata(defaultsByID: [Clip.ID: PromptMetadata]) {
        var promptOrder = 0
        items = items.map { item in
            guard item.category == .prompt, item.promptMetadata == nil else { return item }
            var metadata = defaultsByID[item.id] ?? PromptMetadata(collection: .inbox)
            metadata.manualOrder = promptOrder
            promptOrder += 1
            return item.replacingPromptMetadata(metadata)
        }
    }

    mutating func formatBuiltInPrompts() {
        let builtInIDs = Set(Clip.builtInPromptTemplates.map(\.id))
        items = items.map { item in
            guard builtInIDs.contains(item.id), !item.content.contains("\n") else { return item }
            return item.replacingContent(
                Clip.formattedBuiltInPromptContent(id: item.id, content: item.content)
            )
        }
    }

    public func duplicatePrompt(content: String, excludingID: Clip.ID? = nil) -> Clip? {
        let normalizedContent = Self.normalizedPromptContent(content)
        guard !normalizedContent.isEmpty else { return nil }
        return items.first {
            $0.category == .prompt &&
                $0.id != excludingID &&
                Self.normalizedPromptContent($0.content) == normalizedContent
        }
    }

    public mutating func togglePromptFavorite(id: Clip.ID) {
        updatePromptMetadata(id: id) { metadata in
            metadata.isFavorite.toggle()
        }
    }

    public mutating func setPromptArchived(id: Clip.ID, isArchived: Bool) {
        updatePromptMetadata(id: id) { metadata in
            metadata.isArchived = isArchived
        }
    }

    public mutating func recordPromptUse(id: Clip.ID, at date: Date = Date()) {
        updatePromptMetadata(id: id, updateTimestamp: false) { metadata in
            metadata.lastUsedAt = date
            metadata.useCount += 1
        }
    }

    public func prompts(
        collection: PromptCollection? = nil,
        favoritesOnly: Bool = false,
        archived: Bool = false,
        query: String = "",
        sortOrder: PromptSortOrder = .smart
    ) -> [Clip] {
        let terms = query.split(whereSeparator: \.isWhitespace).map {
            String($0).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        let filtered = items.filter { item in
            guard item.category == .prompt else { return false }
            let metadata = Self.metadata(for: item)
            guard metadata.isArchived == archived else { return false }
            guard collection == nil || metadata.collection == collection else { return false }
            guard !favoritesOnly || metadata.isFavorite else { return false }
            guard !terms.isEmpty else { return true }
            let searchable = ([item.title, item.content, item.source, metadata.collection.label, metadata.sourceURL ?? ""] + metadata.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return terms.allSatisfy(searchable.contains)
        }
        return filtered.sorted { lhs, rhs in
            Self.promptPrecedes(lhs, rhs, sortOrder: sortOrder)
        }
    }

    public static func normalizedPromptContent(_ content: String) -> String {
        content.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private mutating func updatePromptMetadata(
        id: Clip.ID,
        updateTimestamp: Bool = true,
        transform: (inout PromptMetadata) -> Void
    ) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.category == .prompt }) else { return }
        var metadata = items[index].promptMetadata ?? PromptMetadata()
        transform(&metadata)
        if updateTimestamp { metadata.updatedAt = Date() }
        items[index] = items[index].replacingPromptMetadata(metadata)
    }

    private static func promptPrecedes(_ lhs: Clip, _ rhs: Clip, sortOrder: PromptSortOrder) -> Bool {
        let left = metadata(for: lhs)
        let right = metadata(for: rhs)
        switch sortOrder {
        case .smart:
            if left.isFavorite != right.isFavorite { return left.isFavorite }
            if left.manualOrder != right.manualOrder {
                return (left.manualOrder ?? Int.max) < (right.manualOrder ?? Int.max)
            }
            if left.lastUsedAt != right.lastUsedAt {
                return (left.lastUsedAt ?? .distantPast) > (right.lastUsedAt ?? .distantPast)
            }
            return left.updatedAt > right.updatedAt
        case .recentlyUsed:
            if left.lastUsedAt != right.lastUsedAt {
                return (left.lastUsedAt ?? .distantPast) > (right.lastUsedAt ?? .distantPast)
            }
            return left.updatedAt > right.updatedAt
        case .recentlyAdded:
            return left.createdAt > right.createdAt
        case .name:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func metadata(for item: Clip) -> PromptMetadata {
        item.promptMetadata ?? PromptMetadata(
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
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
            imageData: clip.imageData,
            fileURLs: clip.fileURLs
        )
        items.insert(pinned, at: 0)
        return pinned
    }

    @discardableResult
    public mutating func unpin(_ clip: Clip) -> Bool {
        let countBeforeRemoval = items.count
        items.removeAll { $0.category == .pinned && $0.content == clip.content }
        return items.count != countBeforeRemoval
    }
}
