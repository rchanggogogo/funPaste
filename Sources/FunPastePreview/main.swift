import SwiftUI
import FunPasteUI

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    let store = ClipboardStore()
    private var monitor: ClipboardMonitor?
    private var panelController: QuickPanelController?
    private var shortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let monitor = ClipboardMonitor(store: store)
        monitor.start()
        self.monitor = monitor

        let panelController = QuickPanelController(store: store)
        self.panelController = panelController

        let shortcut = GlobalShortcut { [weak panelController] in
            panelController?.toggle()
        }
        shortcut.start()
        self.shortcut = shortcut
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        shortcut?.stop()
    }

    func togglePanel() {
        panelController?.toggle()
    }
}

@main
struct FunPastePreview: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("funPaste", systemImage: "square.on.square.intersection.dashed") {
            Button("显示 funPaste") {
                appDelegate.togglePanel()
            }
            Button(appDelegate.store.isPaused ? "恢复记录剪贴板" : "暂停记录剪贴板") {
                appDelegate.store.togglePause()
            }
            Divider()
            Button("清空剪贴历史") {
                appDelegate.store.clearHistory()
            }
            Divider()
            Button("退出 funPaste") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
