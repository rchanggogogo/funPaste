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

    public static let builtInPromptTemplates: [Clip] = [
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
            id: "effective-ai-collaboration-prompt",
            category: .prompt,
            title: "让 AI 高效完成任务",
            content: "目标：{{功能描述}}。约束与参考：{{技术约束}}。先复述你理解的结果和边界，指出缺失的关键信息；信息足够后直接完成任务。结束前运行可用的测试、构建或对比检查，修复发现的问题，并用简短清单给出改动与验证证据。",
            source: "Claude Code 最佳实践"
        ),
        Clip(
            id: "requirements-interview-prompt",
            category: .prompt,
            title: "先访谈，再写需求规格",
            content: "我想实现{{功能描述}}，当前约束是{{技术约束}}。先围绕用户体验、范围、边界情况、数据与安全、技术取舍和验收标准逐步访谈我；不要问显而易见的问题。信息充分后，输出一份自包含的规格，明确目标、非目标、关键流程、异常场景和端到端验收步骤。此阶段不要修改代码。",
            source: "Claude Code 最佳实践"
        ),
        Clip(
            id: "explore-plan-implement-prompt",
            category: .prompt,
            title: "先探索规划，再实现",
            content: "请完成{{功能描述}}，并遵守{{技术约束}}。先只读探索相关代码、现有测试和项目约定，确认真实调用链与可复用模式；再列出最小修改计划和验收标准；随后按计划实现。完成后运行最相关的测试和静态检查，修复失败，并报告修改文件、关键取舍和验证结果。",
            source: "Claude Code 最佳实践"
        ),
        Clip(
            id: "root-cause-debugging-prompt",
            category: .prompt,
            title: "定位并修复根因",
            content: "问题现象：{{功能描述}}。环境、日志或限制：{{技术约束}}。先复现问题并沿调用链定位根因，不要通过吞掉错误、跳过检查或硬编码绕过症状。先添加能稳定复现的失败测试，再做最小修复；运行相关测试与构建直到通过，并提供根因、修复原理和验证证据。",
            source: "Claude Code 最佳实践"
        ),
        Clip(
            id: "code-review-prompt",
            category: .prompt,
            title: "审查代码变更",
            content: "请审查{{功能描述}}，重点关注{{技术约束}}。先理解变更目标和项目约定，再检查正确性、数据丢失与兼容性风险、安全、并发与性能、架构一致性以及测试缺口。只报告可操作且有证据的问题，按阻塞、重要、建议排序；每项注明文件与位置、影响、触发场景和最小修复建议。若没有问题，明确说明剩余风险和已检查范围。",
            source: "GitHub 工程实践"
        ),
        Clip(
            id: "test-generation-prompt",
            category: .prompt,
            title: "补齐高价值测试",
            content: "请为{{功能描述}}补齐测试，遵守{{技术约束}}。先阅读实现和现有测试风格，识别关键路径、边界值、错误场景和曾经容易回归的行为；优先写确定性强、验证可观察结果的测试，避免测试实现细节和不必要的 Mock。运行相关测试，修复由本次工作引入的失败，并说明每个新增测试防住了什么风险。",
            source: "GitHub 工程实践"
        ),
        Clip(
            id: "behavior-preserving-refactor-prompt",
            category: .prompt,
            title: "保持行为的最小重构",
            content: "请重构{{功能描述}}，约束是{{技术约束}}。先用现有测试和必要的特征测试锁定当前可观察行为，再指出具体复杂度与最小重构边界。保持公共接口和行为不变，不顺手扩展功能；分小步修改并持续运行测试。最后对比重构前后，说明简化了什么、哪些行为得到验证，以及仍未处理的风险。",
            source: "Awesome Copilot"
        ),
        Clip(
            id: "gpt-5p6-outcome-contract-prompt",
            category: .prompt,
            title: "用结果契约完成复杂任务",
            content: "角色：你是负责交付{{功能描述}}的协作助手。目标：先明确用户可见的最终结果，再选择最有效的完成路径。成功标准：结果完整、符合{{技术约束}}，关键判断有可核查证据，要求的检查全部通过。自主边界：安全且范围内的读取、分析、修改和验证可直接进行；外部写入、破坏性操作、付费行为或扩大范围前必须确认。输出：先给结论，再给关键证据、完成动作和阻塞项。停止规则：已有充分证据时结束；缺少必要信息时只询问最小缺失字段；验证失败时修复并重试，不用表面绕过代替根因解决。",
            source: "OpenAI GPT-5.6 指南"
        ),
        Clip(
            id: "gpt-5p6-prompt-audit-prompt",
            category: .prompt,
            title: "精简并校准 Prompt",
            content: "请审查并优化以下 Prompt：{{功能描述}}。使用场景与不可改变的约束：{{技术约束}}。保留用户可见结果、成功标准、停止条件、安全与权限边界、证据要求、工具路由和输出格式；删除重复规则、无效示例、模型已能稳定完成的过程说明及无关工具；找出互相矛盾或过度使用“始终、绝不、只能”的规则，并改成清晰的判断条件。输出精简后的 Prompt、删除或改写项及原因，以及一组用于对比新旧 Prompt 的代表性测试。不要一次引入与已观察问题无关的新规则。",
            source: "OpenAI GPT-5.6 指南"
        ),
        Clip(
            id: "gpt-5p6-grounded-research-prompt",
            category: .prompt,
            title: "做有证据边界的研究",
            content: "请研究{{功能描述}}，来源范围与限制为{{技术约束}}。先用简短且有区分度的关键词做一次广泛检索；只有当核心事实、日期、负责人、标识、指定材料或关键主张仍缺少支持时再继续检索。只引用实际读取的来源，把引用放在对应主张旁；明确区分来源直接支持的事实与推断，说明来源冲突。没有证据不等于事实为否；证据不足时缩小结论或明确缺失信息，不猜测。输出结论、关键证据、分歧或不确定性和下一步。",
            source: "OpenAI GPT-5.6 指南"
        )
    ]

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
    ] + builtInPromptTemplates + [
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

    public static func presentationItems(history: [Clip], library: ContentLibrary = .seeded) -> [Clip] {
        let staticItems = demo.filter { $0.category == .image }
        let recentItems = history.isEmpty ? demo.filter { $0.category == .recent } : history
        return recentItems + library.items + staticItems
    }
}
