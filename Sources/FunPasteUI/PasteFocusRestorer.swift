import Foundation

@MainActor
public enum PasteFocusRestorer {
    public static func restore(
        deactivateApplication: () -> Void,
        enterBackgroundMode: () -> Void,
        scheduleTargetActivation: (@escaping @MainActor () -> Void) -> Void,
        activateTarget: @escaping @MainActor () -> Void
    ) {
        deactivateApplication()
        enterBackgroundMode()
        scheduleTargetActivation(activateTarget)
    }
}
