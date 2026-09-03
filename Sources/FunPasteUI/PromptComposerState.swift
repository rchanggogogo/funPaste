import Combine
import Foundation
import OSLog

private let promptComposerLogger = Logger(subsystem: "com.changlei.funPaste", category: "Prompt编辑器")

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

public enum PromptComposerField: Sendable {
    case featureDescription
    case technicalConstraint
    case additionalContext
}

@MainActor
public final class PromptComposerSession: ObservableObject {
    @Published public var state: PromptComposerState
    public var focusedField: PromptComposerField

    public init(prompt: Clip) {
        let state = PromptComposerState(prompt: prompt)
        self.state = state
        if state.requiresFeatureDescription {
            focusedField = .featureDescription
        } else if state.requiresTechnicalConstraint {
            focusedField = .technicalConstraint
        } else {
            focusedField = .additionalContext
        }
    }

    @discardableResult
    public func insert(_ content: String, replacementRange: NSRange) -> Bool {
        let currentValue: String
        switch focusedField {
        case .featureDescription:
            currentValue = state.featureDescription
        case .technicalConstraint:
            currentValue = state.technicalConstraint
        case .additionalContext:
            currentValue = state.additionalContext
        }

        guard replacementRange.location <= currentValue.utf16.count,
              replacementRange.length <= currentValue.utf16.count - replacementRange.location
        else {
            return false
        }

        let updatedValue = (currentValue as NSString).replacingCharacters(in: replacementRange, with: content)
        switch focusedField {
        case .featureDescription:
            state.featureDescription = updatedValue
        case .technicalConstraint:
            state.technicalConstraint = updatedValue
        case .additionalContext:
            state.additionalContext = updatedValue
        }
        promptComposerLogger.notice(
            "Prompt 状态已更新，字段：\(String(describing: self.focusedField), privacy: .public)，变更前：\(currentValue.utf16.count)，变更后：\(updatedValue.utf16.count)"
        )
        return true
    }
}
