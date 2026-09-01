import Foundation
import AppKit
import FunPasteUI

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("测试失败：\(message)")
    }
}

expect(
    FunPasteLanguage.preferred(from: ["zh-Hans-CN"]) == .simplifiedChinese &&
        FunPasteLanguage.preferred(from: ["en-US"]) == .english &&
        FunPasteLanguage.preferred(from: ["fr-FR"]) == .english &&
        FunPasteLocalization.hasCompleteTranslations &&
        FunPasteLocalization.string("menu.show", language: .english) == "Show funPaste" &&
        FunPasteLocalization.string("menu.show", language: .simplifiedChinese) == "显示 funPaste" &&
        FunPasteLocalization.string("prompt.plainLanguage.content", language: .english).contains("\n\n") &&
        FunPasteLocalization.string("prompt.plainLanguage.content", language: .simplifiedChinese).contains("\n\n"),
    "本地化必须按系统首选语言选择简体中文，并为其他语言回退英文"
)

let englishPrompt = Clip(
    id: "english-prompt-test",
    category: .prompt,
    title: "English prompt",
    content: FunPasteLocalization.string("prompt.development.content", language: .english),
    source: "Test"
)
var englishPromptState = PromptComposerState(prompt: englishPrompt)
englishPromptState.featureDescription = "English goal"
englishPromptState.technicalConstraint = "Keep the public API"
expect(
    englishPromptState.requiresFeatureDescription &&
        englishPromptState.requiresTechnicalConstraint &&
        englishPromptState.canSubmit &&
        !englishPromptState.resolvedContent.contains("{{"),
    "英文 Prompt 必须识别并替换英文变量"
)

print("通过：系统语言选择与双语 Prompt")

@MainActor
final class LaunchAtLoginServiceSpy: LaunchAtLoginServicing {
    var state: LaunchAtLoginState = .disabled
    var registrationCount = 0
    var unregistrationCount = 0
    var systemSettingsOpenCount = 0

    func register() {
        registrationCount += 1
        state = .enabled
    }

    func unregister() {
        unregistrationCount += 1
        state = .disabled
    }

    func openSystemSettings() {
        systemSettingsOpenCount += 1
    }
}

let launchAtLoginService = LaunchAtLoginServiceSpy()
let launchAtLoginController = LaunchAtLoginController(service: launchAtLoginService)
launchAtLoginController.setEnabled(true)
expect(
    launchAtLoginController.state == .enabled &&
        launchAtLoginController.state.isEnabled &&
        launchAtLoginService.registrationCount == 1,
    "用户启用开机自启动时必须注册主应用登录项"
)
launchAtLoginController.setEnabled(false)
expect(
    launchAtLoginController.state == .disabled &&
        !launchAtLoginController.state.isEnabled &&
        launchAtLoginService.unregistrationCount == 1,
    "用户关闭开机自启动时必须注销主应用登录项"
)
launchAtLoginService.state = .requiresApproval
launchAtLoginController.refresh()
launchAtLoginController.openSystemSettings()
expect(
    launchAtLoginController.state == .requiresApproval &&
        launchAtLoginService.systemSettingsOpenCount == 1,
    "系统要求批准登录项时必须提示用户并可打开对应的系统设置"
)

print("通过：开机自启动设置")

let launchAgentTestDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("funPaste-launch-agent-tests-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: launchAgentTestDirectory) }
let launchAgentAppURL = launchAgentTestDirectory
    .appendingPathComponent("Applications/funPaste.app", isDirectory: true)
let launchAgentsDirectory = launchAgentTestDirectory
    .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
let userLaunchAgentService = UserLaunchAgentService(
    appURL: launchAgentAppURL,
    launchAgentsDirectory: launchAgentsDirectory
)
try! userLaunchAgentService.register()

let launchAgentURL = launchAgentsDirectory
    .appendingPathComponent("\(UserLaunchAgentService.label).plist")
let launchAgentPropertyList = try! PropertyListSerialization.propertyList(
    from: Data(contentsOf: launchAgentURL),
    options: [],
    format: nil
) as! [String: Any]
expect(
    userLaunchAgentService.state == .enabled &&
        launchAgentPropertyList["Label"] as? String == UserLaunchAgentService.label &&
        launchAgentPropertyList["RunAtLoad"] as? Bool == true &&
        launchAgentPropertyList["ProgramArguments"] as? [String] == [
            "/usr/bin/open",
            "-gj",
            launchAgentAppURL.path
        ],
    "临时签名版本必须创建可在用户登录时启动当前应用的 LaunchAgent"
)
try! userLaunchAgentService.unregister()
expect(
    userLaunchAgentService.state == .disabled &&
        !FileManager.default.fileExists(atPath: launchAgentURL.path),
    "用户关闭开机自启动时必须删除兼容登录项"
)

print("通过：临时签名版本开机自启动兼容")

expect(
    Array(ClipCategory.defaultOrder.prefix(2)) == [.recent, .prompt],
    "默认分类必须先展示最近复制，再展示 Prompt"
)

print("通过：默认分类顺序")

expect(
    Clip.demo.first { $0.category == .prompt }.map {
        PromptComposerState(prompt: $0).requiresFeatureDescription
    } == true,
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

let configurableLimitSuiteName = "funPaste.tests.configurable-history-limit"
let configurableLimitDefaults = UserDefaults(suiteName: configurableLimitSuiteName)!
configurableLimitDefaults.removePersistentDomain(forName: configurableLimitSuiteName)
let configurableLimitStore = ClipboardStore(defaults: configurableLimitDefaults)
for index in 0..<80 {
    configurableLimitStore.recordClipboardText("可配置历史 \(index)")
}
configurableLimitStore.setHistoryMaximumCount(50)
expect(
    configurableLimitStore.history.maximumCount == 50 &&
        configurableLimitStore.history.clips.count == 50 &&
        configurableLimitStore.history.clips.first?.content == "可配置历史 79" &&
        configurableLimitStore.history.clips.last?.content == "可配置历史 30",
    "用户调小历史上限后必须立即裁剪最旧记录"
)
configurableLimitStore.setHistoryMaximumCount(500)
let reloadedConfigurableLimitStore = ClipboardStore(defaults: configurableLimitDefaults)
expect(
    reloadedConfigurableLimitStore.history.maximumCount == 500 &&
        reloadedConfigurableLimitStore.history.clips.count == 50,
    "用户调大历史上限后必须保留现有记录，并在重启后继续生效"
)
configurableLimitDefaults.removePersistentDomain(forName: configurableLimitSuiteName)

print("通过：用户可配置历史记录上限")

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

let fileTestDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("funPaste-file-tests-\(UUID().uuidString)", isDirectory: true)
try! FileManager.default.createDirectory(at: fileTestDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: fileTestDirectory) }
let firstFileURL = fileTestDirectory.appendingPathComponent("第一份.txt")
let secondFileURL = fileTestDirectory.appendingPathComponent("第二份.md")
try! Data("第一份文件".utf8).write(to: firstFileURL)
try! Data("第二份文件".utf8).write(to: secondFileURL)

var fileHistory = ClipHistory(maximumCount: 5)
fileHistory.recordFiles([firstFileURL, secondFileURL, firstFileURL])
expect(
    fileHistory.clips.first?.category == .file &&
        fileHistory.clips.first?.title == FunPasteLocalization.format("history.files.count", 2) &&
        fileHistory.clips.first?.fileURLs == [firstFileURL.standardizedFileURL, secondFileURL.standardizedFileURL],
    "复制多个文件时必须保存真实文件 URL、维持顺序并去除重复路径"
)
fileHistory.recordFiles([firstFileURL, secondFileURL])
expect(
    fileHistory.clips.count == 1,
    "相同文件组合再次复制时不得产生重复历史"
)

let decodedFileHistory = try! JSONDecoder().decode(
    ClipHistory.self,
    from: JSONEncoder().encode(fileHistory)
)
expect(
    decodedFileHistory.clips.first?.fileURLs == fileHistory.clips.first?.fileURLs,
    "文件 URL 必须能随历史记录持久化并重新加载"
)

var refreshedFileHistory = fileHistory
expect(
    refreshedFileHistory.refreshFileReferences { $0 == secondFileURL.standardizedFileURL } &&
        refreshedFileHistory.clips.first?.fileURLs == [secondFileURL.standardizedFileURL] &&
        refreshedFileHistory.clips.first?.title == "第二份.md",
    "多文件中的部分文件失效后，历史卡片必须只保留仍存在的文件"
)
expect(
    refreshedFileHistory.refreshFileReferences { _ in false } && refreshedFileHistory.clips.isEmpty,
    "文件全部失效后，历史卡片必须被自动移除"
)

let filePasteboard = NSPasteboard(name: NSPasteboard.Name("funPaste.tests.files"))
filePasteboard.clearContents()
filePasteboard.writeObjects([firstFileURL as NSURL, secondFileURL as NSURL])
expect(
    ClipboardMonitor.fileURLs(in: filePasteboard) == [firstFileURL, secondFileURL],
    "剪贴板监听必须能读取 Finder 写入的单个或多个文件 URL"
)

let fileCopySuiteName = "funPaste.tests.file-copy"
let fileCopyDefaults = UserDefaults(suiteName: fileCopySuiteName)!
fileCopyDefaults.removePersistentDomain(forName: fileCopySuiteName)
let fileCopyStore = ClipboardStore(defaults: fileCopyDefaults)
fileCopyStore.recordClipboardFiles([firstFileURL, secondFileURL])
let persistedFileClip = fileCopyStore.history.clips.first!
let reloadedFileCopyStore = ClipboardStore(defaults: fileCopyDefaults)
expect(
    reloadedFileCopyStore.history.clips.first?.fileURLs == persistedFileClip.fileURLs,
    "Store 重新加载后必须保留文件历史"
)

filePasteboard.clearContents()
expect(
    fileCopyStore.copy(persistedFileClip, to: filePasteboard) &&
        ClipboardMonitor.fileURLs(in: filePasteboard) == [firstFileURL, secondFileURL],
    "点击文件历史时必须把真实文件对象写回剪贴板"
)

try! FileManager.default.removeItem(at: firstFileURL)
try! FileManager.default.removeItem(at: secondFileURL)
expect(
    !fileCopyStore.copy(persistedFileClip, to: filePasteboard) &&
        fileCopyStore.history.clips.allSatisfy { $0.id != persistedFileClip.id } &&
        fileCopyStore.feedbackMessage == FunPasteLocalization.string("feedback.fileMissing"),
    "所有源文件失效后必须移除历史卡片、阻止空粘贴并给出可见反馈"
)
fileCopyDefaults.removePersistentDomain(forName: fileCopySuiteName)

print("通过：文件捕获、去重、持久化、再次复制与失效保护")

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

var pasteEventPostingSteps: [String] = []
PasteEventPostingCoordinator.perform(
    postPasteEvent: { pasteEventPostingSteps.append("发送粘贴") },
    onPasteEventPosted: { pasteEventPostingSteps.append("记录使用") }
)
expect(
    pasteEventPostingSteps == ["发送粘贴", "记录使用"],
    "Prompt 使用记录必须发生在粘贴事件发送之后"
)

print("通过：粘贴后记录 Prompt 使用")

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
    PromptComposerCloseBehavior.returnToPanel.restoresParentPanel &&
        !PromptComposerCloseBehavior.prepareForPaste.restoresParentPanel &&
        QuickPanelController.pasteActivationDelayMilliseconds == 16 &&
        QuickPanelController.pasteTargetActivationRetryInterval == 5 &&
        QuickPanelController.pasteFadeDuration == 0.08,
    "Prompt 生成并粘贴时不得重新激活主面板并抢走原输入框焦点"
)

print("通过：Prompt 粘贴关闭策略")

expect(
    PasteTargetActivationCoordinator.nextAction(
        isFrontmost: true,
        attemptsRemaining: 50,
        retryInterval: 5
    ) == .paste &&
        PasteTargetActivationCoordinator.nextAction(
            isFrontmost: false,
            attemptsRemaining: 50,
            retryInterval: 5
        ) == .retryActivation &&
        PasteTargetActivationCoordinator.nextAction(
            isFrontmost: false,
            attemptsRemaining: 49,
            retryInterval: 5
        ) == .wait &&
        PasteTargetActivationCoordinator.nextAction(
            isFrontmost: false,
            attemptsRemaining: 0,
            retryInterval: 5
        ) == .fail,
    "粘贴目标必须支持立即完成、激活重试、等待和最终失败四种状态"
)

print("通过：粘贴目标自适应激活重试")

expect(
    PanelKeyCommand(keyCode: 53) == .dismiss &&
        PanelKeyCommand(keyCode: 126) == .selectPrevious &&
        PanelKeyCommand(keyCode: 125) == .selectNext &&
        PanelKeyCommand(keyCode: 123) == .selectPreviousCategory &&
        PanelKeyCommand(keyCode: 124) == .selectNextCategory &&
        PanelKeyCommand(keyCode: 36) == .paste,
    "Esc、上下左右键和回车必须在原生窗口层映射为侧栏操作"
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

let engineeringPromptIDs: Set<String> = [
    "effective-ai-collaboration-prompt",
    "requirements-interview-prompt",
    "explore-plan-implement-prompt",
    "root-cause-debugging-prompt",
    "code-review-prompt",
    "test-generation-prompt",
    "behavior-preserving-refactor-prompt"
]
let seededEngineeringPrompts = library.items.filter { engineeringPromptIDs.contains($0.id) }
expect(
    Set(seededEngineeringPrompts.map(\.id)) == engineeringPromptIDs &&
        seededEngineeringPrompts.allSatisfy {
            $0.category == .prompt &&
                !$0.content
                    .replacingOccurrences(of: "{{功能描述}}", with: "测试目标")
                    .replacingOccurrences(of: "{{技术约束}}", with: "测试约束")
                    .replacingOccurrences(of: "{{feature description}}", with: "test goal")
                    .replacingOccurrences(of: "{{technical constraints}}", with: "test constraints")
                    .contains("{{")
        },
    "首次内容库必须包含可补全变量的 AI 协作与工程开发 Prompt"
)

print("通过：AI 协作与工程 Prompt 模板")

let openAIPromptIDs: Set<String> = [
    "gpt-5p6-outcome-contract-prompt",
    "gpt-5p6-prompt-audit-prompt",
    "gpt-5p6-grounded-research-prompt"
]
let seededOpenAIPrompts = library.items.filter { openAIPromptIDs.contains($0.id) }
expect(
    Set(seededOpenAIPrompts.map(\.id)) == openAIPromptIDs &&
        seededOpenAIPrompts.allSatisfy {
            $0.source == FunPasteLocalization.string("prompt.source.openAI") &&
                !$0.content
                    .replacingOccurrences(of: "{{功能描述}}", with: "测试目标")
                    .replacingOccurrences(of: "{{技术约束}}", with: "测试约束")
                    .replacingOccurrences(of: "{{feature description}}", with: "test goal")
                    .replacingOccurrences(of: "{{technical constraints}}", with: "test constraints")
                    .contains("{{")
        },
    "首次内容库必须包含来自 OpenAI GPT-5.6 指南的可补全 Prompt"
)

print("通过：OpenAI GPT-5.6 Prompt 模板")

expect(
    library.items
        .filter { $0.category == .prompt }
        .allSatisfy { $0.content.contains("\n\n") },
    "内置 Prompt 必须使用空行区分目标、约束、步骤和输出等结构"
)

print("通过：内置 Prompt 分段结构")

let composerPrompt = Clip(
    id: "composer-test",
    category: .prompt,
    title: "独立编辑测试",
    content: "目标：{{功能描述}}\n约束：{{技术约束}}",
    source: "测试"
)
var composerState = PromptComposerState(prompt: composerPrompt)
expect(
    composerState.requiresFeatureDescription &&
        composerState.requiresTechnicalConstraint &&
        !composerState.canSubmit,
    "Prompt 编辑器必须识别必填变量并阻止直接提交占位符"
)

composerState.featureDescription = "第一行目标\n第二行包含更多细节"
composerState.technicalConstraint = "保持现有接口\n兼容 macOS 14"
composerState.additionalContext = "错误日志第一行\n错误日志第二行"
expect(
    composerState.canSubmit &&
        composerState.resolvedContent.contains("第一行目标\n第二行包含更多细节") &&
        composerState.resolvedContent.contains("保持现有接口\n兼容 macOS 14") &&
        composerState.resolvedContent.hasSuffix(
            "\(FunPasteLocalization.string("promptComposer.additionalSection"))\n错误日志第一行\n错误日志第二行"
        ) &&
        !composerState.preparedClip.content.contains("{{"),
    "独立 Prompt 编辑器必须保留多行输入、附加上下文并生成完整内容"
)

print("通过：独立 Prompt 编辑状态")

let standardPanelSize = QuickPanelController.panelSize(
    for: NSRect(x: 0, y: 0, width: 1440, height: 900)
)
let compactPanelSize = QuickPanelController.panelSize(
    for: NSRect(x: 0, y: 0, width: 400, height: 500)
)
expect(
    standardPanelSize == NSSize(width: 420, height: 864) &&
        compactPanelSize == NSSize(width: 364, height: 500),
    "快捷面板必须保持目标宽度，并根据当前屏幕可见高度自适应且不越界"
)

print("通过：快捷面板屏幕高度适配")

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

let migrationLibrarySuiteName = "funPaste.tests.prompt-library-migration"
let migrationLibraryDefaults = UserDefaults(suiteName: migrationLibrarySuiteName)!
migrationLibraryDefaults.removePersistentDomain(forName: migrationLibrarySuiteName)
let legacyLibrary = ContentLibrary(items: [
    Clip(
        id: "plain-language-prompt",
        category: .prompt,
        title: "把复杂内容说清楚",
        content: "旧版内置 Prompt",
        source: "内置 Prompt"
    )
])
migrationLibraryDefaults.set(try! JSONEncoder().encode(legacyLibrary), forKey: "funPaste.library")

let migratedLibraryStore = ClipboardStore(defaults: migrationLibraryDefaults)
expect(
    engineeringPromptIDs.isSubset(of: Set(migratedLibraryStore.library.items.map(\.id))) &&
        !migratedLibraryStore.library.items.contains { $0.id == "development-prompt" },
    "升级旧内容库时必须补齐新 Prompt，但不能复活用户已删除的旧模板"
)

migratedLibraryStore.deleteLibraryItem(id: "code-review-prompt")
let reloadedMigratedLibraryStore = ClipboardStore(defaults: migrationLibraryDefaults)
expect(
    !reloadedMigratedLibraryStore.library.items.contains { $0.id == "code-review-prompt" } &&
        reloadedMigratedLibraryStore.library.items.filter { engineeringPromptIDs.contains($0.id) }.count == engineeringPromptIDs.count - 1,
    "Prompt 模板迁移只能执行一次，用户删除后不得再次出现"
)

migrationLibraryDefaults.removePersistentDomain(forName: migrationLibrarySuiteName)

print("通过：Prompt 模板库升级迁移")

let openAIMigrationSuiteName = "funPaste.tests.openai-prompt-migration"
let openAIMigrationDefaults = UserDefaults(suiteName: openAIMigrationSuiteName)!
openAIMigrationDefaults.removePersistentDomain(forName: openAIMigrationSuiteName)
openAIMigrationDefaults.set(try! JSONEncoder().encode(legacyLibrary), forKey: "funPaste.library")
openAIMigrationDefaults.set(1, forKey: "funPaste.librarySeedVersion")

let openAIMigratedStore = ClipboardStore(defaults: openAIMigrationDefaults)
expect(
    openAIPromptIDs.isSubset(of: Set(openAIMigratedStore.library.items.map(\.id))),
    "版本 1 内容库升级时必须补齐 OpenAI GPT-5.6 Prompt"
)

openAIMigratedStore.deleteLibraryItem(id: "gpt-5p6-prompt-audit-prompt")
let reloadedOpenAIMigratedStore = ClipboardStore(defaults: openAIMigrationDefaults)
expect(
    !reloadedOpenAIMigratedStore.library.items.contains { $0.id == "gpt-5p6-prompt-audit-prompt" },
    "OpenAI Prompt 迁移只能执行一次，用户删除后不得再次出现"
)

openAIMigrationDefaults.removePersistentDomain(forName: openAIMigrationSuiteName)

print("通过：OpenAI Prompt 模板升级迁移")

let legacyClipJSON = """
{"id":"legacy-json","category":"prompt","title":"旧 Prompt","content":"旧内容","source":"旧版本"}
""".data(using: .utf8)!
let decodedLegacyClip = try! JSONDecoder().decode(Clip.self, from: legacyClipJSON)
expect(
    decodedLegacyClip.promptMetadata == nil,
    "新增 Prompt 元数据后必须仍能解码旧版 Clip 数据"
)

var organizedLibrary = ContentLibrary()
let duplicateOriginal = organizedLibrary.create(
    category: .prompt,
    title: "原始 Prompt",
    content: "请分析   这段内容\n并给出结论",
    promptMetadata: PromptMetadata(collection: .research, tags: ["研究", " 证据 ", "研究"])
)
expect(
    organizedLibrary.duplicatePrompt(content: "请分析 这段内容 并给出结论")?.id == duplicateOriginal.id &&
        organizedLibrary.items.first?.promptMetadata?.tags == ["研究", "证据"],
    "重复检测必须忽略空白差异，标签必须去空和去重"
)

organizedLibrary.togglePromptFavorite(id: duplicateOriginal.id)
organizedLibrary.recordPromptUse(id: duplicateOriginal.id, at: Date(timeIntervalSince1970: 100))
expect(
    organizedLibrary.prompts(favoritesOnly: true).map(\.id) == [duplicateOriginal.id] &&
        organizedLibrary.prompts(query: "证据").map(\.id) == [duplicateOriginal.id] &&
        organizedLibrary.items.first?.promptMetadata?.useCount == 1,
    "Prompt 收藏、标签搜索和使用次数必须同步生效"
)

organizedLibrary.setPromptArchived(id: duplicateOriginal.id, isArchived: true)
expect(
    organizedLibrary.prompts().isEmpty &&
        organizedLibrary.prompts(archived: true).map(\.id) == [duplicateOriginal.id],
    "归档 Prompt 必须从正常列表隐藏，并只出现在已归档视图"
)

var largeLibrary = ContentLibrary()
for index in 0..<200 {
    _ = largeLibrary.create(
        category: .prompt,
        title: "工程模板 \(index)",
        content: "处理模块 \(index)",
        promptMetadata: PromptMetadata(
            collection: index.isMultiple(of: 2) ? .development : .writing,
            tags: [index.isMultiple(of: 5) ? "高频" : "常规"]
        )
    )
}
expect(
    largeLibrary.prompts(collection: .development).count == 100 &&
        largeLibrary.prompts(query: "高频").count == 40 &&
        largeLibrary.prompts(query: "工程 199").map(\.title) == ["工程模板 199"],
    "200 条 Prompt 下分类、标签和多关键词搜索结果必须准确"
)

let metadataMigrationSuiteName = "funPaste.tests.prompt-metadata-migration"
let metadataMigrationDefaults = UserDefaults(suiteName: metadataMigrationSuiteName)!
metadataMigrationDefaults.removePersistentDomain(forName: metadataMigrationSuiteName)
let versionTwoLibrary = ContentLibrary(items: [
    Clip(
        id: "custom-version-two",
        category: .prompt,
        title: "旧自定义 Prompt",
        content: "用户内容",
        source: "自定义 Prompt"
    ),
    Clip(
        id: "gpt-5p6-grounded-research-prompt",
        category: .prompt,
        title: "做有证据边界的研究",
        content: "旧研究内容",
        source: "OpenAI GPT-5.6 指南"
    )
])
metadataMigrationDefaults.set(try! JSONEncoder().encode(versionTwoLibrary), forKey: "funPaste.library")
metadataMigrationDefaults.set(2, forKey: "funPaste.librarySeedVersion")
let metadataMigratedStore = ClipboardStore(defaults: metadataMigrationDefaults)
expect(
    metadataMigratedStore.library.items.first { $0.id == "custom-version-two" }?.promptMetadata?.collection == .inbox &&
        metadataMigratedStore.library.items.first { $0.id == "gpt-5p6-grounded-research-prompt" }?.promptMetadata?.collection == .research,
    "版本 2 内容库升级时必须把自定义 Prompt 放入收件箱，并保留内置模板的推荐分类"
)
let metadataReloadedStore = ClipboardStore(defaults: metadataMigrationDefaults)
expect(
    metadataReloadedStore.library.items.count == metadataMigratedStore.library.items.count,
    "Prompt 元数据迁移只能执行一次，重新加载不得添加或复活条目"
)
metadataMigrationDefaults.removePersistentDomain(forName: metadataMigrationSuiteName)

let formattingMigrationSuiteName = "funPaste.tests.prompt-formatting-migration"
let formattingMigrationDefaults = UserDefaults(suiteName: formattingMigrationSuiteName)!
formattingMigrationDefaults.removePersistentDomain(forName: formattingMigrationSuiteName)
let flatBuiltIn = Clip.builtInPromptTemplates.first { $0.id == "gpt-5p6-outcome-contract-prompt" }!
formattingMigrationDefaults.set(
    try! JSONEncoder().encode(ContentLibrary(items: [flatBuiltIn])),
    forKey: "funPaste.library"
)
formattingMigrationDefaults.set(3, forKey: "funPaste.librarySeedVersion")
let formattingMigratedStore = ClipboardStore(defaults: formattingMigrationDefaults)
expect(
    formattingMigratedStore.library.items.first?.content.contains("\n\n") == true &&
        formattingMigratedStore.library.items.count == 1,
    "版本 3 内容库升级时必须为已有内置 Prompt 增加段落，且不得补回其他条目"
)
formattingMigrationDefaults.removePersistentDomain(forName: formattingMigrationSuiteName)

print("通过：Prompt 分类、标签、收藏、归档、搜索、重复检测与版本 4 迁移")
