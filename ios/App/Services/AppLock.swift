import Foundation
import LocalAuthentication

/// Optional Face ID (or passcode) lock. The diary is hidden whenever the app
/// goes to the background and stays hidden until the owner unlocks it.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published var errorMessage: String?
    private var isAuthenticating = false

    init(defaults: UserDefaults = .standard) {
        isLocked = defaults.bool(forKey: SettingsKeys.lockEnabled)
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.lockEnabled)
    }

    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let success = await Self.authenticate(reason: "Unlock your noise diary.")
        if success {
            isLocked = false
            errorMessage = nil
        } else {
            errorMessage = "Not unlocked. Try again."
        }
    }

    /// Turns the lock on or off. Turning it on asks for Face ID first so the
    /// owner knows it works before they rely on it.
    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            guard Self.isAvailable else { return false }
            let success = await Self.authenticate(reason: "Turn on the lock for your noise diary.")
            guard success else { return false }
        }
        UserDefaults.standard.set(enabled, forKey: SettingsKeys.lockEnabled)
        return true
    }

    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// "Face ID", "Touch ID" or "Passcode", for labels.
    static var methodName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Passcode"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Passcode"
        }
    }

    private static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
