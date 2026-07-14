import Carbon.HIToolbox
import OSLog

private let shortcutLogger = Logger(subsystem: "com.changlei.funPaste", category: "快捷键")

@MainActor
public final class GlobalShortcut {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public func start() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
                shortcutLogger.notice("收到全局快捷键事件")
                Task { @MainActor in
                    shortcut.action()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            shortcutLogger.error("快捷键事件监听注册失败：\(installStatus)")
            return
        }

        let identifier = EventHotKeyID(signature: OSType(0x46505354), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(shiftKey | cmdKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            shortcutLogger.error("全局快捷键注册失败：\(registerStatus)")
            stop()
        } else {
            shortcutLogger.notice("全局快捷键注册成功")
        }
    }

    public func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
    }
}
