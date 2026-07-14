# funPaste 面板隐藏 Dock 图标实施计划

**目标：** funPaste 打开侧边面板及执行全部交互时始终不出现在 Dock，同时保留当前已经验收的搜索、键盘导航、关闭和 Enter 粘贴能力。

**架构：** App 始终维持 AppKit `.accessory` 激活策略。继续使用当前普通可获焦点 `NSPanel`、应用激活通知和本地按键监听，只移除打开面板时切换到 `.regular` 的行为；粘贴目标恢复和授权流程保持不变。

**技术栈：** Swift 6、SwiftUI、AppKit、Swift Package Manager、macOS 14+、Carbon 全局快捷键、Core Graphics PostEvent。

---

## 文件职责

- `Sources/FunPasteUI/QuickPanelController.swift`：定义面板显示期间的激活策略，并负责面板键盘焦点与目标应用恢复。
- `Sources/FunPasteUITestRunner/main.swift`：固定 Dock 隐藏策略，并保留现有键盘与粘贴回归检查。
- `scripts/build-app.sh`：生成带 `LSUIElement = true` 和有效本地签名的 App 包。

### 任务 1：用失败测试固定 Dock 隐藏约束

**文件：**

- 修改：`Sources/FunPasteUITestRunner/main.swift:137`

- [ ] **步骤 1：将现有激活策略断言改为 `.accessory`**

```swift
expect(
    QuickPanelController.panelActivationPolicy == .accessory &&
        QuickPanelController.restingActivationPolicy == .accessory,
    "funPaste 打开和收起侧栏时都必须保持后台工具策略，不能显示 Dock 图标"
)

print("通过：侧栏始终保持后台工具策略")
```

- [ ] **步骤 2：运行测试并确认按预期失败**

运行：

```sh
swift run FunPasteUITestRunner
```

预期：测试在“funPaste 打开和收起侧栏时都必须保持后台工具策略”处失败，因为当前 `panelActivationPolicy` 是 `.regular`。

### 任务 2：实施最小激活策略修改

**文件：**

- 修改：`Sources/FunPasteUI/QuickPanelController.swift:14`

- [ ] **步骤 1：让面板显示和静止状态都使用 `.accessory`**

```swift
public static let panelActivationPolicy: NSApplication.ActivationPolicy = .accessory
public static let restingActivationPolicy: NSApplication.ActivationPolicy = .accessory
```

保留 `show()` 中的 `NSRunningApplication.current.activate()`、`didBecomeActiveNotification`、120 毫秒兜底展示和本地按键监听，不修改 Enter 粘贴链路。

- [ ] **步骤 2：运行完整测试并确认通过**

运行：

```sh
swift run FunPasteUITestRunner
```

预期：输出包含“通过：侧栏始终保持后台工具策略”，且所有既有测试通过。

- [ ] **步骤 3：检查差异并提交核心修改**

运行：

```sh
git diff --check
git diff -- Sources/FunPasteUI/QuickPanelController.swift Sources/FunPasteUITestRunner/main.swift
git add Sources/FunPasteUI/QuickPanelController.swift Sources/FunPasteUITestRunner/main.swift
git commit -m "fix: keep quick panel out of dock"
```

预期：提交只包含激活策略和对应回归测试。

### 任务 3：构建、授权和真实交互验收

**文件：** 无源码修改。

- [ ] **步骤 1：构建并验证 App 包**

运行：

```sh
bash scripts/build-app.sh
plutil -extract LSUIElement raw dist/funPaste.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 dist/funPaste.app
```

预期：`LSUIElement` 输出 `true`，签名验证输出 `valid on disk` 和 `satisfies its Designated Requirement`。

- [ ] **步骤 2：重启最新 App**

运行：

```sh
pkill -x funPaste || true
open -n dist/funPaste.app
```

预期：菜单栏出现 funPaste，Dock 中没有 funPaste 图标。

- [ ] **步骤 3：处理本地签名导致的权限刷新**

如果 Enter 粘贴权限因新二进制失效，只重置当前 App 的权限并重启：

```sh
tccutil reset PostEvent com.changlei.funPaste
tccutil reset Accessibility com.changlei.funPaste
pkill -x funPaste || true
open -n dist/funPaste.app
```

用户在系统弹窗中允许 funPaste。授权后不得再次构建，避免当前本地签名权限再次失效。

- [ ] **步骤 4：执行黑盒验收**

在任意真实输入框中逐项验证：

1. 连续多次按 `Shift + Command + V`，面板出现时 Dock 始终没有 funPaste 图标；
2. 搜索框可以输入普通文字；
3. 上下方向键移动选择，滚动位置同步；
4. Tab 循环切换分类；
5. Esc 和关闭按钮都能收起面板；
6. Enter 和鼠标双击都能把选中内容输入原输入框；
7. 点击面板外部能自动收起。

预期：七项全部通过；任何键盘或粘贴回归都视为失败，不提交替代性猜测修复。

### 任务 4：最终状态检查

**文件：** 无新增修改。

- [ ] **步骤 1：确认提交与工作区状态**

运行：

```sh
git status --short
git log -2 --oneline
```

预期：工作区干净，最新代码提交为 `fix: keep quick panel out of dock`。
