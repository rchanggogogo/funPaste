import AppKit
import SwiftUI

public struct RibbonDeckView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store: ClipboardStore
    @State private var category: ClipCategory = .recent
    @State private var selectedID: Clip.ID?
    @State private var searchText = ""
    @State private var isEditingPrompt = false
    @State private var featureDescription = ""
    @State private var technicalConstraint = ""

    private let compact: Bool
    private let dismissPanel: (() -> Void)?
    private let prepareForPaste: (@MainActor @Sendable () -> Void)?

    public init(store: ClipboardStore, compact: Bool = false, dismissPanel: (() -> Void)? = nil, prepareForPaste: (@MainActor @Sendable () -> Void)? = nil) {
        self.store = store
        self.compact = compact
        self.dismissPanel = dismissPanel
        self.prepareForPaste = prepareForPaste
    }

    private var visibleClips: [Clip] {
        let categories: Set<ClipCategory> = category == .recent ? [.recent, .prompt, .image] : [category]
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.clips.filter { clip in
            categories.contains(clip.category) && (query.isEmpty || clip.title.localizedCaseInsensitiveContains(query) || clip.content.localizedCaseInsensitiveContains(query))
        }
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 24 / 255, green: 30 / 255, blue: 53 / 255), FunPasteTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.14)))

            VStack(spacing: 14) {
                header
                ribbon
                headline
                historyList
                if isEditingPrompt { promptEditor }
                footer
            }
            .padding(18)
        }
        .padding(8)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: category)
        .onAppear { selectedID = visibleClips.first?.id }
        .onChange(of: category) { _, _ in selectedID = visibleClips.first?.id }
        .onReceive(NotificationCenter.default.publisher(for: .funPastePanelDidShow)) { _ in
            resetForOpening()
        }
        .onExitCommand { dismissPanel?() }
        .onReceive(NotificationCenter.default.publisher(for: .funPastePanelKeyCommand)) { notification in
            guard let command = notification.object as? PanelKeyCommand else { return }
            handlePanelKeyCommand(command)
        }
        .onMoveCommand { direction in
            switch direction {
            case .up: moveSelection(forward: false)
            case .down: moveSelection(forward: true)
            default: break
            }
        }
        .onKeyPress(.return) {
            pasteSelectedClip()
            return .handled
        }
    }

    private var header: some View {
        HStack {
            Label("funPaste", systemImage: "square.on.square.intersection.dashed")
                .font(.title3.bold())
            Spacer()
            if compact {
                Button(action: dismissPanel ?? {}) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.1), in: Circle())
                .pointingCursor()
                .accessibilityLabel("关闭 funPaste")
            }
        }
    }

    private var ribbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ClipCategory.defaultOrder, id: \.self) { item in
                    Button {
                        category = item
                        searchText = ""
                        isEditingPrompt = false
                    } label: {
                        Text(item.label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(category == item ? FunPasteTheme.ink : .secondary)
                            .background(category == item ? FunPasteTheme.accent : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    .accessibilityLabel("切换到\(item.label)")
                }
            }
            .padding(4)
        }
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var headline: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(category.label.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(FunPasteTheme.lilac)
                Text(category.headline)
                    .font(.title3.bold())
            }
            Spacer()
            Text("\(visibleClips.count)")
                .font(.caption.weight(.bold))
                .padding(8)
                .background(FunPasteTheme.lilac.opacity(0.16), in: Circle())
        }
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 9) {
                    if visibleClips.isEmpty {
                        ContentUnavailableView("没有找到相关内容", systemImage: "magnifyingglass", description: Text("换个关键词，或切换分类继续浏览。"))
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(visibleClips) { clip in
                            ClipRow(clip: clip, isSelected: selectedID == clip.id)
                                .id(clip.id)
                                .contentShape(Rectangle())
                                .onTapGesture { select(clip) }
                                .onTapGesture(count: 2) { pasteAndDismiss(clip) }
                                .pointingCursor()
                                .accessibilityAddTraits(selectedID == clip.id ? .isSelected : [])
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .onChange(of: selectedID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("补全这个 Prompt").font(.headline)
                Spacer()
                Button { isEditingPrompt = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    .accessibilityLabel("关闭 Prompt 编辑")
            }
            TextField("功能描述", text: $featureDescription).textFieldStyle(.roundedBorder)
            TextField("技术约束", text: $technicalConstraint).textFieldStyle(.roundedBorder)
            HStack {
                Button("复制") { copyPreparedPrompt() }.buttonStyle(.bordered).pointingCursor()
                Spacer()
                Button("生成并粘贴") { pastePreparedPrompt() }
                    .buttonStyle(.borderedProminent)
                    .tint(FunPasteTheme.accent)
                    .pointingCursor()
            }
        }
        .padding(13)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FunPasteTheme.accent.opacity(0.42)))
    }

    private var footer: some View {
        Label {
            TextField("搜索剪贴历史", text: $searchText)
                .textFieldStyle(.plain)
        } icon: { Image(systemName: "magnifyingglass") }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func select(_ clip: Clip) {
        selectedID = clip.id
        isEditingPrompt = clip.category == .prompt
    }

    private func copyPreparedPrompt() {
        guard let prompt = selectedClip else { return }
        store.copy(preparedPrompt(from: prompt))
        dismissPanel?()
    }

    private func pastePreparedPrompt() {
        guard let prompt = selectedClip else { return }
        store.paste(preparedPrompt(from: prompt), prepareForPaste: prepareForPaste ?? {})
    }

    private func pasteAndDismiss(_ clip: Clip) {
        store.paste(clip, prepareForPaste: prepareForPaste ?? {})
    }

    private func moveSelection(forward: Bool) {
        let currentIndex = visibleClips.firstIndex { $0.id == selectedID }
        let nextIndex = forward
            ? SelectionNavigator.nextIndex(current: currentIndex, count: visibleClips.count)
            : SelectionNavigator.previousIndex(current: currentIndex, count: visibleClips.count)
        guard let nextIndex else { return }
        selectedID = visibleClips[nextIndex].id
    }

    private func pasteSelectedClip() {
        guard let selectedClip else { return }
        if selectedClip.category == .prompt {
            store.paste(preparedPrompt(from: selectedClip), prepareForPaste: prepareForPaste ?? {})
        } else {
            pasteAndDismiss(selectedClip)
        }
    }

    private func handlePanelKeyCommand(_ command: PanelKeyCommand) {
        switch command {
        case .dismiss:
            dismissPanel?()
        case .selectPrevious:
            moveSelection(forward: false)
        case .selectNext:
            moveSelection(forward: true)
        case .paste:
            pasteSelectedClip()
        case .selectPreviousCategory:
            category = CategoryNavigator.previous(before: category)
            searchText = ""
            isEditingPrompt = false
        case .selectNextCategory:
            category = CategoryNavigator.next(after: category)
            searchText = ""
            isEditingPrompt = false
        }
    }

    private func resetForOpening() {
        category = QuickPanelController.defaultCategoryOnOpen
        searchText = ""
        isEditingPrompt = false
        selectedID = store.clips.first { [.recent, .prompt, .image].contains($0.category) }?.id
    }

    private var selectedClip: Clip? {
        store.clips.first { $0.id == selectedID }
    }

    private func preparedPrompt(from prompt: Clip) -> Clip {
        Clip(
            id: prompt.id,
            category: prompt.category,
            title: prompt.title,
            content: prompt.content
                .replacingOccurrences(of: "{{功能描述}}", with: featureDescription.isEmpty ? "待补充功能" : featureDescription)
                .replacingOccurrences(of: "{{技术约束}}", with: technicalConstraint.isEmpty ? "遵循现有项目风格" : technicalConstraint),
            source: prompt.source
        )
    }
}

private struct ClipRow: View {
    let clip: Clip
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            preview
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(clip.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(clip.category.label).font(.caption2).foregroundStyle(.secondary)
                }
                Text(clip.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(clip.source).font(.caption2).foregroundStyle(FunPasteTheme.mint.opacity(0.8))
            }
            Spacer(minLength: 0)
            if isSelected { Image(systemName: "return").font(.caption).foregroundStyle(FunPasteTheme.accent) }
        }
        .padding(12)
        .background(.white.opacity(isSelected ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isSelected ? FunPasteTheme.accent : .white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1))
    }

    @ViewBuilder private var preview: some View {
        if let imageData = clip.imageData, let image = NSImage(data: imageData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: clip.symbol)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private extension ClipCategory {
    var label: String {
        switch self {
        case .recent: "最近复制"
        case .prompt: "Prompt"
        case .pinned: "收藏"
        case .image: "图片"
        case .file: "文件"
        }
    }

    var headline: String {
        switch self {
        case .recent: "刚复制，也最应该先看到"
        case .prompt: "把好问题留在触手可及处"
        case .pinned: "真正值得反复使用的内容"
        case .image: "刚复制的图片，也在这里"
        case .file: "文件引用，不再散落在记忆里"
        }
    }
}

private extension Clip {
    var symbol: String {
        switch category {
        case .recent: source == "Xcode" ? "command" : "text.alignleft"
        case .prompt: "sparkles"
        case .pinned: "pin.fill"
        case .image: "photo"
        case .file: "doc.text"
        }
    }
}

private extension View {
    func pointingCursor() -> some View {
        onHover { isHovering in
            (isHovering ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
    }
}
