import SwiftUI
import FunPasteUI

@main
struct FunPastePreview: App {
    var body: some Scene {
        WindowGroup("funPaste") {
            RibbonDeckView()
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
