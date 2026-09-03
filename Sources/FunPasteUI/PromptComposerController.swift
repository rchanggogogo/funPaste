import AppKit
import SwiftUI

public enum PromptComposerCloseBehavior: Sendable {
    case returnToPanel
    case prepareForPaste

    public var restoresParentPanel: Bool {
        self == .returnToPanel
    }
}

@MainActor
public final class PromptComposerController: NSObject, NSWindowDelegate {
    public private(set) var isVisible = false

    private var panel: NSPanel?
    private var session: PromptComposerSession?
    private var onWindowClosed: (() -> Void)?
    private var pendingOrderOutTask: Task<Void, Never>?

    public func show(
        prompt: Clip,
        onCancel: @escaping () -> Void,
        onShowHistory: @escaping () -> Void,
        onCopy: @escaping (Clip) -> Void,
        onPaste: @escaping (Clip) -> Void,
        onWindowClosed: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded()
        pendingOrderOutTask?.cancel()
        pendingOrderOutTask = nil
        panel.alphaValue = 1
        self.onWindowClosed = onWindowClosed
        let session = PromptComposerSession(prompt: prompt)
        self.session = session
        panel.contentView = NSHostingView(
            rootView: PromptComposerView(
                session: session,
                onCancel: { [weak self] in
                    self?.close()
                    onCancel()
                },
                onShowHistory: onShowHistory,
                onCopy: onCopy,
                onPaste: onPaste
            )
        )
        position(panel)
        isVisible = true
        panel.makeKeyAndOrderFront(nil)
    }

    public func close(
        behavior: PromptComposerCloseBehavior = .returnToPanel,
        fadeDuration: TimeInterval = 0
    ) {
        guard isVisible else { return }
        isVisible = false
        orderOutPanel(fadeDuration: fadeDuration)
        let onWindowClosed = onWindowClosed
        self.onWindowClosed = nil
        if behavior.restoresParentPanel {
            onWindowClosed?()
        }
    }

    public func windowWillClose(_ notification: Notification) {
        isVisible = false
        onWindowClosed?()
        onWindowClosed = nil
    }

    public func focusedEditableTextView() -> NSTextView? {
        guard isVisible,
              let textView = panel?.firstResponder as? NSTextView,
              textView.isEditable
        else {
            return nil
        }
        return textView
    }

    @discardableResult
    public func insertHistoryContent(_ content: String, replacementRange: NSRange) -> Bool {
        session?.insert(content, replacementRange: replacementRange) == true
    }

    private func orderOutPanel(fadeDuration: TimeInterval) {
        guard let panel else { return }
        pendingOrderOutTask?.cancel()
        guard fadeDuration > 0 else {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            panel.animator().alphaValue = 0
        }
        pendingOrderOutTask = Task { @MainActor [weak self, weak panel] in
            try? await Task.sleep(for: .milliseconds(Int(fadeDuration * 1_000)))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self?.pendingOrderOutTask = nil
        }
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
