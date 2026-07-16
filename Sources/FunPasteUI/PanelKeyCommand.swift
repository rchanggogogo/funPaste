import Foundation

public enum PanelKeyCommand: Equatable, Sendable {
    case dismiss
    case selectPrevious
    case selectNext
    case paste
    case selectPreviousCategory
    case selectNextCategory

    public init?(keyCode: UInt16, shiftPressed: Bool = false) {
        switch keyCode {
        case 53: self = .dismiss
        case 126: self = .selectPrevious
        case 125: self = .selectNext
        case 123: self = .selectPreviousCategory
        case 124: self = .selectNextCategory
        case 36, 76: self = .paste
        case 48: self = shiftPressed ? .selectPreviousCategory : .selectNextCategory
        default: return nil
        }
    }
}

public extension Notification.Name {
    static let funPastePanelKeyCommand = Notification.Name("funPaste.panelKeyCommand")
    static let funPastePanelDidShow = Notification.Name("funPaste.panelDidShow")
}
