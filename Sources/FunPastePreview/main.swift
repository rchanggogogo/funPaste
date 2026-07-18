import SwiftUI
import FunPasteUI

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    let store = ClipboardStore()
    private var monitor: ClipboardMonitor?
    private var panelController: QuickPanelController?
    private var shortcut: GlobalShortcut?
    private var activationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let monitor = ClipboardMonitor(store: store)
        monitor.start()
        self.monitor = monitor

        let panelController = QuickPanelController(store: store)
        self.panelController = panelController

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak panelController] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                panelController?.rememberPasteTarget(application)
            }
        }

        let shortcut = GlobalShortcut { [weak panelController] in
            panelController?.toggle()
        }
        shortcut.start()
        self.shortcut = shortcut

        Task { @MainActor [weak store] in
            try? await Task.sleep(for: .milliseconds(500))
            store?.requestPasteAccessIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        shortcut?.stop()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
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
            Button(FunPasteLocalization.string("menu.show")) {
                appDelegate.togglePanel()
            }
            Button(FunPasteLocalization.string(appDelegate.store.isPaused ? "menu.resume" : "menu.pause")) {
                appDelegate.store.togglePause()
            }
            Divider()
            Button(FunPasteLocalization.string("menu.clear")) {
                appDelegate.store.clearHistory()
            }
            Divider()
            Button(FunPasteLocalization.string("menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
