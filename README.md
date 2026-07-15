# funPaste

复制只是开始。funPaste 一键构建 Prompt，把灵感、剪贴板和常用指令留在手边。按下 `Shift + Command + V`，搜索、收藏、粘贴一气呵成。

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

## 安装测试版

测试版同时支持 Apple 芯片和 Intel Mac，要求 macOS 14 或更高版本。

1. 从本仓库的 Releases 下载最新 `.dmg` 文件。
2. 双击 `.dmg`，将 `funPaste.app` 拖入“应用程序（Applications）”文件夹。
3. 首次打开时按住 Control 点按 App，选择“打开”，再确认打开。此测试版未经过 Apple 公证，因此会显示安全提示。
4. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 funPaste 控制电脑；这是自动粘贴所需的权限。

发布者可运行以下命令创建通用 DMG：

```sh
bash scripts/build-dmg.sh 1.0.0
```

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

构建可双击启动的 macOS App：

```sh
bash scripts/build-app.sh
open dist/funPaste.app
```

该构建用于本机使用；首次分发给其他 Mac 前，仍需要使用 Apple Developer 证书签名并完成公证。

## 快捷键

| 按键 | 功能 |
| --- | --- |
| `Shift + Command + V` | 打开或收起 funPaste |
| `Tab` / `Shift + Tab` | 切换分类 |
| `↑` / `↓` | 选择内容 |
| `Enter` | 粘贴选中内容 |
| `Esc` | 关闭面板 |
