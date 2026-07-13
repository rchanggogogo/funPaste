import AppKit
import SwiftUI

@MainActor
public final class QuickPanelController {
    private let store: ClipboardStore
    private var panel: NSPanel?

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

        panel.orderFrontRegardless()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(
            rootView: RibbonDeckView(store: store, compact: true, dismissPanel: { [weak panel] in
                panel?.orderOut(nil)
            })
        )
        self.panel = panel
        return panel
    }
}
