import SwiftUI

public struct PromptComposerView: View {
    @State private var state: PromptComposerState

    private let onCancel: () -> Void
    private let onCopy: (Clip) -> Void
    private let onPaste: (Clip) -> Void

    public init(
        prompt: Clip,
        onCancel: @escaping () -> Void,
        onCopy: @escaping (Clip) -> Void,
        onPaste: @escaping (Clip) -> Void
    ) {
        _state = State(initialValue: PromptComposerState(prompt: prompt))
        self.onCancel = onCancel
        self.onCopy = onCopy
        self.onPaste = onPaste
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    templateContext
                    variableEditors
                    additionalContextEditor
                    resultPreview
                }
                .padding(24)
            }
            Divider().opacity(0.45)
            actions
        }
        .frame(minWidth: 600, minHeight: 520)
        .background(FunPasteTheme.ink)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(FunPasteTheme.accent)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(FunPasteLocalization.string("promptComposer.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FunPasteTheme.lilac)
                Text(state.prompt.title)
                    .font(.title3.bold())
                Text(state.prompt.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var templateContext: some View {
        editorSection(
            title: FunPasteLocalization.string("promptComposer.templateContext"),
            description: FunPasteLocalization.string("promptComposer.templateDescription")
        ) {
            Text(state.prompt.content)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.9))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder private var variableEditors: some View {
        if state.requiresFeatureDescription {
            editorSection(
                title: FunPasteLocalization.string("promptComposer.featureDescription"),
                description: FunPasteLocalization.string("promptComposer.featureVariable")
            ) {
                multilineEditor(
                    text: $state.featureDescription,
                    guidance: FunPasteLocalization.string("promptComposer.featureGuidance")
                )
            }
        }
        if state.requiresTechnicalConstraint {
            editorSection(
                title: FunPasteLocalization.string("promptComposer.technicalConstraints"),
                description: FunPasteLocalization.string("promptComposer.technicalVariable")
            ) {
                multilineEditor(
                    text: $state.technicalConstraint,
                    guidance: FunPasteLocalization.string("promptComposer.technicalGuidance")
                )
            }
        }
    }

    private var additionalContextEditor: some View {
        editorSection(
            title: FunPasteLocalization.string("promptComposer.additionalContext"),
            description: FunPasteLocalization.string("promptComposer.additionalDescription")
        ) {
            multilineEditor(
                text: $state.additionalContext,
                guidance: FunPasteLocalization.string("promptComposer.additionalGuidance")
            )
        }
    }

    private var resultPreview: some View {
        editorSection(
            title: FunPasteLocalization.string("promptComposer.preview"),
            description: FunPasteLocalization.string(
                state.canSubmit ? "promptComposer.previewReady" : "promptComposer.previewIncomplete"
            )
        ) {
            Text(state.resolvedContent)
                .font(.body.monospaced())
                .foregroundStyle(state.canSubmit ? Color.primary.opacity(0.9) : Color.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button(FunPasteLocalization.string("common.cancel"), action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button(FunPasteLocalization.string("common.copy")) { onCopy(state.preparedClip) }
                .disabled(!state.canSubmit)
            Button(FunPasteLocalization.string("promptComposer.generateAndPaste")) { onPaste(state.preparedClip) }
                .buttonStyle(.borderedProminent)
                .tint(FunPasteTheme.accent)
                .foregroundStyle(FunPasteTheme.ink)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!state.canSubmit)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func editorSection<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func multilineEditor(text: Binding<String>, guidance: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(FunPasteLocalization.format("promptComposer.guidance", guidance))
                .font(.caption)
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
            TextEditor(text: text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 96)
        }
        .padding(8)
        .frame(minHeight: 120)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.12)))
    }
}
