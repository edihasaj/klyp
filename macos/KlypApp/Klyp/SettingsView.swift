import SwiftUI

struct SettingsView: View {
    @Environment(ClipboardStore.self) private var store
    @AppStorage("klyp.maxItems") private var maxItems: Int = 10
    @AppStorage("klyp.launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            shortcuts
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            about
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 320)
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
