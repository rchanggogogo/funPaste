@preconcurrency import ApplicationServices

@MainActor
public struct PasteEventAuthorization {
    public static let live = PasteEventAuthorization(
        preflight: { CGPreflightPostEventAccess() },
        request: { CGRequestPostEventAccess() },
        fallbackPreflight: { AXIsProcessTrusted() },
        fallbackRequest: {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
    )

    private let preflight: () -> Bool
    private let request: () -> Bool
    private let fallbackPreflight: () -> Bool
    private let fallbackRequest: () -> Bool

    public init(
        preflight: @escaping () -> Bool,
        request: @escaping () -> Bool,
        fallbackPreflight: @escaping () -> Bool = { false },
        fallbackRequest: @escaping () -> Bool = { false }
    ) {
        self.preflight = preflight
        self.request = request
        self.fallbackPreflight = fallbackPreflight
        self.fallbackRequest = fallbackRequest
    }

    @discardableResult
    public func requestIfNeeded() -> Bool {
        if preflight() || fallbackPreflight() {
            return true
        }
        return request() || fallbackRequest()
    }
}
