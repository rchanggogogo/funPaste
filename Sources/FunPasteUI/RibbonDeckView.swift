import AppKit
import SwiftUI

public struct RibbonDeckView: View {
    public static let newLibraryItemButtonHitSize: CGFloat = 36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store: ClipboardStore
    @State private var category: ClipCategory = .recent
    @State private var selectedID: Clip.ID?
    @State private var searchText = ""
    @State private var promptForSheet: Clip?
    @State private var libraryEditorState = LibraryEditorState()
    @State private var itemPendingDeletion: Clip?
    @State private var promptFilter: PromptLibraryFilter = .all
    @State private var insertsIntoPrompt = false
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @AppStorage("funPaste.promptSortOrder") private var promptSortRawValue = PromptSortOrder.smart.rawValue

    private let compact: Bool
    private let dismissPanel: (() -> Void)?
    private let pasteClip: ((Clip) -> Void)?
    private let prepareForPaste: (@MainActor @Sendable (@escaping @MainActor () -> Void) -> Void)?
    private let onUsePrompt: ((Clip) -> Void)?

    public init(
        store: ClipboardStore,
        compact: Bool = false,
        dismissPanel: (() -> Void)? = nil,
        pasteClip: ((Clip) -> Void)? = nil,
        prepareForPaste: (@MainActor @Sendable (@escaping @MainActor () -> Void) -> Void)? = nil,
        onUsePrompt: ((Clip) -> Void)? = nil
    ) {
        self.store = store
        self.compact = compact
        self.dismissPanel = dismissPanel
        self.pasteClip = pasteClip
        self.prepareForPaste = prepareForPaste
        self.onUsePrompt = onUsePrompt
    }

    private var visibleClips: [Clip] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if category == .prompt {
            return store.library.prompts(
                collection: promptFilter.collection,
                favoritesOnly: promptFilter == .favorites,
                archived: promptFilter == .archived,
                query: query,
                sortOrder: PromptSortOrder(rawValue: promptSortRawValue) ?? .smart
            )
        }

        let categories: Set<ClipCategory> = category == .recent ? [.recent, .prompt, .image, .file] : [category]
        return store.clips.filter { clip in
            categories.contains(clip.category) &&
                clip.promptMetadata?.isArchived != true &&
                (query.isEmpty || clip.title.localizedCaseInsensitiveContains(query) || clip.content.localizedCaseInsensitiveContains(query))
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
                if category == .prompt { promptFilterBar }
                historyList
                if libraryEditorState.isPresented { libraryEditor }
                footer
            }
            .padding(18)
        }
        .padding(8)
        .overlay(alignment: .top) {
            if let message = store.feedbackMessage {
                Label(message, systemImage: "info.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FunPasteTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FunPasteTheme.mint, in: Capsule())
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
                    .padding(.top, 66)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: category)
        .onAppear {
            selectedID = visibleClips.first?.id
            launchAtLogin.refresh()
        }
        .onChange(of: category) { _, _ in selectedID = visibleClips.first?.id }
        .onReceive(NotificationCenter.default.publisher(for: .funPastePanelDidShow)) { notification in
            insertsIntoPrompt = notification.object as? Bool ?? false
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
            activateSelectedClip()
            return .handled
        }
        .confirmationDialog(
            FunPasteLocalization.string("delete.warning"),
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(FunPasteLocalization.string("common.delete"), role: .destructive) { deletePendingItem() }
            Button(FunPasteLocalization.string("common.cancel"), role: .cancel) { itemPendingDeletion = nil }
        } message: {
            Text(FunPasteLocalization.format("delete.confirmation", itemPendingDeletion?.title ?? ""))
        }
        .sheet(item: $promptForSheet) { prompt in
            PromptComposerView(
                prompt: prompt,
                onCancel: { promptForSheet = nil },
                onCopy: { preparedPrompt in
                    store.copy(preparedPrompt)
                    store.recordPromptUse(id: prompt.id)
                    promptForSheet = nil
                },
                onPaste: { preparedPrompt in
                    promptForSheet = nil
                    store.recordPromptUse(id: prompt.id)
                    store.paste(preparedPrompt, prepareForPaste: prepareForPaste ?? { $0() })
                }
            )
            .frame(idealWidth: 720, idealHeight: 720)
        }
    }

    private var header: some View {
        HStack {
            Label("funPaste", systemImage: "square.on.square.intersection.dashed")
                .font(.title3.bold())
            Spacer()
            Menu {
                Toggle(
                    FunPasteLocalization.string("settings.launchAtLogin"),
                    isOn: Binding(
                        get: { launchAtLogin.state.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .disabled(launchAtLogin.state == .unavailable)

                if launchAtLogin.state == .requiresApproval {
                    Text(FunPasteLocalization.string("settings.launchAtLogin.requiresApproval"))
                    Button(FunPasteLocalization.string("settings.launchAtLogin.openSystemSettings")) {
                        launchAtLogin.openSystemSettings()
                    }
                } else if launchAtLogin.state == .unavailable {
                    Text(FunPasteLocalization.string("settings.launchAtLogin.unavailable"))
                } else if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                }

                Divider()
                Section(FunPasteLocalization.string("settings.historyLimit")) {
                    ForEach(ClipboardStore.availableHistoryMaximumCounts, id: \.self) { maximumCount in
                        Button {
                            store.setHistoryMaximumCount(maximumCount)
                        } label: {
                            if store.history.maximumCount == maximumCount {
                                Label(
                                    FunPasteLocalization.format("settings.historyLimit.count", maximumCount),
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(FunPasteLocalization.format("settings.historyLimit.count", maximumCount))
                            }
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle().fill(.white.opacity(0.1))
                    Image(systemName: "gearshape")
                        .font(.caption.weight(.semibold))
                }
                .frame(width: 28, height: 28)
                .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .contentShape(Circle())
            .clipShape(Circle())
            .pointingCursor()
            .accessibilityLabel(FunPasteLocalization.string("settings.title"))
            if compact {
                Button(action: dismissPanel ?? {}) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.1), in: Circle())
                .pointingCursor()
                .accessibilityLabel(FunPasteLocalization.string("close.funPaste"))
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
                    .accessibilityLabel(FunPasteLocalization.format("category.switch", item.label))
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
            if category == .prompt || category == .pinned {
                Button {
                    startCreatingLibraryItem(category: category)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(
                            width: Self.newLibraryItemButtonHitSize,
                            height: Self.newLibraryItemButtonHitSize
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(FunPasteTheme.accent, in: Circle())
                .foregroundStyle(FunPasteTheme.ink)
                .pointingCursor()
                .accessibilityLabel(
                    FunPasteLocalization.string(category == .prompt ? "prompt.new" : "favorite.new")
                )
            }
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
                        ContentUnavailableView(
                            FunPasteLocalization.string("empty.title"),
                            systemImage: "magnifyingglass",
                            description: Text(FunPasteLocalization.string("empty.description"))
                        )
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(visibleClips) { clip in
                            historyRow(for: clip)
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

    @ViewBuilder
    private func historyRow(for clip: Clip) -> some View {
        let row = ClipRow(
            clip: clip,
            isSelected: selectedID == clip.id,
            isPinned: store.isPinned(clip),
            canPin: !insertsIntoPrompt && (clip.category == .recent || clip.category == .image),
            isPromptFavorite: clip.promptMetadata?.isFavorite == true,
            onPin: { togglePin(clip) },
            onPromptFavorite: { togglePromptFavorite(clip) },
            onEdit: { startEditingLibraryItem(clip) },
            onArchive: { archivePrompt(clip) },
            onRestore: { restorePrompt(clip) },
            onDelete: { itemPendingDeletion = clip }
        )
        .id(clip.id)
        .contentShape(Rectangle())
        .pointingCursor()
        .accessibilityAddTraits(selectedID == clip.id ? .isSelected : [])

        if insertsIntoPrompt {
            Button(action: { select(clip) }) {
                row
            }
            .buttonStyle(.plain)
            .accessibilityLabel(clip.title)
        } else {
            row
                .onTapGesture(count: 2) { activate(clip) }
                .onTapGesture { select(clip) }
        }
    }

    private var promptFilterBar: some View {
        HStack(spacing: 2) {
            promptFilterButton(.all)
            promptFilterButton(.favorites)
            promptFilterButton(.archived)
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 18)
                .padding(.horizontal, 4)
            Menu {
                ForEach(PromptCollection.allCases, id: \.self) { collection in
                    Button(collection.label) {
                        selectPromptFilter(.collection(collection))
                    }
                }
            } label: {
                Label(
                    promptFilter.collection?.label ?? FunPasteLocalization.string("common.category"),
                    systemImage: "folder"
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(promptFilter.collection == nil ? Color.secondary : FunPasteTheme.ink)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(
                        promptFilter.collection == nil ? .clear : FunPasteTheme.mint,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .pointingCursor()
            Spacer(minLength: 0)
            Menu {
                ForEach(PromptSortOrder.allCases, id: \.self) { order in
                    Button {
                        promptSortRawValue = order.rawValue
                    } label: {
                        if promptSortRawValue == order.rawValue {
                            Label(order.label, systemImage: "checkmark")
                        } else {
                            Text(order.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .pointingCursor()
            .accessibilityLabel(FunPasteLocalization.string("prompt.sort"))
        }
        .padding(4)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08))
        )
    }

    private func promptFilterButton(_ filter: PromptLibraryFilter) -> some View {
        Button(filter.label) {
            selectPromptFilter(filter)
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .foregroundStyle(promptFilter == filter ? FunPasteTheme.ink : .secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            promptFilter == filter ? FunPasteTheme.mint : .clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .pointingCursor()
    }

    private func selectPromptFilter(_ filter: PromptLibraryFilter) {
        promptFilter = filter
        selectedID = nil
    }

    private var libraryEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(libraryEditorTitle)
                        .font(.headline)
                    if libraryEditorState.category == .prompt {
                        Text(FunPasteLocalization.string("editor.variablesHint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { closeLibraryEditor() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .pointingCursor()
                    .accessibilityLabel(FunPasteLocalization.string("editor.close"))
            }
            TextField(
                FunPasteLocalization.string(
                    libraryEditorState.category == .prompt
                        ? "editor.prompt.titlePlaceholder"
                        : "editor.favorite.titlePlaceholder"
                ),
                text: $libraryEditorState.title
            )
            .textFieldStyle(.roundedBorder)
            TextEditor(text: $libraryEditorState.content)
                .font(.body)
                .frame(minHeight: 88, maxHeight: 110)
                .padding(6)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.white.opacity(0.12)))
            if libraryEditorState.content.isEmpty {
                Text(
                    FunPasteLocalization.string(
                        libraryEditorState.category == .prompt
                            ? "editor.prompt.contentPlaceholder"
                            : "editor.favorite.contentPlaceholder"
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if libraryEditorState.category == .prompt {
                HStack {
                    Picker(FunPasteLocalization.string("editor.primaryCollection"), selection: $libraryEditorState.promptCollection) {
                        ForEach(PromptCollection.allCases, id: \.self) { collection in
                            Text(collection.label).tag(collection)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField(FunPasteLocalization.string("editor.tagsPlaceholder"), text: $libraryEditorState.tagsText)
                        .textFieldStyle(.roundedBorder)
                }
                TextField(FunPasteLocalization.string("editor.sourceURLPlaceholder"), text: $libraryEditorState.sourceURL)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Button(FunPasteLocalization.string("common.cancel")) { closeLibraryEditor() }
                    .buttonStyle(.bordered)
                    .pointingCursor()
                Spacer()
                Button(
                    FunPasteLocalization.string(
                        libraryEditorState.editingItem == nil ? "common.create" : "common.save"
                    )
                ) { saveLibraryEditor() }
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
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
        } icon: { Image(systemName: "magnifyingglass") }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var searchPlaceholder: String {
        category == .prompt
            ? FunPasteLocalization.string("search.prompt")
            : FunPasteLocalization.format("search.category", category.label)
    }

    private var libraryEditorTitle: String {
        if libraryEditorState.editingItem == nil {
            return FunPasteLocalization.string(
                libraryEditorState.category == .prompt ? "editor.prompt.new" : "editor.favorite.new"
            )
        }
        return FunPasteLocalization.string(
            libraryEditorState.category == .prompt ? "editor.prompt.edit" : "editor.favorite.edit"
        )
    }

    private func select(_ clip: Clip) {
        selectedID = clip.id
        switch ClipSelectionResolver.action(
            for: clip.category,
            insertsIntoPrompt: insertsIntoPrompt
        ) {
        case .select:
            break
        case .usePrompt:
            usePrompt(clip)
        case .paste:
            pasteAndDismiss(clip)
        }
    }

    private func pasteAndDismiss(_ clip: Clip) {
        if let pasteClip {
            pasteClip(clip)
        } else {
            store.paste(clip, prepareForPaste: prepareForPaste ?? { $0() })
        }
    }

    private func togglePin(_ clip: Clip) {
        if store.isPinned(clip) {
            store.unpin(clip)
            store.showFeedback(FunPasteLocalization.format("feedback.unpinned", clip.title))
        } else {
            let item = store.pin(clip)
            store.showFeedback(FunPasteLocalization.format("feedback.pinned", item.title))
        }
    }

    private func togglePromptFavorite(_ clip: Clip) {
        store.togglePromptFavorite(id: clip.id)
        let isNowFavorite = !(clip.promptMetadata?.isFavorite ?? false)
        store.showFeedback(
            FunPasteLocalization.format(
                isNowFavorite ? "feedback.promptFavorited" : "feedback.promptUnfavorited",
                clip.title
            )
        )
    }

    private func archivePrompt(_ clip: Clip) {
        store.setPromptArchived(id: clip.id, isArchived: true)
        selectedID = visibleClips.first?.id
        store.showFeedback(FunPasteLocalization.format("feedback.archived", clip.title))
    }

    private func restorePrompt(_ clip: Clip) {
        store.setPromptArchived(id: clip.id, isArchived: false)
        selectedID = visibleClips.first?.id
        store.showFeedback(FunPasteLocalization.format("feedback.restored", clip.title))
    }

    private func startCreatingLibraryItem(category: ClipCategory) {
        libraryEditorState.startCreating(category: category)
    }

    private func startEditingLibraryItem(_ item: Clip) {
        libraryEditorState.startEditing(item)
    }

    private func closeLibraryEditor() {
        libraryEditorState.close()
    }

    private func saveLibraryEditor() {
        let title = libraryEditorState.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = libraryEditorState.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !content.isEmpty else {
            store.showFeedback(FunPasteLocalization.string("feedback.emptyFields"))
            return
        }

        if libraryEditorState.category == .prompt,
           let duplicate = store.duplicatePrompt(
               content: content,
               excludingID: libraryEditorState.editingItem?.id
           ) {
            selectedID = duplicate.id
            closeLibraryEditor()
            store.showFeedback(FunPasteLocalization.format("feedback.duplicate", duplicate.title))
            return
        }

        let savedItem: Clip
        if let item = libraryEditorState.editingItem {
            let metadata = editedPromptMetadata(from: item.promptMetadata)
            store.updateLibraryItem(id: item.id, title: title, content: content, promptMetadata: metadata)
            savedItem = Clip(
                id: item.id,
                category: item.category,
                title: title,
                content: content,
                source: item.source,
                imageData: item.imageData,
                fileURLs: item.fileURLs,
                promptMetadata: metadata
            )
        } else {
            savedItem = store.createLibraryItem(
                category: libraryEditorState.category,
                title: title,
                content: content,
                promptMetadata: libraryEditorState.category == .prompt ? editedPromptMetadata(from: nil) : nil
            )
        }
        selectedID = savedItem.id
        closeLibraryEditor()
        store.showFeedback(FunPasteLocalization.format("feedback.saved", savedItem.title))
    }

    private func editedPromptMetadata(from existing: PromptMetadata?) -> PromptMetadata {
        let tags = libraryEditorState.tagsText
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map(String.init)
        var metadata = existing ?? PromptMetadata()
        metadata.collection = libraryEditorState.promptCollection
        metadata.tags = PromptMetadata.normalizedTags(tags)
        metadata.sourceURL = libraryEditorState.sourceURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        metadata.updatedAt = Date()
        return metadata
    }

    private func deletePendingItem() {
        guard let item = itemPendingDeletion else { return }
        store.deleteLibraryItem(id: item.id)
        if selectedID == item.id { selectedID = visibleClips.first?.id }
        itemPendingDeletion = nil
        store.showFeedback(FunPasteLocalization.format("feedback.deleted", item.title))
    }

    private func moveSelection(forward: Bool) {
        let currentIndex = visibleClips.firstIndex { $0.id == selectedID }
        let nextIndex = forward
            ? SelectionNavigator.nextIndex(current: currentIndex, count: visibleClips.count)
            : SelectionNavigator.previousIndex(current: currentIndex, count: visibleClips.count)
        guard let nextIndex else { return }
        selectedID = visibleClips[nextIndex].id
    }

    private func activateSelectedClip() {
        guard let selectedClip else { return }
        activate(selectedClip)
    }

    private func activate(_ clip: Clip) {
        if clip.category == .prompt {
            usePrompt(clip)
        } else {
            pasteAndDismiss(clip)
        }
    }

    private func usePrompt(_ prompt: Clip) {
        if let onUsePrompt {
            onUsePrompt(prompt)
        } else {
            promptForSheet = prompt
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
            activateSelectedClip()
        case .selectPreviousCategory:
            category = CategoryNavigator.previous(before: category)
            searchText = ""
        case .selectNextCategory:
            category = CategoryNavigator.next(after: category)
            searchText = ""
        }
    }

    private func resetForOpening() {
        store.refreshFileHistory()
        category = QuickPanelController.defaultCategoryOnOpen
        searchText = ""
        promptForSheet = nil
        promptFilter = .all
        libraryEditorState.resetForPanelOpening()
        selectedID = store.clips.first { [.recent, .prompt, .image, .file].contains($0.category) }?.id
    }

    private var selectedClip: Clip? {
        store.clips.first { $0.id == selectedID }
    }

}

private enum PromptLibraryFilter: Hashable {
    case all
    case favorites
    case collection(PromptCollection)
    case archived

    var collection: PromptCollection? {
        if case let .collection(collection) = self { return collection }
        return nil
    }

    var label: String {
        switch self {
        case .all: FunPasteLocalization.string("prompt.filter.all")
        case .favorites: FunPasteLocalization.string("prompt.filter.favorites")
        case let .collection(collection): collection.label
        case .archived: FunPasteLocalization.string("prompt.filter.archived")
        }
    }
}

private struct ClipRow: View {
    let clip: Clip
    let isSelected: Bool
    let isPinned: Bool
    let canPin: Bool
    let isPromptFavorite: Bool
    let onPin: () -> Void
    let onPromptFavorite: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            preview
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(clip.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    if canPin {
                        Button(action: onPin) {
                            Image(systemName: isPinned ? "star.fill" : "star")
                                .foregroundStyle(isPinned ? FunPasteTheme.accent : .secondary)
                        }
                        .buttonStyle(.plain)
                        .pointingCursor()
                        .accessibilityLabel(
                            FunPasteLocalization.string(isPinned ? "favorite.added" : "favorite.add")
                        )
                    }
                    if clip.category == .prompt {
                        Button(action: onPromptFavorite) {
                            Image(systemName: isPromptFavorite ? "star.fill" : "star")
                                .foregroundStyle(isPromptFavorite ? FunPasteTheme.accent : .secondary)
                        }
                        .buttonStyle(.plain)
                        .pointingCursor()
                        .accessibilityLabel(
                            FunPasteLocalization.string(
                                isPromptFavorite ? "prompt.unfavorite" : "prompt.favorite"
                            )
                        )
                    }
                    if clip.category == .prompt || clip.category == .pinned {
                        Menu {
                            Button(FunPasteLocalization.string("common.edit"), action: onEdit)
                            if clip.category == .prompt {
                                if clip.promptMetadata?.isArchived == true {
                                    Button(FunPasteLocalization.string("common.restore"), action: onRestore)
                                    Button(
                                        FunPasteLocalization.string("delete.permanently"),
                                        role: .destructive,
                                        action: onDelete
                                    )
                                } else {
                                    Button(FunPasteLocalization.string("common.archive"), action: onArchive)
                                }
                            } else {
                                Button(
                                    FunPasteLocalization.string("common.delete"),
                                    role: .destructive,
                                    action: onDelete
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .pointingCursor()
                        .accessibilityLabel(
                            FunPasteLocalization.string(
                                clip.category == .prompt
                                    ? "content.manage.prompt"
                                    : "content.manage.favorite"
                            )
                        )
                    }
                    Text(clip.category.label).font(.caption2).foregroundStyle(.secondary)
                }
                Text(clip.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let metadata = clip.promptMetadata {
                        Text(metadata.collection.label)
                        ForEach(metadata.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                        }
                    } else {
                        Text(clip.source)
                    }
                }
                .font(.caption2)
                .foregroundStyle(FunPasteTheme.mint.opacity(0.8))
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
        case .recent: FunPasteLocalization.string("category.recent")
        case .prompt: FunPasteLocalization.string("category.prompt")
        case .pinned: FunPasteLocalization.string("category.pinned")
        case .image: FunPasteLocalization.string("category.image")
        case .file: FunPasteLocalization.string("category.file")
        }
    }

    var headline: String {
        switch self {
        case .recent: FunPasteLocalization.string("category.recent.headline")
        case .prompt: FunPasteLocalization.string("category.prompt.headline")
        case .pinned: FunPasteLocalization.string("category.pinned.headline")
        case .image: FunPasteLocalization.string("category.image.headline")
        case .file: FunPasteLocalization.string("category.file.headline")
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
