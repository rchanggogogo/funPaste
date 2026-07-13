import Foundation

public enum ClipCategory: String, CaseIterable, Equatable, Sendable, Codable {
    case recent
    case prompt
    case pinned
    case image
    case file

    public static let defaultOrder: [ClipCategory] = [
        .recent,
        .prompt,
        .pinned,
        .image,
        .file
    ]
}

public struct Clip: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let category: ClipCategory
    public let title: String
    public let content: String
    public let source: String
    public let imageData: Data?

    public init(id: String, category: ClipCategory, title: String, content: String, source: String, imageData: Data? = nil) {
        self.id = id
        self.category = category
        self.title = title
        self.content = content
        self.source = source
        self.imageData = imageData
    }

    public static let demo: [Clip] = [
        Clip(
            id: "product-principle",
            category: .recent,
            title: "产品体验优先的实现原则",
            content: "我只负责把控需求；技术方案、架构和实现细节由你决定。首要原则是保证用户体验。",
            source: "备忘录"
        ),
        Clip(
            id: "swiftui-focus",
            category: .recent,
            title: "SwiftUI 卡片焦点状态",
            content: "@State private var selectedID: Clip.ID?",
            source: "Xcode"
        ),
        Clip(
            id: "apple-hig",
            category: .recent,
            title: "Apple Human Interface Guidelines",
            content: "设计应该清晰、可预测，并尊重用户已掌握的系统习惯。",
            source: "Safari"
        ),
        Clip(
            id: "development-prompt",
            category: .prompt,
            title: "请帮我完成这个功能",
            content: "请帮我完成{{功能描述}}。技术约束：{{技术约束}}。先阅读项目结构，说明修改方案，修改代码并运行检查。",
            source: "内置 Prompt"
        ),
        Clip(
            id: "plain-language-prompt",
            category: .prompt,
            title: "把复杂内容说清楚",
            content: "请用面向初学者的中文解释以下内容，先给结论，再补充必要的背景。",
            source: "内置 Prompt"
        ),
        Clip(
            id: "pinned-address",
            category: .pinned,
            title: "常用收件地址",
            content: "上海市静安区 · 个人工作室 · 请提前联系确认收件时间",
            source: "收藏"
        ),
        Clip(
            id: "image-palette",
            category: .image,
            title: "柔和日落色板",
            content: "温暖柑橘、雾紫与深墨蓝的配色参考",
            source: "截图"
        ),
        Clip(
            id: "product-file",
            category: .file,
            title: "funPaste 产品想法.md",
            content: "剪贴历史、常用内容和 Prompt 模板的一体化整理方案。",
            source: "Finder"
        )
    ]

    public static func presentationItems(history: [Clip]) -> [Clip] {
        guard !history.isEmpty else { return demo }
        let reusableItems = demo.filter { $0.category != .recent }
        return history + reusableItems
    }
}
