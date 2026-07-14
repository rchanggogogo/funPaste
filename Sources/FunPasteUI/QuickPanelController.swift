import AppKit
import SwiftUI

@MainActor
public final class QuickPanelController {
    public static let hidesOnDeactivate = true
    public static let usesNonactivatingPanel = false
    public static let requiresApplicationActivation = true
    public static let panelActivationPolicy: NSApplication.ActivationPolicy = .accessory
    public static let defaultCategoryOnOpen: ClipCategory = .recent

    private let store: ClipboardStore
    private var panel: NSPanel?
    private var pasteTargetApplication: NSRunningApplication?
    private var pasteTargetState = PasteTargetState()

    public init(store: ClipboardStore) {
        self.store = store
    }

    public func toggle() {
        if panel?.isVisible == true {
            dismiss()
        } else {
            show()
        }
    }

    public func show() {
        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)

        let panel = makePanelIfNeeded()
        let panelSize = NSSize(width: 420, height: 640)
        panel.setContentSize(panelSize)

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let screen {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(
                NSPoint(
                    x: frame.maxX - panelSize.width - 18,
                    y: frame.midY - panelSize.height / 2
                )
            )
        }

        if Self.requiresApplicationActivation {
            NSApp.setActivationPolicy(Self.panelActivationPolicy)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .funPastePanelDidShow, object: nil)
    }

    public func dismiss() {
        panel?.orderOut(nil)
        pasteTargetApplication?.activate()
        if Self.requiresApplicationActivation {
            NSApp.setActivationPolicy(Self.panelActivationPolicy)
        }
    }

    public func rememberPasteTarget(_ application: NSRunningApplication?) {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard let application, application.processIdentifier != ownProcessIdentifier else { return }
        pasteTargetApplication = application
        pasteTargetState.remember(
            processIdentifier: application.processIdentifier,
            ownProcessIdentifier: ownProcessIdentifier
        )
    }

    private func prepareForPaste(_ completion: @escaping @MainActor () -> Void) {
        panel?.orderOut(nil)
        guard let target = pasteTargetApplication, !target.isTerminated else {
            store.showFeedback("已复制，请手动粘贴")
            return
        }

        target.activate()
        waitForPasteTarget(attemptsRemaining: 50, completion: completion)
    }

    private func waitForPasteTarget(
        attemptsRemaining: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        if pasteTargetState.isFrontmost(
            processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier
        ) {
            completion()
            return
        }

        guard attemptsRemaining > 0 else {
            store.showFeedback("已复制，请手动粘贴")
            return
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(20))
            self?.waitForPasteTarget(attemptsRemaining: attemptsRemaining - 1, completion: completion)
        }
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = Self.hidesOnDeactivate
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onKeyCommand = { [weak self] command in
            if command == .dismiss {
                self?.dismiss()
            } else {
                NotificationCenter.default.post(name: .funPastePanelKeyCommand, object: command)
            }
        }
        panel.contentView = NSHostingView(
            rootView: RibbonDeckView(store: store, compact: true, dismissPanel: { [weak self] in
                self?.dismiss()
            }, prepareForPaste: { [weak self] completion in
                self?.prepareForPaste(completion)
            })
        )
        self.panel = panel
        return panel
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    var onKeyCommand: ((PanelKeyCommand) -> Void)?

    override func keyDown(with event: NSEvent) {
        if let command = PanelKeyCommand(
            keyCode: event.keyCode,
            shiftPressed: event.modifierFlags.contains(.shift)
        ) {
            onKeyCommand?(command)
        } else {
            super.keyDown(with: event)
        }
    }
}
