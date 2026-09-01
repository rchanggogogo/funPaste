@MainActor
public enum PasteAttemptCoordinator {
    @discardableResult
    public static func perform(
        authorization: PasteEventAuthorization,
        prepareForPaste: (@escaping @MainActor () -> Void) -> Void,
        postPasteEvent: @escaping @MainActor () -> Void
    ) -> Bool {
        let hadAccessBeforeAttempt = authorization.requestIfNeeded()
        prepareForPaste(postPasteEvent)
        return hadAccessBeforeAttempt
    }
}

@MainActor
public enum PasteEventPostingCoordinator {
    public static func perform(
        postPasteEvent: () -> Void,
        onPasteEventPosted: () -> Void
    ) {
        postPasteEvent()
        onPasteEventPosted()
    }
}
