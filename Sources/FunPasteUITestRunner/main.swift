import Foundation
import AppKit
import FunPasteUI

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("测试失败：\(message)")
    }
}

expect(
    Array(ClipCategory.defaultOrder.prefix(2)) == [.recent, .prompt],
    "默认分类必须先展示最近复制，再展示 Prompt"
)

print("通过：默认分类顺序")

expect(
    Clip.demo.first { $0.category == .prompt }?.content.contains("{{功能描述}}") == true,
    "内置开发 Prompt 必须保留功能描述变量"
)

print("通过：Prompt 变量")

expect(
    FunPasteTheme.accentHex == "#FF9F5B",
    "丝带卡组必须使用暖柑橘色作为焦点强调色"
)

print("通过：界面强调色")

var history = ClipHistory(maximumCount: 3)
history.record("第一条")
history.record("第二条")

expect(
    history.clips.map(\.content) == ["第二条", "第一条"],
    "新剪贴内容必须插入历史顶部"
)

print("通过：新内容位于历史顶部")

history.record("第一条")

expect(
    history.clips.map(\.content) == ["第一条", "第二条"],
    "相同内容再次复制时不得产生重复记录，且应回到顶部"
)

print("通过：重复内容去重并置顶")

let countBeforeSensitiveContent = history.clips.count
history.record("password: 极其私密的内容")
history.record("验证码：123456")

expect(
    history.clips.count == countBeforeSensitiveContent,
    "疑似密码和验证码不得自动记录"
)

print("通过：敏感内容自动过滤")

var limitedHistory = ClipHistory(maximumCount: 3)
["一", "二", "三", "四"].forEach { limitedHistory.record($0) }

expect(
    limitedHistory.clips.map(\.content) == ["四", "三", "二"],
    "历史记录必须遵守最大保存数量"
)

print("通过：历史数量上限")

expect(
    ClipHistory().maximumCount == 200,
    "默认剪贴历史最多只能保存 200 条"
)

let migrationSuiteName = "funPaste.tests.history-migration"
let migrationDefaults = UserDefaults(suiteName: migrationSuiteName)!
migrationDefaults.removePersistentDomain(forName: migrationSuiteName)
let legacyClips = (0..<500).map { index in
    Clip(
        id: "legacy-\(index)",
        category: .recent,
        title: "旧记录 \(index)",
        content: "旧内容 \(index)",
        source: "剪贴板"
    )
}
let legacyHistory = ClipHistory(maximumCount: 500, clips: legacyClips)
migrationDefaults.set(try! JSONEncoder().encode(legacyHistory), forKey: "funPaste.history")
let migratedHistoryStore = ClipboardStore(defaults: migrationDefaults)
let reloadedMigratedHistoryStore = ClipboardStore(defaults: migrationDefaults)

expect(
    migratedHistoryStore.history.maximumCount == 200 &&
        migratedHistoryStore.history.clips.count == 200 &&
        reloadedMigratedHistoryStore.history.maximumCount == 200 &&
        reloadedMigratedHistoryStore.history.clips.count == 200,
    "加载旧版历史时必须迁移并裁剪到最近 200 条"
)

migrationDefaults.removePersistentDomain(forName: migrationSuiteName)

print("通过：默认历史上限与旧数据迁移")

let liveHistory = [
    Clip(id: "live", category: .recent, title: "刚复制", content: "真实剪贴内容", source: "剪贴板")
]

expect(
    Clip.presentationItems(history: liveHistory).contains { $0.category == .prompt },
    "开始记录真实历史后，Prompt 模板仍必须保留在内容库中"
)

print("通过：真实历史与 Prompt 模板共存")

var imageHistory = ClipHistory(maximumCount: 3)
let imageData = Data([0x89, 0x50, 0x4E, 0x47])
imageHistory.recordImage(imageData, title: "截图")

expect(
    imageHistory.clips.first?.category == .image,
    "复制图片后必须作为图片项目出现在历史顶部"
)

expect(
    imageHistory.clips.first?.imageData == imageData,
    "图片历史必须保留原始图片数据，以便显示缩略图和再次复制"
)

print("通过：图片剪贴历史")

expect(
    QuickPanelController.hidesOnDeactivate == false &&
        QuickPanelController.usesOutsideClickMonitor == true,
    "可获焦点面板必须保持显示，并由外部点击监听负责收起"
)

print("通过：侧栏通过外部点击自动收起")

expect(
    SelectionNavigator.nextIndex(current: 0, count: 3) == 1 &&
        SelectionNavigator.previousIndex(current: 0, count: 3) == 2,
    "方向键必须在列表首尾循环选择历史项"
)

print("通过：历史方向键选择")

expect(
    QuickPanelController.usesNonactivatingPanel == false,
    "侧栏必须使用可获焦点面板，才能可靠接收键盘输入"
)

print("通过：侧栏使用可获焦点面板")

expect(
    QuickPanelController.usesLocalKeyMonitor == true,
    "面板显示时必须在应用内部优先处理 Enter、方向键、Tab 和 Esc"
)

print("通过：侧栏使用应用内按键监听")

expect(
    QuickPanelController.requiresApplicationActivation == true,
    "显示侧栏时必须激活 funPaste，才能可靠接收键盘输入"
)

print("通过：侧栏激活后接收键盘焦点")

expect(
    QuickPanelController.panelActivationPolicy == .accessory &&
        QuickPanelController.restingActivationPolicy == .accessory,
    "funPaste 打开和收起侧栏时都必须保持后台工具策略，不能显示 Dock 图标"
)

print("通过：侧栏始终保持后台工具策略")

var pasteTarget = PasteTargetState()
pasteTarget.remember(processIdentifier: 101, ownProcessIdentifier: 99)
pasteTarget.remember(processIdentifier: 99, ownProcessIdentifier: 99)
expect(
    pasteTarget.processIdentifier == 101 &&
        pasteTarget.isFrontmost(processIdentifier: 101) &&
        !pasteTarget.isFrontmost(processIdentifier: 99),
    "粘贴目标必须保留最后一个非 funPaste 的前台应用，并只在它恢复前台后粘贴"
)

print("通过：粘贴目标焦点恢复")

var pasteAccessRequestCount = 0
let deniedPasteAuthorization = PasteEventAuthorization(
    preflight: { false },
    request: {
        pasteAccessRequestCount += 1
        return false
    }
)
expect(
    deniedPasteAuthorization.requestIfNeeded() == false && pasteAccessRequestCount == 1,
    "缺少跨应用粘贴权限时必须主动请求系统授权"
)

let grantedPasteAuthorization = PasteEventAuthorization(
    preflight: { true },
    request: {
        pasteAccessRequestCount += 1
        return false
    }
)
expect(
    grantedPasteAuthorization.requestIfNeeded() == true && pasteAccessRequestCount == 1,
    "已有跨应用粘贴权限时不得重复请求授权"
)

print("通过：跨应用粘贴权限请求策略")

var fallbackPasteAccessRequestCount = 0
let fallbackPasteAuthorization = PasteEventAuthorization(
    preflight: { false },
    request: { false },
    fallbackPreflight: { false },
    fallbackRequest: {
        fallbackPasteAccessRequestCount += 1
        return true
    }
)
expect(
    fallbackPasteAuthorization.requestIfNeeded() && fallbackPasteAccessRequestCount == 1,
    "PostEvent 请求无效时必须改用完整辅助功能授权请求"
)

print("通过：完整辅助功能备用授权")

var didPrepareDeniedPaste = false
var didPostDeniedPaste = false
PasteAttemptCoordinator.perform(
    authorization: PasteEventAuthorization(preflight: { false }, request: { false }),
    prepareForPaste: { completion in
        didPrepareDeniedPaste = true
        completion()
    },
    postPasteEvent: {
        didPostDeniedPaste = true
    }
)
expect(
    didPrepareDeniedPaste && didPostDeniedPaste,
    "预检查未授权时也必须实际尝试发送粘贴事件，让 macOS 处理 PostEvent 授权"
)

print("通过：未授权时仍尝试发送粘贴事件")

var focusRestorationSteps: [String] = []
PasteFocusRestorer.restore(
    deactivateApplication: { focusRestorationSteps.append("退出前台") },
    enterBackgroundMode: { focusRestorationSteps.append("恢复后台") },
    scheduleTargetActivation: { activation in
        focusRestorationSteps.append("等待切换")
        activation()
    },
    activateTarget: { focusRestorationSteps.append("激活目标") }
)
expect(
    focusRestorationSteps == ["退出前台", "恢复后台", "等待切换", "激活目标"],
    "粘贴前必须先让 funPaste 退出前台，再异步激活原输入应用"
)

print("通过：粘贴焦点恢复顺序")

expect(
    PanelKeyCommand(keyCode: 53) == .dismiss &&
        PanelKeyCommand(keyCode: 126) == .selectPrevious &&
        PanelKeyCommand(keyCode: 125) == .selectNext &&
        PanelKeyCommand(keyCode: 36) == .paste,
    "Esc、上下键和回车必须在原生窗口层映射为侧栏操作"
)

print("通过：原生键盘命令映射")

expect(
    CategoryNavigator.next(after: .file) == .recent &&
        CategoryNavigator.previous(before: .recent) == .file,
    "Tab 必须在分类栏首尾循环切换"
)

print("通过：分类 Tab 循环")

expect(
    QuickPanelController.defaultCategoryOnOpen == .recent,
    "每次打开侧栏必须先展示最近复制"
)

print("通过：打开侧栏默认最近复制")

expect(
    RibbonDeckView.newLibraryItemButtonHitSize >= 36,
    "新建 Prompt 按钮必须提供完整且易点击的命中区域"
)

var libraryEditorState = LibraryEditorState()
libraryEditorState.startCreating(category: .prompt)
libraryEditorState.title = "未保存标题"
libraryEditorState.content = "未保存内容"
libraryEditorState.resetForPanelOpening()

expect(
    !libraryEditorState.isPresented &&
        libraryEditorState.editingItem == nil &&
        libraryEditorState.title.isEmpty &&
        libraryEditorState.content.isEmpty,
    "重新打开面板时必须关闭并清空未保存的新建窗口"
)

print("通过：新建按钮命中区域与面板重开状态")

var library = ContentLibrary.seeded
expect(
    library.items.contains { $0.id == "development-prompt" } &&
        library.items.contains { $0.id == "pinned-address" },
    "首次内容库必须包含当前内置 Prompt 与收藏"
)

let createdPrompt = library.create(category: .prompt, title: "测试 Prompt", content: "请解释 {{内容}}")
expect(
    library.items.contains { $0.id == createdPrompt.id },
    "新建 Prompt 必须进入内容库"
)

library.update(id: createdPrompt.id, title: "已编辑 Prompt", content: "编辑后的内容")
expect(
    library.items.first { $0.id == createdPrompt.id }?.title == "已编辑 Prompt",
    "Prompt 编辑必须保存新标题"
)

library.delete(id: "development-prompt")
expect(
    !library.items.contains { $0.id == "development-prompt" },
    "内置 Prompt 也必须允许永久删除"
)

let recentClip = Clip(id: "recent-pin", category: .recent, title: "可收藏内容", content: "一键收藏的文本", source: "剪贴板")
let firstPin = library.pin(recentClip)
let secondPin = library.pin(recentClip)
let matchingPins = library.items.filter { $0.category == .pinned && $0.content == recentClip.content }
expect(
    firstPin.id == secondPin.id && matchingPins.count == 1,
    "同一最近复制内容只能收藏一次"
)

library.unpin(recentClip)
expect(
    !library.items.contains { $0.category == .pinned && $0.content == recentClip.content },
    "再次点击已收藏内容必须取消收藏，但不删除原始历史"
)

print("通过：内容库 CRUD 与一键收藏")

let librarySuiteName = "funPaste.tests.library"
let libraryDefaults = UserDefaults(suiteName: librarySuiteName)!
libraryDefaults.removePersistentDomain(forName: librarySuiteName)
let libraryStore = ClipboardStore(defaults: libraryDefaults)
let persistedPrompt = libraryStore.createLibraryItem(category: .prompt, title: "持久化 Prompt", content: "重启后仍存在")
let reloadedLibraryStore = ClipboardStore(defaults: libraryDefaults)
expect(
    reloadedLibraryStore.library.items.contains { $0.id == persistedPrompt.id },
    "新建 Prompt 必须在重新加载 Store 后保留"
)

let persistedPin = libraryStore.pin(recentClip)
let repeatedPersistedPin = libraryStore.pin(recentClip)
let reloadedAfterPin = ClipboardStore(defaults: libraryDefaults)
expect(
    persistedPin.id == repeatedPersistedPin.id &&
        reloadedAfterPin.library.items.filter { $0.category == .pinned && $0.content == recentClip.content }.count == 1,
    "Store 一键收藏必须持久化且不得重复"
)

print("通过：内容库本地持久化")
