import AppKit
import Foundation

enum TerminalApps {
    /// Bundle identifiers of apps where flattened paste is almost always what
    /// the user wants. Mirrors Trimmy's terminal list.
    static let bundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "org.alacritty",
        "io.alacritty",
    ]

    static func isTerminal(bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return bundleIDs.contains(id)
    }

    /// Bundle ID of the app currently in front. Looked up right before paste
    /// so we know whether to apply terminal or general aggressiveness.
    @MainActor
    static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
