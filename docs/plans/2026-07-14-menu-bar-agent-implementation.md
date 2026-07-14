# 菜单栏后台运行实施计划

> **给执行者：** 按任务顺序执行；每个任务完成后运行列出的验证命令。

**目标：** 让 funPaste 始终以菜单栏后台工具运行，不在 Dock 中显示图标，同时保持侧边面板可获得键盘焦点。

**架构：** App 委托在启动时设为 `.accessory` 激活策略；`QuickPanelController` 在打开面板时继续激活应用，但不再切换为 `.regular`，关闭后也保持 `.accessory`。打包脚本把 `LSUIElement` 写入 App 的 `Info.plist`，让 Finder 启动路径获得同一行为。

**技术栈：** Swift 6、SwiftUI、AppKit、Swift Package Manager、macOS 14+、`plutil`。

---

## 文件职责

- `Sources/FunPastePreview/main.swift`：配置启动时的 App 激活策略。
- `Sources/FunPasteUI/QuickPanelController.swift`：在显示、关闭侧边面板时维持后台工具策略。
- `Sources/FunPasteUITestRunner/main.swift`：断言面板激活不会改为显示 Dock 的策略。
- `scripts/build-app.sh`：把后台工具标记写入打包 App 的 `Info.plist`。

### 任务 1：先固定面板不显示 Dock 的行为

**文件：**

- 修改：`Sources/FunPasteUITestRunner/main.swift`
- 修改：`Sources/FunPasteUI/QuickPanelController.swift`

- [ ] **步骤 1：写入失败测试**

在 `Sources/FunPasteUITestRunner/main.swift` 的侧栏测试之后加入：

```swift
import AppKit

expect(
    QuickPanelController.panelActivationPolicy == .accessory,
    "打开侧栏时必须保持后台工具策略，不能显示 Dock 图标"
)

print("通过：侧栏打开时保持后台工具策略")
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`swift run FunPasteUITestRunner`

预期：编译失败，提示 `QuickPanelController` 没有 `panelActivationPolicy`。

- [ ] **步骤 3：实现最小策略定义**

在 `QuickPanelController` 的静态属性区域加入：

```swift
public static let panelActivationPolicy: NSApplication.ActivationPolicy = .accessory
```

将 `show()` 中的：

```swift
NSApp.setActivationPolicy(.regular)
```

替换为：

```swift
NSApp.setActivationPolicy(Self.panelActivationPolicy)
```

将 `dismiss()` 中的 `.accessory` 替换为同一静态属性，保证打开与关闭路径一致。

- [ ] **步骤 4：运行测试并确认通过**

运行：`swift run FunPasteUITestRunner`

预期：输出包含“通过：侧栏打开时保持后台工具策略”，且所有既有测试通过。

- [ ] **步骤 5：提交**

```sh
git add Sources/FunPasteUI/QuickPanelController.swift Sources/FunPasteUITestRunner/main.swift
git commit -m "fix: keep panel out of dock"
```

### 任务 2：配置启动与打包路径

**文件：**

- 修改：`Sources/FunPastePreview/main.swift`
- 修改：`scripts/build-app.sh`

- [ ] **步骤 1：启动时设置后台工具策略**

在 `MacAppDelegate.applicationDidFinishLaunching` 的首行加入：

```swift
NSApp.setActivationPolicy(.accessory)
```

之后继续初始化剪贴板监听、侧边面板和全局快捷键。

- [ ] **步骤 2：在打包脚本加入 App 标记**

在 `scripts/build-app.sh` 的 `plutil` 配置末尾加入：

```sh
plutil -replace LSUIElement -bool true "$info_plist"
```

- [ ] **步骤 3：重新构建并核验 App 配置**

运行：

```sh
bash scripts/build-app.sh
plutil -extract LSUIElement raw dist/funPaste.app/Contents/Info.plist
```

预期：第二条命令输出 `true`。

- [ ] **步骤 4：手动启动校验**

先退出已运行的调试版或旧 App，再运行：

```sh
open dist/funPaste.app
```

预期：菜单栏出现 funPaste 图标，Dock 不出现 funPaste 图标；使用 `Shift + Command + V` 打开面板后，面板可以输入搜索文字，Dock 仍不出现图标。

- [ ] **步骤 5：提交**

```sh
git add Sources/FunPastePreview/main.swift scripts/build-app.sh
git commit -m "feat: run funPaste as menu bar agent"
```

### 任务 3：最终回归验证

**文件：** 无新增修改。

- [ ] **步骤 1：运行完整逻辑测试**

运行：`swift run FunPasteUITestRunner`

预期：所有测试均输出“通过”。

- [ ] **步骤 2：重新打包并检查 App 内容**

运行：

```sh
bash scripts/build-app.sh
test -x dist/funPaste.app/Contents/MacOS/funPaste
test -f dist/funPaste.app/Contents/Resources/AppIcon.icns
plutil -extract LSUIElement raw dist/funPaste.app/Contents/Info.plist
```

预期：命令成功，最后输出 `true`。
