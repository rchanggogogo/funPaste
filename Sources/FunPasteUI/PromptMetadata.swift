import Foundation

public enum PromptCollection: String, CaseIterable, Codable, Sendable {
    case inbox
    case development
    case research
    case writing
    case productDesign
    case personal

    public var label: String {
        switch self {
        case .inbox: "收件箱"
        case .development: "开发"
        case .research: "研究"
        case .writing: "写作"
        case .productDesign: "产品设计"
        case .personal: "个人"
        }
    }
}

public enum PromptSortOrder: String, CaseIterable, Codable, Sendable {
    case smart
    case recentlyUsed
    case recentlyAdded
    case name

    public var label: String {
        switch self {
        case .smart: "智能排序"
        case .recentlyUsed: "最近使用"
        case .recentlyAdded: "最近添加"
        case .name: "按名称"
        }
    }
}

public struct PromptMetadata: Equatable, Sendable, Codable {
    public var collection: PromptCollection
    public var tags: [String]
    public var isFavorite: Bool
    public var isArchived: Bool
    public var manualOrder: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
    public var useCount: Int
    public var sourceURL: String?

    public init(
        collection: PromptCollection = .inbox,
        tags: [String] = [],
        isFavorite: Bool = false,
        isArchived: Bool = false,
        manualOrder: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0,
        sourceURL: String? = nil
    ) {
        self.collection = collection
        self.tags = Self.normalizedTags(tags)
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.manualOrder = manualOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.sourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    public static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { value in
            let tag = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else { return nil }
            let key = tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { return nil }
            return tag
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
