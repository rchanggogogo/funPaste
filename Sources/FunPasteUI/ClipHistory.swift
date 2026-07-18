import Foundation

public struct ClipHistory: Sendable, Codable {
    public static let defaultMaximumCount = 200

    public private(set) var clips: [Clip] = []
    public let maximumCount: Int

    public init(maximumCount: Int = Self.defaultMaximumCount, clips: [Clip] = []) {
        self.maximumCount = maximumCount
        self.clips = Array(clips.prefix(maximumCount))
    }

    public func limited(to maximumCount: Int) -> ClipHistory {
        ClipHistory(maximumCount: maximumCount, clips: clips)
    }

    public mutating func record(
        _ content: String,
        source: String = FunPasteLocalization.string("history.source.clipboard")
    ) {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.isSensitiveClipboardContent else { return }

        clips.removeAll { $0.content == normalized }

        clips.insert(
            Clip(
                id: UUID().uuidString,
                category: .recent,
                title: normalized.prefix(48).description,
                content: normalized,
                source: source
            ),
            at: 0
        )

        if clips.count > maximumCount {
            clips.removeLast(clips.count - maximumCount)
        }
    }

    public mutating func recordImage(
        _ data: Data,
        title: String = FunPasteLocalization.string("history.image.title"),
        source: String = FunPasteLocalization.string("history.source.clipboard")
    ) {
        guard !data.isEmpty else { return }
        clips.removeAll { $0.imageData == data }
        clips.insert(
            Clip(
                id: UUID().uuidString,
                category: .image,
                title: title,
                content: FunPasteLocalization.format(
                    "history.image.description",
                    ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
                ),
                source: source,
                imageData: data
            ),
            at: 0
        )

        if clips.count > maximumCount {
            clips.removeLast(clips.count - maximumCount)
        }
    }

    public mutating func recordFiles(_ urls: [URL], source: String = "Finder") {
        var seen = Set<URL>()
        let normalizedURLs = urls.compactMap { url -> URL? in
            guard url.isFileURL else { return nil }
            let normalizedURL = url.standardizedFileURL
            return seen.insert(normalizedURL).inserted ? normalizedURL : nil
        }
        guard !normalizedURLs.isEmpty else { return }

        clips.removeAll { $0.fileURLs == normalizedURLs }
        let title = normalizedURLs.count == 1
            ? normalizedURLs[0].lastPathComponent
            : FunPasteLocalization.format("history.files.count", normalizedURLs.count)
        clips.insert(
            Clip(
                id: UUID().uuidString,
                category: .file,
                title: title,
                content: normalizedURLs.map(\.path).joined(separator: "\n"),
                source: source,
                fileURLs: normalizedURLs
            ),
            at: 0
        )

        if clips.count > maximumCount {
            clips.removeLast(clips.count - maximumCount)
        }
    }

    @discardableResult
    public mutating func refreshFileReferences(
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> Bool {
        var didChange = false
        clips = clips.compactMap { clip in
            guard let fileURLs = clip.fileURLs, !fileURLs.isEmpty else { return clip }
            let existingURLs = fileURLs.filter(fileExists)
            guard existingURLs.count != fileURLs.count else { return clip }
            didChange = true
            guard !existingURLs.isEmpty else { return nil }
            return Clip(
                id: clip.id,
                category: .file,
                title: existingURLs.count == 1
                    ? existingURLs[0].lastPathComponent
                    : FunPasteLocalization.format("history.files.count", existingURLs.count),
                content: existingURLs.map(\.path).joined(separator: "\n"),
                source: clip.source,
                fileURLs: existingURLs
            )
        }
        return didChange
    }
}

private extension String {
    var isSensitiveClipboardContent: Bool {
        let keywords = ["password", "passcode", "one-time code", "otp", "密码", "验证码", "一次性口令", "银行卡"]
        let lowercasedContent = lowercased()
        return keywords.contains { lowercasedContent.contains($0) }
    }
}
