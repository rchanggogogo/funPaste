# macOS App 图标与打包实施计划

> **供自动化执行：** 按任务顺序执行；图标、脚本和包结构均需实际验证。

**目标：** 生成原创 funPaste 图标，并构建可双击运行的未签名 `dist/funPaste.app`。

**架构：** 以一张 1024×1024 PNG 为图标源，转换为 `.iconset` 和 `AppIcon.icns`。打包脚本构建 release 二进制，复制到标准 macOS bundle，并写入 `Info.plist`。

**技术栈：** Swift Package Manager、macOS `iconutil`、`plutil`、Bash、PNG、ICNS。

---

### 任务 1：生成并验证图标源图

**文件：**

- 新建：`Assets/AppIcon/app-icon-1024.png`

- [ ] 使用图像生成工具创建 1024×1024 PNG：深墨蓝圆角方形背景、暖柑橘两张交叠剪贴卡片、淡紫高光，无文字、无水印、留出四周安全边距。

- [ ] 使用图像查看工具检查小尺寸可识别性、边缘完整性和无文字约束。

- [ ] 将最终 PNG 保存为 `Assets/AppIcon/app-icon-1024.png`，不覆盖任何现有资产。

- [ ] 验证：`sips -g pixelWidth -g pixelHeight Assets/AppIcon/app-icon-1024.png` 输出 `1024` × `1024`。

- [ ] 提交：`git add Assets/AppIcon/app-icon-1024.png && git commit -m "feat: add funPaste app icon source"`

### 任务 2：转换 macOS 图标资源

**文件：**

- 新建：`Assets/AppIcon/AppIcon.iconset/`
- 新建：`Assets/AppIcon/AppIcon.icns`
- 新建：`scripts/make-icon.sh`

- [ ] 新建脚本，将 1024 PNG 生成 `icon_16x16.png` 至 `icon_512x512@2x.png` 十个标准尺寸，并运行 `iconutil -c icns`：

```sh
sips -z 16 16 "$source" --out "$iconset/icon_16x16.png"
sips -z 32 32 "$source" --out "$iconset/icon_16x16@2x.png"
iconutil -c icns "$iconset" -o "$assets/AppIcon.icns"
```

- [ ] 运行 `bash scripts/make-icon.sh`，预期生成 `Assets/AppIcon/AppIcon.icns`。

- [ ] 验证：`file Assets/AppIcon/AppIcon.icns` 输出包含 `Mac OS X icon`；`iconutil -c iconset` 可反向解包且包含 10 个 PNG。

- [ ] 提交：`git add Assets/AppIcon scripts/make-icon.sh && git commit -m "build: generate macOS icon resource"`

### 任务 3：构建标准 macOS 应用包

**文件：**

- 新建：`scripts/build-app.sh`
- 新建（脚本生成）：`dist/funPaste.app/Contents/Info.plist`
- 新建（脚本生成）：`dist/funPaste.app/Contents/MacOS/funPaste`
- 新建（脚本生成）：`dist/funPaste.app/Contents/Resources/AppIcon.icns`
- 修改：`.gitignore`

- [ ] 将 `dist/` 加入 `.gitignore`，避免提交构建产物。

- [ ] 新建打包脚本：先 `swift build -c release --product FunPastePreview`，再创建 bundle 目录，复制 release 二进制和 `.icns`，写入如下核心信息：

```xml
<key>CFBundleExecutable</key><string>funPaste</string>
<key>CFBundleIdentifier</key><string>com.changlei.funPaste</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
```

- [ ] 运行 `bash scripts/build-app.sh`，预期生成 `dist/funPaste.app`。

- [ ] 验证：

```sh
plutil -lint dist/funPaste.app/Contents/Info.plist
test -x dist/funPaste.app/Contents/MacOS/funPaste
cmp .build/release/FunPastePreview dist/funPaste.app/Contents/MacOS/funPaste
test -f dist/funPaste.app/Contents/Resources/AppIcon.icns
```

- [ ] 提交：`git add .gitignore scripts/build-app.sh && git commit -m "build: package funPaste as macOS app"`

### 任务 4：启动与回归验证

**文件：**

- 修改：`README.md`

- [ ] 运行 `swift build && swift run FunPasteUITestRunner`，预期完整构建和全部测试通过。

- [ ] 运行 `open dist/funPaste.app`，检查 funPaste 进程存在、菜单栏 App 启动，并在 Finder 或 Dock 中检查图标显示。

- [ ] 在 README 的快速开始增加：`bash scripts/build-app.sh` 生成 `dist/funPaste.app`；注明此构建未签名，仅适用于本机或“右键打开”。

- [ ] 运行 `git diff --check && git status --short`，预期仅源码、图标、脚本、README 和计划文档被跟踪；`dist/` 不显示。

- [ ] 提交：`git add README.md && git commit -m "docs: describe macOS app build"`
