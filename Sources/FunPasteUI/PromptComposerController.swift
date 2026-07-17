import AppKit
import SwiftUI

@MainActor
public final class PromptComposerController: NSObject, NSWindowDelegate {
    public private(set) var isVisible = false

    private var panel: NSPanel?
    private var onWindowClosed: (() -> Void)?

    public func show(
        prompt: Clip,
        onCancel: @escaping () -> Void,
        onCopy: @escaping (Clip) -> Void,
        onPaste: @escaping (Clip) -> Void,
        onWindowClosed: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded()
        self.onWindowClosed = onWindowClosed
        panel.contentView = NSHostingView(
            rootView: PromptComposerView(
                prompt: prompt,
                onCancel: { [weak self] in
                    self?.close()
                    onCancel()
                },
                onCopy: onCopy,
                onPaste: onPaste
            )
        )
        position(panel)
        isVisible = true
        panel.makeKeyAndOrderFront(nil)
    }

    public func close() {
        guard isVisible else { return }
        isVisible = false
        panel?.orderOut(nil)
        onWindowClosed?()
        onWindowClosed = nil
    }

    public func windowWillClose(_ notification: Notification) {
        isVisible = false
        onWindowClosed?()
        onWindowClosed = nil
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = FunPasteLocalization.string("promptComposer.title")
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.minSize = NSSize(width: 600, height: 520)
        panel.delegate = self
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let width = min(720, max(600, frame.width - 40))
        let height = min(760, max(520, frame.height - 40))
        panel.setFrame(
            NSRect(
                x: frame.midX - width / 2,
                y: frame.midY - height / 2,
                width: width,
                height: height
            ),
            display: true
        )
    }
}
