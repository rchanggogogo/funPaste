import AppKit
import ApplicationServices
import Combine

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var history: ClipHistory
    @Published public private(set) var library: ContentLibrary
    @Published public private(set) var isPaused: Bool
    @Published public private(set) var feedbackMessage: String?

    private let defaults: UserDefaults
    private let historyKey = "funPaste.history"
    private let libraryKey = "funPaste.library"
    private let pauseKey = "funPaste.isPaused"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.history = Self.loadHistory(from: defaults) ?? ClipHistory()
        self.library = Self.loadLibrary(from: defaults) ?? .seeded
        self.isPaused = defaults.object(forKey: pauseKey) as? Bool ?? false
    }

    public var clips: [Clip] {
        Clip.presentationItems(history: history.clips, library: library)
    }

    public func recordClipboardText(_ content: String) {
        guard !isPaused else { return }
        history.record(content)
        persistHistory()
    }

    public func recordClipboardImage(_ data: Data) {
        guard !isPaused else { return }
        history.recordImage(data)
        persistHistory()
    }

    public func togglePause() {
        isPaused.toggle()
        defaults.set(isPaused, forKey: pauseKey)
        showFeedback(isPaused ? "已暂停记录剪贴板" : "已恢复记录剪贴板")
    }

    public func clearHistory() {
        history = ClipHistory(maximumCount: history.maximumCount)
        persistHistory()
        showFeedback("已清空剪贴历史")
    }

    @discardableResult
    public func createLibraryItem(category: ClipCategory, title: String, content: String) -> Clip {
        let item = library.create(category: category, title: title, content: content)
        persistLibrary()
        return item
    }

    public func updateLibraryItem(id: Clip.ID, title: String, content: String) {
        library.update(id: id, title: title, content: content)
        persistLibrary()
    }

    public func deleteLibraryItem(id: Clip.ID) {
        library.delete(id: id)
        persistLibrary()
    }

    @discardableResult
    public func pin(_ clip: Clip) -> Clip {
        let item = library.pin(clip)
        persistLibrary()
        return item
    }

    public func isPinned(_ clip: Clip) -> Bool {
        library.items.contains { $0.category == .pinned && $0.content == clip.content }
    }

    public func copy(_ clip: Clip) {
        NSPasteboard.general.clearContents()
        if let imageData = clip.imageData, let image = NSImage(data: imageData) {
            NSPasteboard.general.writeObjects([image])
        } else {
            NSPasteboard.general.setString(clip.content, forType: .string)
        }
    }

    public func paste(_ clip: Clip, prepareForPaste: @escaping @MainActor () -> Void = {}) {
        copy(clip)
        guard CGPreflightPostEventAccess() else {
            CGRequestPostEventAccess()
            showFeedback("已复制，请手动粘贴")
            return
        }

        prepareForPaste()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            self?.postPasteEvent(for: clip)
        }
    }

    private func postPasteEvent(for clip: Clip) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        showFeedback("已粘贴「\(clip.title)」")
    }

    public func showFeedback(_ message: String) {
        feedbackMessage = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.feedbackMessage = nil
        }
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func persistLibrary() {
        guard let data = try? JSONEncoder().encode(library) else { return }
        defaults.set(data, forKey: libraryKey)
    }

    private static func loadHistory(from defaults: UserDefaults) -> ClipHistory? {
        guard let data = defaults.data(forKey: "funPaste.history") else { return nil }
        return try? JSONDecoder().decode(ClipHistory.self, from: data)
    }

    private static func loadLibrary(from defaults: UserDefaults) -> ContentLibrary? {
        guard let data = defaults.data(forKey: "funPaste.library") else { return nil }
        return try? JSONDecoder().decode(ContentLibrary.self, from: data)
    }
}
