# funPaste

funPaste 是一个本地优先的剪贴历史与 Prompt 内容库界面原型。

## 当前包含

- 原创「丝带卡组」快捷面板：最近复制默认聚焦，Prompt 作为第二入口。
- 深墨蓝、暖柑橘、淡紫元数据的视觉系统。
- 浏览器高保真预览：分类、搜索、卡片选择和 Prompt 变量编辑。
- 可编译的 macOS SwiftUI 预览 App。

## 运行

```sh
swift run FunPasteUITestRunner
swift run FunPastePreview
```

浏览器预览：

```sh
cd preview
python3 -m http.server 4173
```

打开 `http://localhost:4173` 查看桌面和移动响应式界面。

## 当前限制

本机只安装了 Command Line Tools，未安装完整 Xcode 与 iOS 模拟器。因此 macOS SwiftUI 预览可编译；iPhone/iPad 真机与模拟器验证需在安装 Xcode 后进行。当前版本不读取系统剪贴板，不请求网络权限，也不执行 AI 调用。
