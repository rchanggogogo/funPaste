# Prompt 与收藏内容库实施计划

> **供自动化执行：** 按任务顺序实施；每个行为先写失败测试，再写最小实现。

**目标：** 为 Prompt 与收藏提供本地新增、编辑、删除和最近复制一键收藏能力。

**架构：** 新增 `ContentLibrary` 作为独立、可编码的内容库；`ClipboardStore` 负责加载、初始化和持久化；`RibbonDeckView` 负责表单、操作菜单和确认删除。历史记录继续由 `ClipHistory` 单独管理。

**技术栈：** Swift 6、SwiftUI、AppKit、UserDefaults、Codable、自定义命令行测试运行器。

---

### 任务 1：可管理内容库与初始化

**文件：**

- 新建：`Sources/FunPasteUI/ContentLibrary.swift`
- 修改：`Sources/FunPasteUI/Clip.swift`
- 修改：`Sources/FunPasteUITestRunner/main.swift`

- [ ] 先在测试运行器新增失败用例，覆盖首次内容库包含内置 Prompt/收藏、按内容收藏去重、更新和永久删除：

```swift
var library = ContentLibrary.seeded
let prompt = library.create(category: .prompt, title: "测试 Prompt", content: "请解释 {{内容}}")
expect(library.items.contains { $0.id == prompt.id }, "新建 Prompt 必须进入内容库")
library.update(id: prompt.id, title: "已编辑", content: "新内容")
expect(library.items.first { $0.id == prompt.id }?.title == "已编辑", "编辑必须更新标题")
library.delete(id: prompt.id)
expect(!library.items.contains { $0.id == prompt.id }, "删除必须永久移除项目")
```

- [ ] 运行 `swift run FunPasteUITestRunner`，预期因 `ContentLibrary` 不存在失败。

- [ ] 实现 `ContentLibrary`：仅接受 `.prompt` 和 `.pinned`；`seeded` 取现有 `Clip.demo` 对应两类项目；`create` 使用 UUID；`update` 保持 id/category/source；`delete` 按 id 移除；`pin` 用内容去重并新增 `.pinned`。

- [ ] 将 `Clip.presentationItems(history:)` 改为接收 `library`，返回历史 + 内容库；历史为空时仍保留现有最近复制示例。

- [ ] 重新运行 `swift run FunPasteUITestRunner`，预期新增内容库断言全部通过。

- [ ] 提交：`git add Sources/FunPasteUI/ContentLibrary.swift Sources/FunPasteUI/Clip.swift Sources/FunPasteUITestRunner/main.swift && git commit -m "feat: add editable content library"`

### 任务 2：内容库持久化与 Store 操作

**文件：**

- 修改：`Sources/FunPasteUI/ClipboardStore.swift`
- 修改：`Sources/FunPasteUITestRunner/main.swift`

- [ ] 添加失败用例，使用独立 `UserDefaults(suiteName:)` 验证保存后重新构建 Store 仍能读到新建 Prompt 和收藏。

```swift
let defaults = UserDefaults(suiteName: "funPaste.tests.library")!
defaults.removePersistentDomain(forName: "funPaste.tests.library")
let store = ClipboardStore(defaults: defaults)
let created = store.createLibraryItem(category: .prompt, title: "持久化", content: "内容")
let reloaded = ClipboardStore(defaults: defaults)
expect(reloaded.library.items.contains { $0.id == created.id }, "内容库必须重启后保留")
```

- [ ] 运行测试，预期因 Store 缺少 `library` 与 CRUD 方法失败。

- [ ] 为 Store 增加 `@Published private(set) var library`、键 `funPaste.library`、加载失败时使用 `ContentLibrary.seeded`；增加 `createLibraryItem`、`updateLibraryItem`、`deleteLibraryItem` 与 `pin(_:)`，每次变更均 JSON 编码保存。

- [ ] `clips` 改为 `Clip.presentationItems(history: history.clips, library: library)`；`pin(_:)` 返回已存在或新建的收藏，确保同内容不重复。

- [ ] 重新运行测试，预期持久化及既有剪贴历史测试全通过。

- [ ] 提交：`git add Sources/FunPasteUI/ClipboardStore.swift Sources/FunPasteUITestRunner/main.swift && git commit -m "feat: persist prompt and pinned library"`

### 任务 3：Prompt 与收藏的新增、编辑、删除界面

**文件：**

- 修改：`Sources/FunPasteUI/RibbonDeckView.swift`

- [ ] 在 `.prompt` 与 `.pinned` 分类标题右侧增加 `＋` 按钮，打开同一个表单状态；Prompt 表单显示变量说明和示例占位文字“例如：实现一个新功能”“请帮我完成……{{功能描述}}”。

- [ ] 在 `ClipRow` 末尾为 `.prompt`、`.pinned` 增加 `Menu`：编辑、删除；编辑预填标题/内容；删除用 `confirmationDialog` 显示“删除后无法恢复”。

- [ ] 表单保存时校验标题与内容去除空白后非空；空值不保存并保留表单；成功后调用 Store CRUD、关闭表单、选中保存项目。

- [ ] 删除确认后调用 `deleteLibraryItem(id:)`，清空当前选中 id，并用现有反馈机制显示“已删除”。

- [ ] 手工验证：新增 Prompt、编辑内置 Prompt、删除内置 Prompt、新增收藏、编辑收藏、删除收藏，关闭并重新打开 App 后确认均保留。

- [ ] 提交：`git add Sources/FunPasteUI/RibbonDeckView.swift && git commit -m "feat: manage prompts and pins in panel"`

### 任务 4：最近复制一键收藏与完整验证

**文件：**

- 修改：`Sources/FunPasteUI/RibbonDeckView.swift`
- 修改：`Sources/FunPasteUITestRunner/main.swift`

- [ ] 添加 Store 失败用例，验证同一最近复制项连续调用两次 `pin(_:)` 后内容库仅有一条同内容收藏。

- [ ] 运行测试，预期重复收藏断言失败或 API 缺失。

- [ ] 对 `.recent` 与 `.image` 行增加星标按钮：未收藏显示 `star`，已收藏显示 `star.fill`；点击调用 `store.pin(clip)`，不触发卡片选择或粘贴。

- [ ] 重新运行 `swift build && swift run FunPasteUITestRunner && git diff --check`，预期构建完成、所有测试通过且无空白错误。

- [ ] 手工验证：复制一段文本→一键收藏→切到收藏确认出现；再次收藏不重复；搜索、Tab 分类、上下选择、Enter 粘贴、Esc 和点击外部收起均正常。

- [ ] 提交：`git add Sources/FunPasteUI/RibbonDeckView.swift Sources/FunPasteUITestRunner/main.swift && git commit -m "feat: pin recent clipboard items"`
