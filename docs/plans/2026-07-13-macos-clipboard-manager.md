# funPaste macOS 剪贴板管理器实现计划

**目标：** 将当前 UI 原型扩展为可在 macOS 上自动记录、搜索、复制和粘贴文本剪贴历史的本地工具。

**架构：** 纯 SwiftUI + AppKit。`ClipHistory` 负责可测试的去重、排序和敏感内容过滤；`ClipboardStore` 将历史持久化到用户的本地偏好设置，并由 `ClipboardMonitor` 轮询 `NSPasteboard` 的变化。`MacAppDelegate` 负责菜单栏、全局快捷键与浮动面板，界面继续使用 Ribbon Deck。

**技术约束：** 仅保存文本；不联网；不实现 iPhone/iPad 验证；默认快捷键为 Shift + Command + V；自动粘贴需要 macOS 辅助功能权限，未授权时只复制并提示用户。

## 任务

### 1. 可测试的历史规则

**文件：**

- 创建：`Sources/FunPasteUI/ClipHistory.swift`
- 修改：`Sources/FunPasteUI/Clip.swift`
- 修改：`Sources/FunPasteUITestRunner/main.swift`

先为以下规则添加失败测试，再实现最小逻辑：

- 新内容插入历史顶部。
- 相同文本不会生成重复记录，而是回到顶部。
- 包含密码、验证码或银行卡字段的内容不自动记录。
- 历史最多保存 500 条，避免无界增长。

### 2. 本地保存与 macOS 剪贴板监听

**文件：**

- 创建：`Sources/FunPasteUI/ClipboardStore.swift`
- 创建：`Sources/FunPasteUI/ClipboardMonitor.swift`

`ClipboardStore` 使用 `UserDefaults` 保存历史、暂停状态和分类顺序。`ClipboardMonitor` 监听 `NSPasteboard.general.changeCount`；发现新文本时交给历史规则处理。用户主动从 funPaste 复制或粘贴的文本会标记为忽略一次，避免回写造成重复。

### 3. 快捷键与浮动面板

**文件：**

- 创建：`Sources/FunPasteUI/GlobalShortcut.swift`
- 创建：`Sources/FunPasteUI/QuickPanelController.swift`
- 修改：`Sources/FunPastePreview/main.swift`

注册 Shift + Command + V；按下后在当前屏幕底部展示非激活的浮动 Ribbon Deck 面板。菜单栏提供「显示 funPaste」「暂停记录」「清空历史」和「退出」。快捷键注册失败时菜单栏入口仍可用。

### 4. 可用的卡组界面

**文件：**

- 修改：`Sources/FunPasteUI/RibbonDeckView.swift`

界面从静态演示数据切换到 `ClipboardStore`。最近复制默认选中；搜索、分类和 Prompt 模板保持当前交互。点击或回车后先写入系统剪贴板，再尝试模拟 Command + V；未获得辅助功能权限时显示「已复制，请手动粘贴」。

### 5. 验证

运行以下命令：

```sh
swift build
swift run FunPasteUITestRunner
swift run FunPastePreview
```

前两项必须成功。第三项用于人工确认菜单栏、快捷键权限提示和浮动面板；若当前运行环境无法显示 GUI，保留构建成功与运行限制说明。
