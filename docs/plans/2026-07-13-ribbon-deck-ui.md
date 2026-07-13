# funPaste「丝带卡组」UI 实现计划

> **给执行代理：** 必须逐项执行以下任务；每个任务都遵循先测试、确认失败、最小实现、确认通过的顺序。

**目标：** 创建一个可运行、可在浏览器预览的 funPaste 高保真界面原型，并提供对应的 SwiftUI 代码骨架。

**架构：** 浏览器原型承担视觉验收和交互演示；SwiftUI 代码使用相同的内容模型、颜色与界面层级，供后续 Xcode 项目接入。数据只使用内置演示内容，不连接系统剪贴板或网络服务。

**技术栈：** 原生 HTML/CSS/JavaScript、SwiftUI、Swift Package Manager。

---

### 任务 1：建立项目与可验证的内容模型

**文件：**
- 创建：`Package.swift`
- 创建：`Sources/FunPasteUI/Clip.swift`
- 创建：`Tests/FunPasteUITests/ClipTests.swift`

- [ ] **步骤 1：编写失败测试**

```swift
func test默认分类顺序是最近复制后接Prompt() {
    XCTAssertEqual(Array(ClipCategory.defaultOrder.prefix(2)), [.recent, .prompt])
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`swift test`

预期：失败，因为 `ClipCategory` 尚不存在。

- [ ] **步骤 3：最小实现内容类型与默认分类顺序**

```swift
enum ClipCategory: String, CaseIterable {
    case recent, prompt, pinned, image, file
    static let defaultOrder: [ClipCategory] = [.recent, .prompt, .pinned, .image, .file]
}
```

- [ ] **步骤 4：重新运行测试并确认通过**

运行：`swift test`

预期：所有测试通过。

### 任务 2：完成浏览器高保真「丝带卡组」原型

**文件：**
- 创建：`preview/index.html`
- 创建：`preview/styles.css`
- 创建：`preview/app.js`
- 创建：`preview/README.md`

- [ ] **步骤 1：编写失败的静态结构检查**

```sh
test -f preview/index.html && rg -q '最近复制' preview/index.html && rg -q 'Prompt' preview/index.html
```

- [ ] **步骤 2：运行检查并确认失败**

运行：上述命令。

预期：失败，因为预览文件尚不存在。

- [ ] **步骤 3：实现响应式卡组、分类丝带、搜索、卡片焦点和 Prompt 变量编辑**

页面必须展示「最近复制」为默认分类、居中的放大选中卡片、两侧露出的相邻卡片、深墨蓝与暖柑橘配色，并在移动宽度下改为紧凑卡组。

- [ ] **步骤 4：重新运行结构检查并在浏览器中检查桌面和移动布局**

运行：`python3 -m http.server 4173 --directory preview`

预期：桌面和移动视图均能加载，点击分类和卡片会更新界面。

### 任务 3：实现 SwiftUI 界面骨架

**文件：**
- 创建：`Sources/FunPasteUI/RibbonDeckView.swift`
- 创建：`Sources/FunPasteUI/FunPastePreviewApp.swift`
- 修改：`Package.swift`

- [ ] **步骤 1：编写失败测试**

```swift
func testPrompt模板保留变量字段() {
    XCTAssertTrue(Clip.demo.first { $0.category == .prompt }!.content.contains("{{功能描述}}"))
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`swift test`

预期：失败，因为演示 Prompt 尚不存在。

- [ ] **步骤 3：实现 SwiftUI 卡组视图与内置 Prompt 模板**

`RibbonDeckView` 使用可访问的按钮、动态字体、系统颜色回退与减少动态效果适配。当前不实现系统剪贴板监听。

- [ ] **步骤 4：重新运行测试并确认通过**

运行：`swift test`

预期：所有测试通过。

### 任务 4：验证与交付

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：运行完整测试与静态检查**

运行：`swift test && git diff --check`

预期：退出码为 0。

- [ ] **步骤 2：运行浏览器原型并进行桌面/移动截图检查**

确认最近复制位于第一位、Prompt 位于第二位、卡片可选中、变量编辑可见、无 PasteEasy 素材或文案复制。

- [ ] **步骤 3：记录当前环境限制**

在 README 中注明：当前机器未安装完整 Xcode，iOS 模拟器验证待 Xcode 安装后执行。
