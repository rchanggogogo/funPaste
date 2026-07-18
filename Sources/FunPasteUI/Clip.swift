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
    public let fileURLs: [URL]?
    public let promptMetadata: PromptMetadata?

    public init(
        id: String,
        category: ClipCategory,
        title: String,
        content: String,
        source: String,
        imageData: Data? = nil,
        fileURLs: [URL]? = nil,
        promptMetadata: PromptMetadata? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.content = content
        self.source = source
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.promptMetadata = promptMetadata
    }

    public func replacingPromptMetadata(_ metadata: PromptMetadata?) -> Clip {
        Clip(
            id: id,
            category: category,
            title: title,
            content: content,
            source: source,
            imageData: imageData,
            fileURLs: fileURLs,
            promptMetadata: metadata
        )
    }

    func replacingContent(_ newContent: String) -> Clip {
        Clip(
            id: id,
            category: category,
            title: title,
            content: newContent,
            source: source,
            imageData: imageData,
            fileURLs: fileURLs,
            promptMetadata: promptMetadata
        )
    }

    static func formattedBuiltInPromptContent(id: Clip.ID, content: String) -> String {
        let paragraphStarts: [Clip.ID: [String]] = [
            "development-prompt": ["技术约束：", "先阅读项目结构"],
            "plain-language-prompt": ["先给结论"],
            "effective-ai-collaboration-prompt": ["约束与参考：", "先复述", "信息足够后", "结束前"],
            "requirements-interview-prompt": ["当前约束是", "先围绕", "信息充分后", "此阶段不要"],
            "explore-plan-implement-prompt": ["先只读探索", "再列出", "随后按计划", "完成后"],
            "root-cause-debugging-prompt": ["环境、日志或限制：", "先复现问题", "先添加", "运行相关测试"],
            "code-review-prompt": ["先理解变更目标", "再检查正确性", "只报告", "若没有问题"],
            "test-generation-prompt": ["先阅读实现", "优先写", "运行相关测试"],
            "behavior-preserving-refactor-prompt": ["先用现有测试", "再指出", "保持公共接口", "分小步修改", "最后对比"],
            "gpt-5p6-outcome-contract-prompt": ["目标：", "成功标准：", "自主边界：", "输出：", "停止规则："],
            "gpt-5p6-prompt-audit-prompt": ["使用场景与不可改变的约束：", "保留用户可见结果", "删除重复规则", "找出互相矛盾", "输出精简后的", "不要一次引入"],
            "gpt-5p6-grounded-research-prompt": ["来源范围与限制为", "先用简短", "只有当核心事实", "只引用实际读取", "明确区分", "没有证据不等于", "证据不足时", "输出结论"]
        ]
        guard let starts = paragraphStarts[id] else { return content }
        return starts.reduce(content) { result, start in
            result.replacingOccurrences(of: start, with: "\n\n\(start)")
        }
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static var builtInPromptTemplates: [Clip] { [
        Clip(
            id: "development-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.development.title"),
            content: FunPasteLocalization.string("prompt.development.content"),
            source: FunPasteLocalization.string("prompt.source.builtIn")
        ),
        Clip(
            id: "plain-language-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.plainLanguage.title"),
            content: FunPasteLocalization.string("prompt.plainLanguage.content"),
            source: FunPasteLocalization.string("prompt.source.builtIn")
        ),
        Clip(
            id: "effective-ai-collaboration-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.effectiveCollaboration.title"),
            content: FunPasteLocalization.string("prompt.effectiveCollaboration.content"),
            source: FunPasteLocalization.string("prompt.source.claude")
        ),
        Clip(
            id: "requirements-interview-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.requirementsInterview.title"),
            content: FunPasteLocalization.string("prompt.requirementsInterview.content"),
            source: FunPasteLocalization.string("prompt.source.claude")
        ),
        Clip(
            id: "explore-plan-implement-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.explorePlanImplement.title"),
            content: FunPasteLocalization.string("prompt.explorePlanImplement.content"),
            source: FunPasteLocalization.string("prompt.source.claude")
        ),
        Clip(
            id: "root-cause-debugging-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.rootCause.title"),
            content: FunPasteLocalization.string("prompt.rootCause.content"),
            source: FunPasteLocalization.string("prompt.source.claude")
        ),
        Clip(
            id: "code-review-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.codeReview.title"),
            content: FunPasteLocalization.string("prompt.codeReview.content"),
            source: FunPasteLocalization.string("prompt.source.github")
        ),
        Clip(
            id: "test-generation-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.testGeneration.title"),
            content: FunPasteLocalization.string("prompt.testGeneration.content"),
            source: FunPasteLocalization.string("prompt.source.github")
        ),
        Clip(
            id: "behavior-preserving-refactor-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.refactor.title"),
            content: FunPasteLocalization.string("prompt.refactor.content"),
            source: "Awesome Copilot"
        ),
        Clip(
            id: "gpt-5p6-outcome-contract-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.outcomeContract.title"),
            content: FunPasteLocalization.string("prompt.outcomeContract.content"),
            source: FunPasteLocalization.string("prompt.source.openAI")
        ),
        Clip(
            id: "gpt-5p6-prompt-audit-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.audit.title"),
            content: FunPasteLocalization.string("prompt.audit.content"),
            source: FunPasteLocalization.string("prompt.source.openAI")
        ),
        Clip(
            id: "gpt-5p6-grounded-research-prompt",
            category: .prompt,
            title: FunPasteLocalization.string("prompt.research.title"),
            content: FunPasteLocalization.string("prompt.research.content"),
            source: FunPasteLocalization.string("prompt.source.openAI")
        )
    ] }

    public static var demo: [Clip] { [
        Clip(
            id: "product-principle",
            category: .recent,
            title: FunPasteLocalization.string("demo.productPrinciple.title"),
            content: FunPasteLocalization.string("demo.productPrinciple.content"),
            source: FunPasteLocalization.string("demo.productPrinciple.source")
        ),
        Clip(
            id: "swiftui-focus",
            category: .recent,
            title: FunPasteLocalization.string("demo.swiftUIFocus.title"),
            content: "@State private var selectedID: Clip.ID?",
            source: "Xcode"
        ),
        Clip(
            id: "apple-hig",
            category: .recent,
            title: "Apple Human Interface Guidelines",
            content: FunPasteLocalization.string("demo.appleHIG.content"),
            source: "Safari"
        ),
    ] + builtInPromptTemplates + [
        Clip(
            id: "pinned-address",
            category: .pinned,
            title: FunPasteLocalization.string("demo.address.title"),
            content: FunPasteLocalization.string("demo.address.content"),
            source: FunPasteLocalization.string("library.source.favorite")
        ),
        Clip(
            id: "image-palette",
            category: .image,
            title: FunPasteLocalization.string("demo.palette.title"),
            content: FunPasteLocalization.string("demo.palette.content"),
            source: FunPasteLocalization.string("demo.palette.source")
        ),
        Clip(
            id: "product-file",
            category: .file,
            title: FunPasteLocalization.string("demo.file.title"),
            content: FunPasteLocalization.string("demo.file.content"),
            source: "Finder"
        )
    ] }

    public static func presentationItems(history: [Clip], library: ContentLibrary = .seeded) -> [Clip] {
        let staticItems = demo.filter { $0.category == .image }
        let recentItems = history.isEmpty ? demo.filter { $0.category == .recent } : history
        return recentItems + library.items + staticItems
    }
}
