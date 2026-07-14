import AppKit
import OSLog
import SwiftUI

private let panelLogger = Logger(subsystem: "com.changlei.funPaste", category: "面板")

@MainActor
public final class QuickPanelController {
    public static let hidesOnDeactivate = false
    public static let usesOutsideClickMonitor = true
    public static let usesNonactivatingPanel = false
    public static let usesLocalKeyMonitor = true
    public static let requiresApplicationActivation = true
    public static let panelActivationPolicy: NSApplication.ActivationPolicy = .regular
    public static let restingActivationPolicy: NSApplication.ActivationPolicy = .accessory
    public static let defaultCategoryOnOpen: ClipCategory = .recent

    private let store: ClipboardStore
    private var panel: NSPanel?
    private var pasteTargetApplication: NSRunningApplication?
    private var pasteTargetState = PasteTargetState()
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var isWaitingToPresent = false

    public init(store: ClipboardStore) {
        self.store = store
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.presentPanelAfterActivation()
            }
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismissIfClickedOutsidePanel()
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.panel?.isVisible == true,
                let command = PanelKeyCommand(
                    keyCode: event.keyCode,
                    shiftPressed: event.modifierFlags.contains(.shift)
                )
            else {
                return event
            }

            self.handlePanelKeyCommand(command)
            return nil
        }
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
        panelLogger.notice("开始显示面板，目标进程：\(self.pasteTargetState.processIdentifier ?? -1)")

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

        isWaitingToPresent = true
        if Self.requiresApplicationActivation {
            NSApp.setActivationPolicy(Self.panelActivationPolicy)
            NSRunningApplication.current.activate()
        }

        if NSApp.isActive {
            presentPanelAfterActivation()
        } else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                self?.presentPanelAfterActivation()
            }
        }
    }

    public func dismiss() {
        isWaitingToPresent = false
        panel?.orderOut(nil)
        if Self.requiresApplicationActivation {
            NSApp.setActivationPolicy(Self.restingActivationPolicy)
        }
        pasteTargetApplication?.activate()
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

    private func dismissIfClickedOutsidePanel() {
        guard let panel, panel.isVisible, !panel.frame.contains(NSEvent.mouseLocation) else { return }
        dismiss()
    }

    private func prepareForPaste(_ completion: @escaping @MainActor () -> Void) {
        isWaitingToPresent = false
        panel?.orderOut(nil)
        guard let target = pasteTargetApplication, !target.isTerminated else {
            panelLogger.error("没有可恢复的粘贴目标")
            store.showFeedback("已复制，请手动粘贴")
            return
        }

        PasteFocusRestorer.restore(
            deactivateApplication: {
                NSApp.deactivate()
            },
            enterBackgroundMode: {
                if Self.requiresApplicationActivation {
                    NSApp.setActivationPolicy(Self.restingActivationPolicy)
                }
            },
            scheduleTargetActivation: { activation in
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    activation()
                }
            },
            activateTarget: { [weak self] in
                panelLogger.notice("开始恢复粘贴目标：\(target.processIdentifier)")
                target.activate()
                self?.waitForPasteTarget(attemptsRemaining: 50, completion: completion)
            }
        )
    }

    private func waitForPasteTarget(
        attemptsRemaining: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        if pasteTargetState.isFrontmost(
            processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier
        ) {
            panelLogger.notice("粘贴目标已恢复前台")
            completion()
            return
        }

        guard attemptsRemaining > 0 else {
            panelLogger.error("粘贴目标未在限定时间内恢复前台")
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
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = Self.hidesOnDeactivate
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onKeyCommand = { [weak self] command in
            self?.handlePanelKeyCommand(command)
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

    private func presentPanelAfterActivation() {
        guard isWaitingToPresent, let panel else { return }
        isWaitingToPresent = false
        panel.makeKeyAndOrderFront(nil)
        panelLogger.notice("面板已成为键盘窗口：\(panel.isKeyWindow)")
        NotificationCenter.default.post(name: .funPastePanelDidShow, object: nil)
    }

    private func handlePanelKeyCommand(_ command: PanelKeyCommand) {
        if command == .dismiss {
            dismiss()
        } else {
            NotificationCenter.default.post(name: .funPastePanelKeyCommand, object: command)
        }
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
