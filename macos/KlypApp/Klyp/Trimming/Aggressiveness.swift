import Foundation

/// How eagerly the trimmer flattens multi-line text. Mirrors Trimmy's model
/// (Low/Normal/High) plus an `off` case so a single picker can disable it.
enum Aggressiveness: String, CaseIterable, Codable, Sendable, Identifiable {
    case off, low, normal, high

    var id: String { rawValue }

    /// Minimum signal score required to flatten. Lower = more eager.
    /// `off` returns a sentinel that no realistic score can reach.
    var scoreThreshold: Int {
        switch self {
        case .off: .max
        case .low: 3
        case .normal: 2
        case .high: 1
        }
    }

    /// Upper bound on lines considered "command-shaped". Anything larger is
    /// almost certainly a script/code block — leave it alone.
    var maxLines: Int {
        switch self {
        case .high: 12
        default: 10
        }
    }

    var title: String {
        switch self {
        case .off: "Off"
        case .low: "Low (safer)"
        case .normal: "Normal"
        case .high: "High (eager)"
        }
    }

    var blurb: String {
        switch self {
        case .off:
            "Never auto-trim — paste exactly what was copied."
        case .low:
            "Only flatten when strong cues are present (pipes, backslash continuations, prompt markers)."
        case .normal:
            "Good default: flattens typical blog/README commands with flags, pipes, or continuations."
        case .high:
            "Most eager: flattens almost any short multi-line text that looks command-shaped."
        }
    }
}
