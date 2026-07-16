public struct LibraryEditorState: Sendable {
    public var isPresented = false
    public var category: ClipCategory = .prompt
    public var editingItem: Clip?
    public var title = ""
    public var content = ""
    public var promptCollection: PromptCollection = .inbox
    public var tagsText = ""
    public var sourceURL = ""

    public init() {}

    public mutating func startCreating(category: ClipCategory) {
        self.category = category
        editingItem = nil
        title = ""
        content = ""
        promptCollection = .inbox
        tagsText = ""
        sourceURL = ""
        isPresented = true
    }

    public mutating func startEditing(_ item: Clip) {
        category = item.category
        editingItem = item
        title = item.title
        content = item.content
        promptCollection = item.promptMetadata?.collection ?? .inbox
        tagsText = item.promptMetadata?.tags.joined(separator: ", ") ?? ""
        sourceURL = item.promptMetadata?.sourceURL ?? ""
        isPresented = true
    }

    public mutating func close() {
        isPresented = false
        editingItem = nil
        title = ""
        content = ""
        promptCollection = .inbox
        tagsText = ""
        sourceURL = ""
    }

    public mutating func resetForPanelOpening() {
        close()
    }
}
