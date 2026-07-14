# funPaste 菜单栏后台运行设计

## 目标

funPaste 启动后作为菜单栏工具运行，不在 macOS 程序坞中显示图标；通过 `Shift + Command + V` 或菜单栏图标唤起侧边面板时，也不得显示程序坞图标。

## 方案

采用双层配置，覆盖开发运行与打包运行两种方式。

1. 在 `MacAppDelegate.applicationDidFinishLaunching` 中将应用激活策略设为 `.accessory`。这会使 Swift Package 直接运行时成为菜单栏后台工具，同时仍允许侧边面板在唤起时获取键盘焦点。
2. 在 App 包的 `Info.plist` 中写入 `LSUIElement = true`。从 Finder 双击 `funPaste.app` 启动时，系统也会将它识别为菜单栏工具，不加入 Dock。
3. 保留 `MenuBarExtra`、全局快捷键、侧边面板激活逻辑和“退出 funPaste”菜单项，不增加主窗口，也不改变原有快捷键。

## 验收

- 启动 App 后，菜单栏出现 funPaste 图标，Dock 不出现 funPaste 图标。
- 使用 `Shift + Command + V` 和菜单栏“显示 funPaste”均可打开侧边面板，Dock 仍不出现图标。
- 侧边面板继续能接收键盘输入；`Esc` 与菜单栏“退出 funPaste”继续可用。
- 打包后的 `Info.plist` 含有 `LSUIElement = true`。

## 非目标

- 不更改面板外观、内容库、剪贴板记录或快捷键定义。
- 不处理签名、公证和分发流程。
