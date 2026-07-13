import AppKit
import SwiftUI

@MainActor
public final class QuickPanelController {
    public static let hidesOnDeactivate = true
    public static let usesNonactivatingPanel = false
    public static let requiresApplicationActivation = true

    private let store: ClipboardStore
    private var panel: NSPanel?
    private var previousApplication: NSRunningApplication?

    public init(store: ClipboardStore) {
        self.store = store
    }

    public func toggle() {
        if panel?.isVisible == true {
            panel?.orderOut(nil)
        } else {
            show()
        }
    }

    public func show() {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = frontmostApplication
        }

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
            NSApp.setActivationPolicy(.regular)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func dismiss() {
        panel?.orderOut(nil)
        previousApplication?.activate()
        if Self.requiresApplicationActivation {
            NSApp.setActivationPolicy(.accessory)
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
            }, prepareForPaste: { [weak self] in
                self?.dismiss()
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
