import SwiftUI

@MainActor
public struct FunPastePreviewApp: App {
    @StateObject private var store = ClipboardStore()

    public init() {}

    public var body: some Scene {
        WindowGroup("funPaste") {
            RibbonDeckView(store: store)
        }
    }
}
