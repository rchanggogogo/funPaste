import AppKit
import ApplicationServices
import Combine
import OSLog

private let clipboardLogger = Logger(subsystem: "com.changlei.funPaste", category: "粘贴")

@MainActor
public final class ClipboardStore: ObservableObject {
    private static let historyKey = "funPaste.history"
    private static let libraryKey = "funPaste.library"
    private static let librarySeedVersionKey = "funPaste.librarySeedVersion"
    private static let currentLibrarySeedVersion = 4
    private static let historyMaximumCountKey = "funPaste.historyMaximumCount"
    public static let availableHistoryMaximumCounts = [50, 100, 200, 500, 1_000, 2_000]

    @Published public private(set) var history: ClipHistory
    @Published public private(set) var library: ContentLibrary
    @Published public private(set) var isPaused: Bool
    @Published public private(set) var feedbackMessage: String?

    private let defaults: UserDefaults
    private let pasteEventAuthorization: PasteEventAuthorization
    private let pauseKey = "funPaste.isPaused"

    public init(
        defaults: UserDefaults = .standard,
        pasteEventAuthorization: PasteEventAuthorization = .live
    ) {
        let loadedHistory = Self.loadHistory(from: defaults)
        let savedMaximumCount = defaults.integer(forKey: Self.historyMaximumCountKey)
        let maximumCount = Self.availableHistoryMaximumCounts.contains(savedMaximumCount)
            ? savedMaximumCount
            : ClipHistory.defaultMaximumCount
        let history = loadedHistory?.limited(to: maximumCount) ?? ClipHistory(maximumCount: maximumCount)

        self.defaults = defaults
        self.pasteEventAuthorization = pasteEventAuthorization
        self.history = history
        self.library = Self.loadAndMigrateLibrary(from: defaults)
        self.isPaused = defaults.object(forKey: pauseKey) as? Bool ?? false

        if loadedHistory?.maximumCount != history.maximumCount ||
            loadedHistory?.clips.count != history.clips.count {
            Self.persist(history, to: defaults)
        }
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

    public func recordClipboardFiles(_ urls: [URL]) {
        guard !isPaused else { return }
        history.recordFiles(urls)
        persistHistory()
    }

    public func togglePause() {
        isPaused.toggle()
        defaults.set(isPaused, forKey: pauseKey)
        showFeedback(FunPasteLocalization.string(isPaused ? "feedback.paused" : "feedback.resumed"))
    }

    public func clearHistory() {
        history = ClipHistory(maximumCount: history.maximumCount)
        persistHistory()
        showFeedback(FunPasteLocalization.string("feedback.historyCleared"))
    }

    public func setHistoryMaximumCount(_ maximumCount: Int) {
        guard Self.availableHistoryMaximumCounts.contains(maximumCount) else { return }
        history = history.limited(to: maximumCount)
        defaults.set(maximumCount, forKey: Self.historyMaximumCountKey)
        persistHistory()
        showFeedback(FunPasteLocalization.format("feedback.historyLimit", maximumCount))
    }

    @discardableResult
    public func refreshFileHistory() -> Bool {
        let didChange = history.refreshFileReferences()
        if didChange { persistHistory() }
        return didChange
    }

    @discardableResult
    public func createLibraryItem(
        category: ClipCategory,
        title: String,
        content: String,
        promptMetadata: PromptMetadata? = nil
    ) -> Clip {
        let item = library.create(
            category: category,
            title: title,
            content: content,
            promptMetadata: promptMetadata
        )
        persistLibrary()
        return item
    }

    public func updateLibraryItem(
        id: Clip.ID,
        title: String,
        content: String,
        promptMetadata: PromptMetadata? = nil
    ) {
        library.update(id: id, title: title, content: content, promptMetadata: promptMetadata)
        persistLibrary()
    }

    public func deleteLibraryItem(id: Clip.ID) {
        library.delete(id: id)
        persistLibrary()
    }

    public func duplicatePrompt(content: String, excludingID: Clip.ID? = nil) -> Clip? {
        library.duplicatePrompt(content: content, excludingID: excludingID)
    }

    public func togglePromptFavorite(id: Clip.ID) {
        library.togglePromptFavorite(id: id)
        persistLibrary()
    }

    public func setPromptArchived(id: Clip.ID, isArchived: Bool) {
        library.setPromptArchived(id: id, isArchived: isArchived)
        persistLibrary()
    }

    public func recordPromptUse(id: Clip.ID) {
        library.recordPromptUse(id: id)
        persistLibrary()
    }

    @discardableResult
    public func pin(_ clip: Clip) -> Clip {
        let item = library.pin(clip)
        persistLibrary()
        return item
    }

    @discardableResult
    public func unpin(_ clip: Clip) -> Bool {
        let didUnpin = library.unpin(clip)
        if didUnpin { persistLibrary() }
        return didUnpin
    }

    public func isPinned(_ clip: Clip) -> Bool {
        library.items.contains { $0.category == .pinned && $0.content == clip.content }
    }

    @discardableResult
    public func copy(_ clip: Clip, to pasteboard: NSPasteboard = .general) -> Bool {
        if let fileURLs = clip.fileURLs, !fileURLs.isEmpty {
            let existingURLs = fileURLs.filter {
                FileManager.default.fileExists(atPath: $0.path)
            }
            if existingURLs.count != fileURLs.count {
                refreshFileHistory()
            }
            guard !existingURLs.isEmpty else {
                showFeedback(FunPasteLocalization.string("feedback.fileMissing"))
                return false
            }
            pasteboard.clearContents()
            let didWrite = pasteboard.writeObjects(existingURLs.map { $0 as NSURL })
            if existingURLs.count < fileURLs.count {
                showFeedback(FunPasteLocalization.string("feedback.someFilesMissing"))
            }
            return didWrite
        }

        pasteboard.clearContents()
        if let imageData = clip.imageData, let image = NSImage(data: imageData) {
            return pasteboard.writeObjects([image])
        }
        return pasteboard.setString(clip.content, forType: .string)
    }

    public func paste(
        _ clip: Clip,
        prepareForPaste: @escaping (@escaping @MainActor () -> Void) -> Void = { completion in completion() }
    ) {
        guard copy(clip) else { return }
        clipboardLogger.notice("已复制待粘贴内容")
        let hadAccessBeforeAttempt = PasteAttemptCoordinator.perform(
            authorization: pasteEventAuthorization,
            prepareForPaste: prepareForPaste
        ) { [weak self] in
            self?.postPasteEvent(for: clip)
        }
        if !hadAccessBeforeAttempt {
            clipboardLogger.notice("预检查未授权，继续发送事件以触发 PostEvent 授权")
        }
    }

    @discardableResult
    public func requestPasteAccessIfNeeded() -> Bool {
        pasteEventAuthorization.requestIfNeeded()
    }

    private func postPasteEvent(for clip: Clip) {
        clipboardLogger.notice("正在发送 Command-V")
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        showFeedback(FunPasteLocalization.format("feedback.pasted", clip.title))
    }

    public func showFeedback(_ message: String) {
        feedbackMessage = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.feedbackMessage = nil
        }
    }

    private func persistHistory() {
        Self.persist(history, to: defaults)
    }

    private func persistLibrary() {
        guard let data = try? JSONEncoder().encode(library) else { return }
        defaults.set(data, forKey: Self.libraryKey)
    }

    private static func loadHistory(from defaults: UserDefaults) -> ClipHistory? {
        guard let data = defaults.data(forKey: historyKey) else { return nil }
        return try? JSONDecoder().decode(ClipHistory.self, from: data)
    }

    private static func persist(_ history: ClipHistory, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private static func loadAndMigrateLibrary(from defaults: UserDefaults) -> ContentLibrary {
        guard let data = defaults.data(forKey: libraryKey),
              var library = try? JSONDecoder().decode(ContentLibrary.self, from: data) else {
            let library = ContentLibrary.seeded
            if let encoded = try? JSONEncoder().encode(library) {
                defaults.set(encoded, forKey: libraryKey)
            }
            defaults.set(currentLibrarySeedVersion, forKey: librarySeedVersionKey)
            return library
        }

        let installedSeedVersion = defaults.integer(forKey: librarySeedVersionKey)
        if installedSeedVersion < 1 {
            let legacyPromptIDs: Set<Clip.ID> = ["development-prompt", "plain-language-prompt"]
            let newTemplates = Clip.builtInPromptTemplates.filter { !legacyPromptIDs.contains($0.id) }
            library.addMissing(newTemplates)
        }

        if installedSeedVersion < 2 {
            let gpt5p6PromptIDs: Set<Clip.ID> = [
                "gpt-5p6-outcome-contract-prompt",
                "gpt-5p6-prompt-audit-prompt",
                "gpt-5p6-grounded-research-prompt"
            ]
            library.addMissing(Clip.builtInPromptTemplates.filter { gpt5p6PromptIDs.contains($0.id) })
        }

        if installedSeedVersion < 3 {
            library.migratePromptMetadata(defaultsByID: ContentLibrary.builtInPromptMetadata)
        }

        if installedSeedVersion < 4 {
            library.formatBuiltInPrompts()
        }

        if installedSeedVersion < currentLibrarySeedVersion,
           let migratedData = try? JSONEncoder().encode(library) {
            defaults.set(migratedData, forKey: libraryKey)
        }

        defaults.set(currentLibrarySeedVersion, forKey: librarySeedVersionKey)
        return library
    }
}
