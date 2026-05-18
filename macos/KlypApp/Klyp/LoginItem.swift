import Foundation
import ServiceManagement

enum LoginItem {
    private static let seedKey = "klyp.didSeedLoginItem"
    private static let prefKey = "klyp.launchAtLogin"

    static func set(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("[Klyp] LoginItem toggle failed: \(error)")
        }
    }

    /// Klyp is a menu-bar utility — useless if it doesn't survive a reboot.
    /// On first launch, opt the user into Launch at Login. A one-shot flag
    /// (`klyp.didSeedLoginItem`) makes this idempotent so anyone who later
    /// turns it off in Settings stays off across updates.
    static func seedFirstRunIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seedKey) else { return }
        defaults.set(true, forKey: seedKey)
        defaults.set(true, forKey: prefKey)
        set(enabled: true)
    }
}
