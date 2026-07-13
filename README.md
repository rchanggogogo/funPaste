# funPaste

> 本地优先的 macOS 剪贴板管理器：把刚复制的内容、常用收藏和 Prompt 模板，放在一次快捷键即可触达的位置。

funPaste 的第一版聚焦一件事：**少打扰、快选择、马上粘贴**。按下快捷键后，右侧出现窄栏；键盘或鼠标选中内容即可回到原应用继续输入。

## 功能一览

- 自动记录文本与图片剪贴板历史，最新内容默认排在最前。
- `Shift + Command + V` 唤起右侧快捷面板。
- `↑` / `↓` 循环选择历史；`Enter` 粘贴当前选中内容。
- `Esc`、右上角关闭按钮或切换到其他应用时，面板自动收起。
- `Tab` 循环切换“最近复制、Prompt、收藏、图片、文件”；`Shift + Tab` 反向切换。
- 搜索全部可见内容；选择项会自动滚动到可视区域。
- Prompt 支持新增、编辑、删除；内置 Prompt 同样可以管理。
- 收藏支持新增、编辑、删除；最近复制内容可用星标一键收藏，再点一次取消收藏。
- Prompt 支持 `{{功能描述}}`、`{{技术约束}}` 两个变量，粘贴前可补全。
- 剪贴历史与 Prompt/收藏内容库分别保存，清空历史不会删除模板或收藏。

## 快速开始

要求：macOS 14 或更高版本，并安装 Swift 6 工具链。

```sh
git clone <你的仓库地址>
cd funPaste
swift build
swift run FunPastePreview
```

App 启动后会出现在菜单栏。使用 `Shift + Command + V` 打开侧栏。

运行自动回归测试：

```sh
swift run FunPasteUITestRunner
```

## 使用方式

### 剪贴历史

1. 在任意应用中复制文字或图片。
2. 按 `Shift + Command + V` 打开 funPaste。
3. 用方向键或鼠标选择内容。
4. 按 `Enter` 或双击内容，将其粘贴回原应用。

最近复制项右侧的星标是收藏开关：空心星表示未收藏，实心星表示已收藏；再次点击实心星会取消收藏。

### Prompt

切换到“Prompt”分类后，点击标题右侧的 `＋` 可新建模板。填写标题和内容即可保存；表单中会提示变量用法：

```text
请帮我完成{{功能描述}}。
技术约束：{{技术约束}}。
```

Prompt 和收藏项目右侧的 `…` 菜单可编辑或删除。删除前会要求确认，删除后不可撤销。

### 键盘快捷键

| 按键 | 行为 |
| --- | --- |
| `Shift + Command + V` | 打开或收起 funPaste |
| `Tab` / `Shift + Tab` | 正向 / 反向切换分类 |
| `↑` / `↓` | 循环选择内容 |
| `Enter` | 粘贴当前选中内容 |
| `Esc` | 收起面板 |

## 权限与隐私

funPaste 不使用网络服务，也不会把剪贴内容上传到服务器。数据保存在当前 Mac 的 `UserDefaults` 中。

自动粘贴需要 macOS 的“辅助功能”权限。首次尝试粘贴时，App 会请求该权限；若未授权，funPaste 仍会把内容复制到剪贴板，但需要你手动按 `Command + V`。

当前版本会跳过包含以下关键词的文本，避免意外记录常见敏感内容：

```text
password, passcode, one-time code, otp,
密码, 验证码, 一次性口令, 银行卡
```

这是基础关键词过滤，不是完整的数据防泄漏方案；没有关键词的身份证号、Token、私钥等仍可能被记录。图片暂不进行敏感内容识别。

## 项目结构

```text
Sources/
├── FunPastePreview/          # macOS 菜单栏 App 入口
├── FunPasteUI/
│   ├── ClipboardMonitor.swift # 系统剪贴板监听
│   ├── ClipboardStore.swift   # 历史、内容库与本地持久化
│   ├── ContentLibrary.swift   # Prompt / 收藏 CRUD 与去重
│   ├── QuickPanelController.swift # 右侧快捷面板与键盘事件
│   └── RibbonDeckView.swift   # SwiftUI 界面
└── FunPasteUITestRunner/      # 无第三方依赖的回归测试
docs/plans/                    # 已确认的设计与实施计划
preview/                       # 早期网页视觉预览
```

## 关于网页预览

`preview/` 是早期的静态视觉原型，用于展示设计方向；它**不是**当前原生 App，也不会同步 macOS 功能开发。验收与日常使用请始终运行 `FunPastePreview`。

如需查看原型：

```sh
python3 -m http.server 4173 --directory preview
```

然后访问 `http://localhost:4173`。

## 当前边界

- 当前正式实现面向 macOS；iPhone/iPad 版本尚未验证。
- 本项目以 Swift Package 形式提供，尚未包装为已签名、可分发的 `.app` 安装包。
- 自动粘贴依赖系统辅助功能授权。
- 敏感信息过滤仅为关键词规则，不能替代专业安全策略。

## 第一版验收清单

- [x] 剪贴文本与图片历史
- [x] 右侧快捷面板与键盘操作
- [x] 本地 Prompt / 收藏内容库
- [x] Prompt / 收藏新增、编辑、删除
- [x] 最近复制一键收藏与取消收藏
- [x] 本地持久化与自动回归测试

---

funPaste 仍在持续迭代中。第一版的原则不变：先让每一次复制、找到和粘贴都更顺手。
