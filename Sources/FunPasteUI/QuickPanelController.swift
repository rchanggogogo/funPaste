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
    public static let panelActivationPolicy: NSApplication.ActivationPolicy = .accessory
    public static let restingActivationPolicy: NSApplication.ActivationPolicy = .accessory
    public static let defaultCategoryOnOpen: ClipCategory = .recent
    public static let pasteActivationDelayMilliseconds = 16
    public static let pasteTargetActivationRetryInterval = 5
    public static let pasteFadeDuration: TimeInterval = 0.08

    public static func panelSize(for visibleFrame: NSRect) -> NSSize {
        let inset: CGFloat = 18
        let width = min(420, max(0, visibleFrame.width - inset * 2))
        let desiredHeight = visibleFrame.height - inset * 2
        let height = min(visibleFrame.height, max(520, desiredHeight))
        return NSSize(width: width, height: height)
    }

    private let store: ClipboardStore
    private let promptComposerController: PromptComposerController
    private var panel: NSPanel?
    private var pasteTargetApplication: NSRunningApplication?
    private var pasteTargetState = PasteTargetState()
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private weak var internalPasteTextView: NSTextView?
    private var isSelectingHistoryForPromptEditor = false
    private var isWaitingToPresent = false
    private var presentationActivationAttempts = 0
    private var pendingPanelOrderOutTask: Task<Void, Never>?

    public init(store: ClipboardStore) {
        self.store = store
        self.promptComposerController = PromptComposerController()
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
            if [UInt16(123), UInt16(124)].contains(event.keyCode),
               self?.panel?.firstResponder is NSTextView {
                return event
            }
            guard
                let self,
                self.panel?.isKeyWindow == true,
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
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.panel {
                self.rememberFocusedInternalTextTarget()
            }
            return event
        }
    }

    public func toggle() {
        if promptComposerController.isVisible, panel?.isKeyWindow != true {
            showPasteHistoryForPromptEditor()
        } else if panel?.isVisible == true {
            dismiss()
        } else {
            show()
        }
    }

    public func show() {
        isSelectingHistoryForPromptEditor = false
        showPanel()
    }

    private func showPanel() {
        rememberFocusedInternalTextTarget()
        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)
        panelLogger.notice("开始显示面板，目标进程：\(self.pasteTargetState.processIdentifier ?? -1)")

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let panel = makePanelIfNeeded()
        pendingPanelOrderOutTask?.cancel()
        pendingPanelOrderOutTask = nil
        panel.alphaValue = 1
        if let screen {
            let frame = screen.visibleFrame
            let panelSize = Self.panelSize(for: frame)
            panel.setContentSize(panelSize)
            panel.setFrameOrigin(
                NSPoint(
                    x: frame.maxX - panelSize.width - 18,
                    y: frame.midY - panelSize.height / 2
                )
            )
        }

        isWaitingToPresent = true
        presentationActivationAttempts = 0
        if Self.requiresApplicationActivation {
            NSApp.setActivationPolicy(Self.panelActivationPolicy)
            requestApplicationActivation()
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
        if internalPasteTextView?.window !== panel, restoreInternalPasteTarget() {
            isSelectingHistoryForPromptEditor = false
            pendingPanelOrderOutTask?.cancel()
            pendingPanelOrderOutTask = nil
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            return
        }
        isSelectingHistoryForPromptEditor = false
        internalPasteTextView = nil
        promptComposerController.close()
        pendingPanelOrderOutTask?.cancel()
        pendingPanelOrderOutTask = nil
        panel?.orderOut(nil)
        panel?.alphaValue = 1
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
        guard !promptComposerController.isVisible else { return }
        guard let panel, panel.isVisible, !panel.frame.contains(NSEvent.mouseLocation) else { return }
        dismiss()
    }

    private func prepareForPaste(_ completion: @escaping @MainActor () -> Void) {
        isWaitingToPresent = false
        internalPasteTextView = nil
        promptComposerController.close(
            behavior: .prepareForPaste,
            fadeDuration: Self.pasteFadeDuration
        )
        fadeOutPanelForPaste()
        guard let target = pasteTargetApplication, !target.isTerminated else {
            panelLogger.error("没有可恢复的粘贴目标")
            store.showFeedback(FunPasteLocalization.string("feedback.copiedManualPaste"))
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
                    try? await Task.sleep(for: .milliseconds(Self.pasteActivationDelayMilliseconds))
                    activation()
                }
            },
            activateTarget: { [weak self] in
                panelLogger.notice("开始恢复粘贴目标：\(target.processIdentifier)")
                self?.waitForPasteTarget(attemptsRemaining: 50, completion: completion)
            }
        )
    }

    private func rememberFocusedInternalTextTarget() {
        if let textView = promptComposerController.focusedEditableTextView() {
            internalPasteTextView = textView
        }
    }

    @discardableResult
    private func restoreInternalPasteTarget() -> Bool {
        guard let textView = internalPasteTextView,
              textView.isEditable,
              let targetWindow = textView.window,
              targetWindow.isVisible
        else {
            internalPasteTextView = nil
            return false
        }
        internalPasteTextView = nil
        targetWindow.makeKeyAndOrderFront(nil)
        return targetWindow.makeFirstResponder(textView)
    }

    private func waitForPasteTarget(
        attemptsRemaining: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        let isFrontmost = pasteTargetState.isFrontmost(
            processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier
        )
        switch PasteTargetActivationCoordinator.nextAction(
            isFrontmost: isFrontmost,
            attemptsRemaining: attemptsRemaining,
            retryInterval: Self.pasteTargetActivationRetryInterval
        ) {
        case .paste:
            panelLogger.notice("粘贴目标已恢复前台")
            completion()
        case .fail:
            panelLogger.error("粘贴目标未在限定时间内恢复前台")
            store.showFeedback(FunPasteLocalization.string("feedback.copiedManualPaste"))
        case .retryActivation:
            pasteTargetApplication?.activate()
            schedulePasteTargetCheck(attemptsRemaining: attemptsRemaining - 1, completion: completion)
        case .wait:
            schedulePasteTargetCheck(attemptsRemaining: attemptsRemaining - 1, completion: completion)
        }
    }

    private func schedulePasteTargetCheck(
        attemptsRemaining: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(20))
            self?.waitForPasteTarget(attemptsRemaining: attemptsRemaining, completion: completion)
        }
    }

    private func fadeOutPanelForPaste() {
        guard let panel else { return }
        pendingPanelOrderOutTask?.cancel()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.pasteFadeDuration
            panel.animator().alphaValue = 0
        }
        pendingPanelOrderOutTask = Task { @MainActor [weak self, weak panel] in
            try? await Task.sleep(for: .milliseconds(Int(Self.pasteFadeDuration * 1_000)))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self?.pendingPanelOrderOutTask = nil
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
            }, pasteClip: { [weak self] clip in
                self?.pasteFromPanel(clip)
            }, prepareForPaste: { [weak self] completion in
                self?.prepareForPaste(completion)
            }, onUsePrompt: { [weak self] prompt in
                self?.showPromptComposer(prompt)
            })
        )
        self.panel = panel
        return panel
    }

    private func showPromptComposer(_ prompt: Clip) {
        promptComposerController.show(
            prompt: prompt,
            onCancel: {},
            onShowHistory: { [weak self] in
                self?.showPasteHistoryForPromptEditor()
            },
            onCopy: { [weak self] preparedPrompt in
                guard let self else { return }
                self.store.copy(preparedPrompt)
                self.store.recordPromptUse(id: prompt.id)
                self.promptComposerController.close()
                self.dismiss()
            },
            onPaste: { [weak self] preparedPrompt in
                guard let self else { return }
                self.internalPasteTextView = nil
                self.promptComposerController.close(
                    behavior: .prepareForPaste,
                    fadeDuration: Self.pasteFadeDuration
                )
                self.store.paste(
                    preparedPrompt,
                    onPasteEventPosted: { [weak self] in
                        self?.store.recordPromptUse(id: prompt.id)
                    }
                ) { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    self.prepareForPaste(completion)
                }
            },
            onWindowClosed: { [weak self] in
                self?.panel?.makeKeyAndOrderFront(nil)
            }
        )
    }

    private func showPasteHistoryForPromptEditor() {
        rememberFocusedInternalTextTarget()
        isSelectingHistoryForPromptEditor = true
        panelLogger.notice("进入 Prompt 历史插入模式")
        showPanel()
    }

    private func pasteFromPanel(_ clip: Clip) {
        guard isSelectingHistoryForPromptEditor else {
            panelLogger.notice("使用普通外部粘贴路径")
            store.paste(clip, prepareForPaste: { [weak self] completion in
                self?.prepareForPaste(completion)
            })
            return
        }

        let hasInternalEditor = internalPasteTextView?.isEditable == true &&
            internalPasteTextView?.window?.isVisible == true
        guard hasInternalEditor, let textView = internalPasteTextView else {
            panelLogger.error("Prompt 编辑框已失效，取消历史插入")
            store.showFeedback(FunPasteLocalization.string("feedback.promptEditorUnavailable"))
            return
        }

        let targetWindow = textView.window
        let replacementRange = textView.selectedRange()
        let didPaste = InternalPasteCoordinator.perform(
            restoreEditor: { [weak self] in
                guard let self else { return false }
                if targetWindow !== self.panel {
                    self.pendingPanelOrderOutTask?.cancel()
                    self.pendingPanelOrderOutTask = nil
                    self.panel?.orderOut(nil)
                    self.panel?.alphaValue = 1
                }
                return self.restoreInternalPasteTarget()
            },
            insert: { [weak self] in
                self?.promptComposerController.insertHistoryContent(
                    clip.content,
                    replacementRange: replacementRange
                ) == true
            }
        )
        if didPaste {
            isSelectingHistoryForPromptEditor = false
            panelLogger.notice("Prompt 历史内容已同步插入")
            store.showFeedback(FunPasteLocalization.format("feedback.pasted", clip.title))
        } else {
            isSelectingHistoryForPromptEditor = false
            panelLogger.error("Prompt 编辑框恢复失败")
            store.showFeedback(FunPasteLocalization.string("feedback.promptEditorUnavailable"))
        }
    }

    private func presentPanelAfterActivation() {
        guard isWaitingToPresent, let panel else { return }
        if Self.requiresApplicationActivation, !NSApp.isActive, presentationActivationAttempts < 10 {
            presentationActivationAttempts += 1
            requestApplicationActivation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(50))
                self?.presentPanelAfterActivation()
            }
            return
        }
        isWaitingToPresent = false
        panel.makeKeyAndOrderFront(nil)
        panelLogger.notice("面板已成为键盘窗口：\(panel.isKeyWindow)")
        NotificationCenter.default.post(
            name: .funPastePanelDidShow,
            object: isSelectingHistoryForPromptEditor
        )
    }

    private func requestApplicationActivation() {
        NSApp.activate()
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
