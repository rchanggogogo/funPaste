import ServiceManagement
import SwiftUI

public enum LaunchAtLoginState: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    public var isEnabled: Bool {
        self == .enabled
    }
}

@MainActor
public protocol LaunchAtLoginServicing: AnyObject {
    var state: LaunchAtLoginState { get }

    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var state: LaunchAtLoginState
    @Published public private(set) var errorMessage: String?

    private let service: any LaunchAtLoginServicing

    public convenience init() {
        self.init(service: SystemLaunchAtLoginService())
    }

    public init(service: any LaunchAtLoginServicing) {
        self.service = service
        state = service.state
    }

    public func refresh() {
        state = service.state
    }

    public func setEnabled(_ isEnabled: Bool) {
        errorMessage = nil

        do {
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    public func openSystemSettings() {
        service.openSystemSettings()
    }
}

@MainActor
private final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private let service = SMAppService.mainApp
    private let fallback = UserLaunchAgentService()

    private var shouldUseFallback: Bool {
        fallback.state == .enabled || service.status == .notFound
    }

    var state: LaunchAtLoginState {
        if shouldUseFallback {
            return fallback.state
        }

        switch service.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func register() throws {
        if shouldUseFallback {
            try fallback.register()
        } else {
            try service.register()
        }
    }

    func unregister() throws {
        if fallback.state == .enabled {
            try fallback.unregister()
        } else {
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
public final class UserLaunchAgentService: LaunchAtLoginServicing {
    public static let label = "com.changlei.funPaste.launch-at-login"

    private let appURL: URL
    private let launchAgentURL: URL
    private let fileManager: FileManager

    public convenience init() {
        let fileManager = FileManager.default
        self.init(
            appURL: Bundle.main.bundleURL,
            launchAgentsDirectory: fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents", isDirectory: true),
            fileManager: fileManager
        )
    }

    public init(
        appURL: URL,
        launchAgentsDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.appURL = appURL.standardizedFileURL
        self.launchAgentURL = launchAgentsDirectory
            .appendingPathComponent("\(Self.label).plist")
        self.fileManager = fileManager
    }

    public var state: LaunchAtLoginState {
        fileManager.fileExists(atPath: launchAgentURL.path) ? .enabled : .disabled
    }

    public func register() throws {
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let propertyList: [String: Any] = [
            "Label": Self.label,
            "LimitLoadToSessionType": "Aqua",
            "ProgramArguments": [
                "/usr/bin/open",
                "-gj",
                appURL.path
            ],
            "RunAtLoad": true
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    public func unregister() throws {
        guard fileManager.fileExists(atPath: launchAgentURL.path) else { return }
        try fileManager.removeItem(at: launchAgentURL)
    }

    public func openSystemSettings() {}
}
