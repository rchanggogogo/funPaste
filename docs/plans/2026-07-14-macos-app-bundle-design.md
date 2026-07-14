# macOS App 图标与打包设计

## 目标

为 funPaste 生成原创图标，并将现有 Swift Package 打包为可双击启动的未签名 `funPaste.app`。

## 图标

- 视觉：深墨蓝圆角底、暖柑橘交叠剪贴卡片、淡紫高光。
- 风格：简洁、高对比、在 Finder 小尺寸下仍可识别。
- 交付：一个 1024×1024 主图和 macOS 所需的 `.icns` 图标文件。
- 图标为原创资产，不使用 PasteEasy 或其他产品的视觉元素。

## 应用包

- Bundle 名称：`funPaste`。
- Bundle Identifier：`com.changlei.funPaste`。
- 最低系统版本：macOS 14。
- 打包脚本先使用 `swift build -c release` 生成可执行文件，再创建 `dist/funPaste.app/Contents` 结构，写入 `Info.plist`、复制可执行文件与 `AppIcon.icns`。
- App 为本地未签名构建，可在当前 Mac 上打开；首次打开若被 Gatekeeper 拦截，使用“右键打开”。

## 发布边界

- 第一版不包含 Developer ID 签名、公证、DMG 或 App Store 上架。
- 若要分发给其他用户，后续需要 Apple Developer 账号、Developer ID Application 证书、`codesign` 与 `xcrun notarytool`。

## 验收标准

- `dist/funPaste.app` 存在且目录结构完整。
- Finder/Dock 显示原创 funPaste 图标。
- 双击或 `open dist/funPaste.app` 可启动菜单栏 App。
- `Contents/MacOS/funPaste` 与 release 构建产物一致。
- 不破坏当前 Swift Package 构建与测试命令。
