# funPaste 面板打开时隐藏 Dock 图标设计

## 目标

funPaste 在整个生命周期中都不出现在 macOS Dock，包括打开侧边面板、输入搜索内容、使用键盘导航和执行粘贴时，也不能短暂显示 Dock 图标。

同时必须保留当前已经验收的交互：

- `Shift + Command + V` 能稳定打开面板；
- 搜索框可以正常输入；
- 上下方向键、Tab 和 Esc 正常工作；
- Enter 和鼠标双击能将选中内容粘贴到原输入位置；
- 点击面板外部能够收起面板；
- App 继续常驻菜单栏。

## 根因

应用启动时使用 `.accessory`，但打开面板时会临时切换为 `.regular`。macOS 会为 `.regular` 应用显示 Dock 图标，因此面板出现时 Dock 图标也会出现。

## 选定方案

应用始终保持 `.accessory` 激活策略，不再切换为 `.regular`。

继续使用当前可获得键盘焦点的普通 `NSPanel`，而不是改回 `.nonactivatingPanel`。面板显示时仍由 funPaste 激活自身、等待应用激活，再让面板成为键盘窗口。这样可以最大限度保留当前搜索框和键盘操作的可靠性。

## 历史风险与控制

仓库曾在提交 `242811f` 中尝试过 `.accessory` 面板，但当时尚未具备当前的应用激活通知、本地按键监听和延迟展示机制。后续键盘修复把多项改动与 `.regular` 策略一起引入，因此不能仅凭旧版本判断 `.accessory` 必然无法接收键盘。

本次先用失败测试固定“不允许 `.regular`”的约束，只改变激活策略，不删除当前已经验收的按键监听和展示时序。构建后必须同时验证面板成为键盘窗口、搜索输入、方向键、Esc 和 Enter 粘贴；其中任一项失败都不能交付，也不能用恢复 `.regular` 作为修复手段。

## 组件调整

### 应用激活策略

- `QuickPanelController.panelActivationPolicy` 固定为 `.accessory`；
- 删除打开和关闭面板时在 `.regular` 与 `.accessory` 之间切换的行为；
- `Info.plist` 继续保留 `LSUIElement = true`；
- App 启动后继续设置 `NSApp.setActivationPolicy(.accessory)`。

### 面板显示

打开面板时：

1. 保存当前前台目标应用；
2. 保持 funPaste 为 `.accessory`；
3. 通过 `NSRunningApplication.current.activate()` 激活 funPaste；
4. 等待应用激活后调用 `makeKeyAndOrderFront`；
5. 保持现有本地键盘监听处理方向键、Tab、Esc 和 Enter。

### 粘贴与关闭

粘贴时继续沿用当前已经验收的流程：隐藏面板、让 funPaste 退出前台、恢复原目标应用、确认目标应用成为前台，然后发送 `Command-V`。

普通关闭时隐藏面板并恢复原目标应用。隐藏 Dock 的修改不改变授权、剪贴板写入或粘贴事件发送逻辑。

## 异常处理

- 如果 `.accessory` 状态下应用没有成功激活，面板不得假装已经可交互；继续使用现有激活通知和短暂兜底等待机制。
- 如果目标应用无法恢复，保留“已复制，请手动粘贴”的反馈。
- 不采用旧式进程类型转换 API，也不依赖运行时隐藏 Dock 的补丁。

## 验证方式

自动检查：

- 断言面板激活策略始终为 `.accessory`；
- 断言代码不再要求 `.regular` 激活策略；
- 保留现有键盘命令、焦点恢复和粘贴授权回归测试；
- 完整测试、Release 构建、签名检查和 `git diff --check` 全部通过。

人工验收：

1. 在输入框中打开 funPaste，Dock 不出现 funPaste 图标；
2. 搜索框能够输入；
3. 方向键和 Tab 能切换选项；
4. Esc 能关闭面板；
5. Enter 和双击能正确粘贴；
6. 多次打开和关闭面板，Dock 始终没有 funPaste 图标。
