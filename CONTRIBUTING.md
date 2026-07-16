# 参与贡献

感谢你愿意帮助改进 funPaste。提交改动前，请先搜索现有 Issue 和 Pull Request，避免重复工作。较大的功能或交互调整建议先创建 Feature Request 讨论范围。

## 开发环境

- macOS 14 或更高版本
- Xcode 或 Command Line Tools 提供的 Swift 6 工具链

```sh
git clone https://github.com/rchanggogogo/funPaste.git
cd funPaste
swift build
swift run FunPastePreview
```

启动后按 `Shift + Command + V` 打开面板。

## 验证改动

应用行为变化应在 `Sources/FunPasteUITestRunner/main.swift` 中加入确定性回归检查，并运行：

```sh
swift run FunPasteUITestRunner
git diff --check
```

如果修改了打包、签名、架构或 DMG 布局，还需要运行：

```sh
bash Tests/release-build-tests.sh
```

## 提交规范

- 使用四个空格缩进并遵循 Swift API Design Guidelines。
- 保持文件职责单一，优先使用显式依赖，避免新增全局可变状态。
- 提交信息使用简洁前缀：`feat:`、`fix:`、`docs:`、`build:` 或 `ci:`。
- 不要提交 `.build*`、`dist/`、应用包、DMG、缓存、凭据或签名材料。
- UI 变化请在 Pull Request 中附截图或短录屏。

提交 Pull Request 即表示你同意按本仓库的 MIT License 授权你的贡献。
