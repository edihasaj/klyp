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
    var extractMarkdown: Bool

    static let `default` = TrimSettings(
        enabled: true,
        terminalLevel: .normal,
        generalLevel: .off,
        preserveBlankLines: true,
        removeBoxDrawing: true,
        extractMarkdown: true
    )

    enum Keys {
        static let enabled = "klyp.trim.enabled"
        static let terminalLevel = "klyp.trim.terminalLevel"
        static let generalLevel = "klyp.trim.generalLevel"
        static let preserveBlankLines = "klyp.trim.preserveBlankLines"
        static let removeBoxDrawing = "klyp.trim.removeBoxDrawing"
        static let extractMarkdown = "klyp.trim.extractMarkdown"
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
        let md = defaults.object(forKey: Keys.extractMarkdown) as? Bool
            ?? `default`.extractMarkdown
        return TrimSettings(
            enabled: enabled,
            terminalLevel: term,
            generalLevel: gen,
            preserveBlankLines: preserve,
            removeBoxDrawing: stripBox,
            extractMarkdown: md
        )
    }

    /// Effective aggressiveness for the current target app.
    func aggressiveness(forTerminal isTerminal: Bool) -> Aggressiveness {
        guard enabled else { return .off }
        return isTerminal ? terminalLevel : generalLevel
    }
}
