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
        case .inbox: FunPasteLocalization.string("collection.inbox")
        case .development: FunPasteLocalization.string("collection.development")
        case .research: FunPasteLocalization.string("collection.research")
        case .writing: FunPasteLocalization.string("collection.writing")
        case .productDesign: FunPasteLocalization.string("collection.productDesign")
        case .personal: FunPasteLocalization.string("collection.personal")
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
        case .smart: FunPasteLocalization.string("sort.smart")
        case .recentlyUsed: FunPasteLocalization.string("sort.recentlyUsed")
        case .recentlyAdded: FunPasteLocalization.string("sort.recentlyAdded")
        case .name: FunPasteLocalization.string("sort.name")
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
