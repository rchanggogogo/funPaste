import SwiftUI

public struct RibbonDeckView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var category: ClipCategory = .recent
    @State private var selectedID: Clip.ID? = Clip.demo.first?.id
    @State private var searchText = ""
    @State private var isEditingPrompt = false
    @State private var featureDescription = ""
    @State private var technicalConstraint = ""
    @State private var toastMessage: String?

    public init() {}

    private var visibleClips: [Clip] {
        let categories: Set<ClipCategory> = category == .recent ? [.recent, .prompt] : [category]
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Clip.demo.filter { clip in
            categories.contains(clip.category) && (query.isEmpty || clip.title.localizedCaseInsensitiveContains(query) || clip.content.localizedCaseInsensitiveContains(query))
        }
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 24 / 255, green: 30 / 255, blue: 53 / 255), FunPasteTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                ribbon
                headline
                deck
                if isEditingPrompt { promptEditor }
                footer
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.14)))
            .padding()

            if let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 28)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: category)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedID)
    }

    private var header: some View {
        HStack {
            Label("funPaste", systemImage: "square.on.square.intersection.dashed")
                .font(.title3.bold())
            Spacer()
            Label("本地私密保存", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(FunPasteTheme.mint)
        }
    }

    private var ribbon: some View {
        HStack(spacing: 4) {
            ForEach(ClipCategory.defaultOrder, id: \.self) { item in
                Button {
                    category = item
                    searchText = ""
                    selectedID = visibleClips.first?.id
                    isEditingPrompt = false
                } label: {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(category == item ? FunPasteTheme.ink : .secondary)
                        .background(category == item ? FunPasteTheme.accent : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("切换到\(item.label)")
            }
            Spacer(minLength: 0)
            Text("按住可调整顺序")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(5)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var headline: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.label.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(FunPasteTheme.lilac)
                Text(category.headline)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
            }
            Spacer()
            Text("\(visibleClips.count) 个项目")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(FunPasteTheme.lilac.opacity(0.16), in: Capsule())
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private var deck: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                if visibleClips.isEmpty {
                    ContentUnavailableView("没有找到相关内容", systemImage: "magnifyingglass", description: Text("换个关键词，或回到全部项目继续浏览。"))
                        .frame(width: 520, height: 190)
                } else {
                    ForEach(visibleClips) { clip in
                        ClipCard(clip: clip, isSelected: selectedID == clip.id)
                            .onTapGesture { select(clip) }
                            .accessibilityAddTraits(selectedID == clip.id ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 12)
        }
        .frame(minHeight: 225)
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("准备粘贴").font(.caption.weight(.bold)).foregroundStyle(FunPasteTheme.lilac)
                    Text("补全这个 Prompt").font(.title3.bold())
                }
                Spacer()
                Button { isEditingPrompt = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("关闭 Prompt 编辑")
            }
            TextField("功能描述，例如：增加收藏分组", text: $featureDescription)
                .textFieldStyle(.roundedBorder)
            TextField("技术约束，例如：沿用 SwiftUI", text: $technicalConstraint)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("仅复制") { showToast("Prompt 已复制到剪贴板") }
                    .buttonStyle(.bordered)
                Spacer()
                Button("生成并粘贴") {
                    isEditingPrompt = false
                    showToast("Prompt 已生成并准备粘贴")
                }
                .buttonStyle(.borderedProminent)
                .tint(FunPasteTheme.accent)
            }
        }
        .padding(18)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(FunPasteTheme.accent.opacity(0.42)))
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Label {
                TextField("直接输入即可搜索", text: $searchText)
                    .textFieldStyle(.plain)
            } icon: { Image(systemName: "magnifyingglass") }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Spacer()
            Text("↑↓ 选择  ·  ↵ 粘贴  ·  ⇧↵ 纯文本")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func select(_ clip: Clip) {
        selectedID = clip.id
        if clip.category == .prompt { isEditingPrompt = true }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }
}

private struct ClipCard: View {
    let clip: Clip
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: clip.symbol)
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
                Text(clip.category.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(clip.title)
                .font(.headline)
                .lineLimit(2)
            if clip.category == .image {
                LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                Text(clip.content)
                    .font(clip.source == "Xcode" ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundStyle(clip.source == "Xcode" ? FunPasteTheme.mint : .secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            HStack {
                Text(clip.source).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(isSelected ? "回车粘贴" : "点击选择").font(.caption2).foregroundStyle(isSelected ? FunPasteTheme.accent : .secondary)
            }
        }
        .padding(16)
        .frame(width: 242, height: 192, alignment: .leading)
        .background(.white.opacity(isSelected ? 0.12 : 0.075), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(isSelected ? FunPasteTheme.accent : .white.opacity(0.12), lineWidth: isSelected ? 2 : 1))
        .shadow(color: isSelected ? FunPasteTheme.accent.opacity(0.18) : .black.opacity(0.12), radius: isSelected ? 18 : 8, y: 8)
        .scaleEffect(isSelected ? 1.03 : 0.92)
        .opacity(isSelected ? 1 : 0.7)
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
        case .image: "视觉灵感，也能快速找回"
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
