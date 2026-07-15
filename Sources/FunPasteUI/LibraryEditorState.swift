public struct LibraryEditorState: Sendable {
    public var isPresented = false
    public var category: ClipCategory = .prompt
    public var editingItem: Clip?
    public var title = ""
    public var content = ""

    public init() {}

    public mutating func startCreating(category: ClipCategory) {
        self.category = category
        editingItem = nil
        title = ""
        content = ""
        isPresented = true
    }

    public mutating func startEditing(_ item: Clip) {
        category = item.category
        editingItem = item
        title = item.title
        content = item.content
        isPresented = true
    }

    public mutating func close() {
        isPresented = false
        editingItem = nil
        title = ""
        content = ""
    }

    public mutating func resetForPanelOpening() {
        close()
    }
}
