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
        Self.featureDescriptionVariables.contains { prompt.content.contains($0) }
    }

    public var requiresTechnicalConstraint: Bool {
        Self.technicalConstraintVariables.contains { prompt.content.contains($0) }
    }

    public var canSubmit: Bool {
        (!requiresFeatureDescription || !trimmedFeatureDescription.isEmpty) &&
            (!requiresTechnicalConstraint || !trimmedTechnicalConstraint.isEmpty)
    }

    public var resolvedContent: String {
        var content = Self.featureDescriptionVariables.reduce(prompt.content) {
            $0.replacingOccurrences(of: $1, with: trimmedFeatureDescription)
        }
        content = Self.technicalConstraintVariables.reduce(content) {
            $0.replacingOccurrences(of: $1, with: trimmedTechnicalConstraint)
        }

        if !trimmedAdditionalContext.isEmpty {
            content += "\n\n\(FunPasteLocalization.string("promptComposer.additionalSection"))\n\(trimmedAdditionalContext)"
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

    private static let featureDescriptionVariables = ["{{功能描述}}", "{{feature description}}"]
    private static let technicalConstraintVariables = ["{{技术约束}}", "{{technical constraints}}"]
}
