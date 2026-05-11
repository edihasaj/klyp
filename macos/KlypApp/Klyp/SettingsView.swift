import SwiftUI

struct SettingsView: View {
    @Environment(ClipboardStore.self) private var store
    @AppStorage("klyp.maxItems") private var maxItems: Int = 10
    @AppStorage("klyp.launchAtLogin") private var launchAtLogin: Bool = false

    @AppStorage(TrimSettings.Keys.enabled) private var trimEnabled: Bool = true
    @AppStorage(TrimSettings.Keys.terminalLevel) private var terminalLevelRaw: String = Aggressiveness.normal.rawValue
    @AppStorage(TrimSettings.Keys.generalLevel) private var generalLevelRaw: String = Aggressiveness.off.rawValue
    @AppStorage(TrimSettings.Keys.preserveBlankLines) private var preserveBlankLines: Bool = true
    @AppStorage(TrimSettings.Keys.removeBoxDrawing) private var removeBoxDrawing: Bool = true

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            trimming
                .tabItem { Label("Trimming", systemImage: "scissors") }
            shortcuts
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            about
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 380)
    }

    private var general: some View {
        Form {
            Section {
                Stepper(value: Binding(
                    get: { maxItems },
                    set: { newValue in
                        maxItems = newValue
                        store.setMaxItems(newValue)
                    }
                ), in: 5...200, step: 5) {
                    HStack {
                        Text("History size")
                        Spacer()
                        Text("\(maxItems) items")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        LoginItem.set(enabled: on)
                    }
            }
            Section {
                Button("Clear unpinned history") {
                    store.clearAll()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var trimming: some View {
        Form {
            Section {
                Toggle("Smart-trim on paste", isOn: $trimEnabled)
            } footer: {
                Text("Flattens multi-line shell snippets (continuation backslashes, prompt gutters, box-drawing) so they paste and run cleanly. Other text is left alone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Aggressiveness") {
                Picker("In terminals", selection: $terminalLevelRaw) {
                    ForEach(Aggressiveness.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .help(currentTerminalBlurb)
                .disabled(!trimEnabled)

                Picker("In other apps", selection: $generalLevelRaw) {
                    ForEach(Aggressiveness.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .help(currentGeneralBlurb)
                .disabled(!trimEnabled)
            }

            Section("Formatting") {
                Toggle("Preserve intentional blank lines", isOn: $preserveBlankLines)
                    .disabled(!trimEnabled)
                Toggle("Strip box-drawing characters (│ ┃)", isOn: $removeBoxDrawing)
                    .disabled(!trimEnabled)
            }

            Section {
                Text("Tip: hold ⌥ while pasting to skip the trim and send the original text.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var currentTerminalBlurb: String {
        Aggressiveness(rawValue: terminalLevelRaw)?.blurb ?? ""
    }

    private var currentGeneralBlurb: String {
        Aggressiveness(rawValue: generalLevelRaw)?.blurb ?? ""
    }

    private var shortcuts: some View {
        Form {
            Section("Global") {
                LabeledContent("Toggle Klyp", value: "⌃Space")
            }
            Section("In popover") {
                LabeledContent("Paste selected", value: "↵")
                LabeledContent("Quick paste 1–9", value: "⌘1 … ⌘9")
                LabeledContent("Pin/unpin selected", value: "⌘P")
                LabeledContent("Delete selected", value: "⌫")
                LabeledContent("Close", value: "⎋")
            }
            Section {
                Text("The global hotkey will be customizable in a future release.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        AboutView()
    }
}

struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "v\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Klyp")
                .font(.system(size: 22, weight: .semibold))
            Text(version)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("A modern, lightweight clipboard manager for macOS.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Link("github.com/edihasaj/klyp", destination: URL(string: "https://github.com/edihasaj/klyp")!)
                .font(.system(size: 12))
            Spacer()
            HStack(spacing: 4) {
                Text("©")
                Link("Edi Hasaj", destination: URL(string: "https://edihasaj.com")!)
                Text("· MIT")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
