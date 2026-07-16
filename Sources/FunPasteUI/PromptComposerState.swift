import Foundation

public struct PromptComposerState: Sendable {
    public let prompt: Clip
    public var featureDescription = ""
    public var technicalConstraint = ""
    public var additionalContext = ""

    public init(prompt: Clip) {
        self.prompt = prompt
    }

    public var requiresFeatureDescription: Bool {
        prompt.content.contains("{{功能描述}}")
    }

    public var requiresTechnicalConstraint: Bool {
        prompt.content.contains("{{技术约束}}")
    }

    public var canSubmit: Bool {
        (!requiresFeatureDescription || !trimmedFeatureDescription.isEmpty) &&
            (!requiresTechnicalConstraint || !trimmedTechnicalConstraint.isEmpty)
    }

    public var resolvedContent: String {
        var content = prompt.content
            .replacingOccurrences(of: "{{功能描述}}", with: trimmedFeatureDescription)
            .replacingOccurrences(of: "{{技术约束}}", with: trimmedTechnicalConstraint)

        if !trimmedAdditionalContext.isEmpty {
            content += "\n\n补充上下文：\n\(trimmedAdditionalContext)"
        }
        return content
    }

    public var preparedClip: Clip {
        Clip(
            id: prompt.id,
            category: prompt.category,
            title: prompt.title,
            content: resolvedContent,
            source: prompt.source,
            imageData: prompt.imageData,
            fileURLs: prompt.fileURLs,
            promptMetadata: prompt.promptMetadata
        )
    }

    private var trimmedFeatureDescription: String {
        featureDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTechnicalConstraint: String {
        technicalConstraint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAdditionalContext: String {
        additionalContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
