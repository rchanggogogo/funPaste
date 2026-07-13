import Foundation
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
    QuickPanelController.hidesOnDeactivate == true,
    "点击其他区域导致应用失焦时，侧栏必须自动收起"
)

print("通过：侧栏失焦时自动收起")

expect(
    SelectionNavigator.nextIndex(current: 0, count: 3) == 1 &&
        SelectionNavigator.previousIndex(current: 0, count: 3) == 2,
    "方向键必须在列表首尾循环选择历史项"
)

print("通过：历史方向键选择")

expect(
    QuickPanelController.usesNonactivatingPanel == false,
    "需要键盘输入和 SwiftUI 按钮交互的侧栏不能使用非激活窗口"
)

print("通过：侧栏允许完整交互")

expect(
    QuickPanelController.requiresApplicationActivation == true,
    "显示侧栏时必须让 funPaste 成为前台应用，键盘事件才会进入侧栏"
)

print("通过：侧栏会获得系统键盘焦点")

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
