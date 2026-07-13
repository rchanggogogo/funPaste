import Foundation

public enum PanelKeyCommand: Equatable, Sendable {
    case dismiss
    case selectPrevious
    case selectNext
    case paste

    public init?(keyCode: UInt16) {
        switch keyCode {
        case 53: self = .dismiss
        case 126: self = .selectPrevious
        case 125: self = .selectNext
        case 36, 76: self = .paste
        default: return nil
        }
    }
}

public extension Notification.Name {
    static let funPastePanelKeyCommand = Notification.Name("funPaste.panelKeyCommand")
}
