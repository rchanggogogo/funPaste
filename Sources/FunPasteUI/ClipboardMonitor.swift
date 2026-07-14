import AppKit

@MainActor
public final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    public init(store: ClipboardStore) {
        self.store = store
    }

    public func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if let image = NSImage(pasteboard: pasteboard), let data = image.tiffRepresentation {
            store.recordClipboardImage(data)
        } else if let text = pasteboard.string(forType: .string) {
            store.recordClipboardText(text)
        }
    }
}
