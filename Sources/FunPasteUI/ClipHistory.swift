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

    public mutating func record(_ content: String, source: String = "剪贴板") {
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

    public mutating func recordImage(_ data: Data, title: String = "剪贴图片", source: String = "剪贴板") {
        guard !data.isEmpty else { return }
        clips.removeAll { $0.imageData == data }
        clips.insert(
            Clip(
                id: UUID().uuidString,
                category: .image,
                title: title,
                content: "图片 · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))",
                source: source,
                imageData: data
            ),
            at: 0
        )

        if clips.count > maximumCount {
            clips.removeLast(clips.count - maximumCount)
        }
    }
}

private extension String {
    var isSensitiveClipboardContent: Bool {
        let keywords = ["password", "passcode", "one-time code", "otp", "密码", "验证码", "一次性口令", "银行卡"]
        let lowercasedContent = lowercased()
        return keywords.contains { lowercasedContent.contains($0) }
    }
}
