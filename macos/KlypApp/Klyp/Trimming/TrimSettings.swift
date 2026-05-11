import Foundation

/// Snapshot of the user's trim preferences. Read from `UserDefaults` at the
/// moment of paste — paste is rare, the lookup is cheap, and this avoids
/// threading `@AppStorage` through the coordinator.
struct TrimSettings: Sendable {
    var enabled: Bool
    var terminalLevel: Aggressiveness
    var generalLevel: Aggressiveness
    var preserveBlankLines: Bool
    var removeBoxDrawing: Bool

    static let `default` = TrimSettings(
        enabled: true,
        terminalLevel: .normal,
        generalLevel: .off,
        preserveBlankLines: true,
        removeBoxDrawing: true
    )

    enum Keys {
        static let enabled = "klyp.trim.enabled"
        static let terminalLevel = "klyp.trim.terminalLevel"
        static let generalLevel = "klyp.trim.generalLevel"
        static let preserveBlankLines = "klyp.trim.preserveBlankLines"
        static let removeBoxDrawing = "klyp.trim.removeBoxDrawing"
    }

    static func load(from defaults: UserDefaults = .standard) -> TrimSettings {
        let enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? `default`.enabled
        let term = (defaults.string(forKey: Keys.terminalLevel)
            .flatMap(Aggressiveness.init(rawValue:))) ?? `default`.terminalLevel
        let gen = (defaults.string(forKey: Keys.generalLevel)
            .flatMap(Aggressiveness.init(rawValue:))) ?? `default`.generalLevel
        let preserve = defaults.object(forKey: Keys.preserveBlankLines) as? Bool
            ?? `default`.preserveBlankLines
        let stripBox = defaults.object(forKey: Keys.removeBoxDrawing) as? Bool
            ?? `default`.removeBoxDrawing
        return TrimSettings(
            enabled: enabled,
            terminalLevel: term,
            generalLevel: gen,
            preserveBlankLines: preserve,
            removeBoxDrawing: stripBox
        )
    }

    /// Effective aggressiveness for the current target app.
    func aggressiveness(forTerminal isTerminal: Bool) -> Aggressiveness {
        guard enabled else { return .off }
        return isTerminal ? terminalLevel : generalLevel
    }
}
