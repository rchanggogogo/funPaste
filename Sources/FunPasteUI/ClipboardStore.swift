import AppKit
import ApplicationServices
import Combine

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var history: ClipHistory
    @Published public private(set) var isPaused: Bool
    @Published public private(set) var feedbackMessage: String?

    private let defaults: UserDefaults
    private let historyKey = "funPaste.history"
    private let pauseKey = "funPaste.isPaused"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.history = Self.loadHistory(from: defaults) ?? ClipHistory()
        self.isPaused = defaults.object(forKey: pauseKey) as? Bool ?? false
    }

    public var clips: [Clip] {
        Clip.presentationItems(history: history.clips)
    }

    public func recordClipboardText(_ content: String) {
        guard !isPaused else { return }
        history.record(content)
        persist()
    }

    public func recordClipboardImage(_ data: Data) {
        guard !isPaused else { return }
        history.recordImage(data)
        persist()
    }

    public func togglePause() {
        isPaused.toggle()
        defaults.set(isPaused, forKey: pauseKey)
        showFeedback(isPaused ? "已暂停记录剪贴板" : "已恢复记录剪贴板")
    }

    public func clearHistory() {
        history = ClipHistory(maximumCount: history.maximumCount)
        persist()
        showFeedback("已清空剪贴历史")
    }

    public func copy(_ clip: Clip) {
        NSPasteboard.general.clearContents()
        if let imageData = clip.imageData, let image = NSImage(data: imageData) {
            NSPasteboard.general.writeObjects([image])
        } else {
            NSPasteboard.general.setString(clip.content, forType: .string)
        }
    }

    public func paste(_ clip: Clip) {
        copy(clip)
        guard CGPreflightPostEventAccess() else {
            showFeedback("已复制，请手动粘贴")
            return
        }

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

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private static func loadHistory(from defaults: UserDefaults) -> ClipHistory? {
        guard let data = defaults.data(forKey: "funPaste.history") else { return nil }
        return try? JSONDecoder().decode(ClipHistory.self, from: data)
    }
}
