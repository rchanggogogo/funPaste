<p align="center">
  <img src="Assets/AppIcon/app-icon-1024.png" width="112" alt="funPaste 图标">
</p>

<h1 align="center">funPaste</h1>

<p align="center">
  <strong>复制只是开始。</strong><br>
  把剪贴历史、常用内容和 Prompt 留在手边，一次快捷键，随时找回并粘贴。
</p>

<p align="center">
  <a href="https://github.com/rchanggogogo/funPaste/actions/workflows/ci.yml"><img src="https://github.com/rchanggogogo/funPaste/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-FF9F5B.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-121728.svg" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138.svg" alt="Swift 6">
</p>

<p align="center"><kbd>⇧ Shift</kbd> + <kbd>⌘ Command</kbd> + <kbd>V</kbd></p>

<p align="center">
  <img src="Assets/README/hero.svg" width="100%" alt="funPaste 快捷粘贴面板预览">
</p>

## 为什么是 funPaste？

很多剪贴板工具只是把复制记录排成一张长列表。funPaste 更像一副随手展开的内容卡组：刚复制的文字、截图、收藏和 Prompt 都在同一个面板里，键盘就能完成查找、选择和粘贴。

| ⚡ 不打断思路 | ✦ Prompt 也是一等公民 | ◉ 本地优先 |
| --- | --- | --- |
| 从任何 App 按 `Shift + Command + V` 唤起，方向键选择，`Enter` 粘贴回原处。 | 保存常用 Prompt，用 `{{功能描述}}`、`{{技术约束}}` 在粘贴前快速补全。 | 当前没有账号、遥测、广告或网络同步；历史、Prompt 和收藏保存在本机。 |

## 能做什么

- 记录文本和图片剪贴历史，重复内容自动置顶。
- 搜索最近复制的内容，并用键盘快速选择。
- 创建、编辑和删除自己的 Prompt 与收藏。
- 一键收藏最近复制的文字或图片。
- 在粘贴前补全 Prompt 变量。
- 随时暂停记录或清空全部历史。
- 以菜单栏 Agent 运行，不占用 Dock。

## 立即体验

### 下载测试版

支持 Apple 芯片和 Intel Mac，需要 macOS 14 或更高版本。

1. 从 [Releases](https://github.com/rchanggogogo/funPaste/releases) 下载最新 `.dmg`。
2. 将 `funPaste.app` 拖入“应用程序”文件夹。
3. 首次打开时按住 Control 点按 App，选择“打开”。当前测试版尚未经过 Apple 公证。
4. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 funPaste；该权限仅用于自动粘贴。

### 从源码运行

```sh
git clone https://github.com/rchanggogogo/funPaste.git
cd funPaste
swift run FunPastePreview
```

启动后按 `Shift + Command + V`，或者先运行行为检查：

```sh
swift run FunPasteUITestRunner
```

## 快捷键

| 按键 | 动作 |
| --- | --- |
| `Shift + Command + V` | 打开或收起面板 |
| `Tab` / `Shift + Tab` | 切换分类 |
| `↑` / `↓` | 移动选择 |
| `Enter` | 粘贴选中内容 |
| `Esc` | 关闭面板 |

## 构建 macOS App

创建本机可双击启动的 ad-hoc 签名 App：

```sh
bash scripts/build-app.sh
open dist/funPaste.app
```

创建同时支持 Apple 芯片和 Intel Mac 的 DMG：

```sh
bash scripts/build-dmg.sh 1.0.0
```

正式分发前仍需使用 Apple Developer 证书签名并完成公证。

## 隐私不是脚注

funPaste 会接触你复制的内容，因此隐私边界必须说清楚：

- 当前应用代码不发起网络请求，也不记录剪贴板正文到日志。
- 剪贴历史和内容库通过 macOS `UserDefaults` 持久化，应用层没有额外加密。
- 敏感内容过滤只是启发式规则，不能保证识别所有密码、Token 或个人信息。
- 辅助功能权限仅用于模拟 `Command + V`；拒绝后仍可复制并手动粘贴。

完整说明见 [PRIVACY.md](PRIVACY.md)。

## 一起把它变得更顺手

Bug 报告、交互想法和 Pull Request 都欢迎。开始前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)；安全问题请遵循 [SECURITY.md](SECURITY.md)，不要在公开 Issue 中披露漏洞细节。

## License

funPaste 代码以 [MIT License](LICENSE) 开源。
