# funPaste

funPaste 是一款本地优先的 macOS 剪贴板管理工具。它把最近复制的内容、常用收藏和 Prompt 模板集中在一个快捷面板中，让复制、查找和粘贴更顺手。

## 核心功能

- 自动记录文本与图片剪贴历史，最新内容优先展示。
- 按 `Shift + Command + V` 从屏幕右侧快速唤起面板。
- 使用 `↑` / `↓` 选择内容，按 `Enter` 粘贴回原应用。
- 使用 `Tab` / `Shift + Tab` 循环切换最近复制、Prompt、收藏、图片和文件。
- 支持搜索剪贴历史。
- 点击其他应用、按 `Esc` 或右上角关闭按钮即可收起面板。
- Prompt 支持新增、编辑、删除；内置模板也可管理。
- 收藏支持新增、编辑、删除。
- 最近复制内容可一键收藏；再次点击星标即可取消收藏。
- Prompt 支持 `{{功能描述}}`、`{{技术约束}}` 变量补全。
- 所有历史、Prompt 和收藏均保存在本机。

## 快速开始

```sh
swift build
swift run FunPastePreview
```

启动后使用 `Shift + Command + V` 打开 funPaste。

运行测试：

```sh
swift run FunPasteUITestRunner
```

## 快捷键

| 按键 | 功能 |
| --- | --- |
| `Shift + Command + V` | 打开或收起 funPaste |
| `Tab` / `Shift + Tab` | 切换分类 |
| `↑` / `↓` | 选择内容 |
| `Enter` | 粘贴选中内容 |
| `Esc` | 关闭面板 |
