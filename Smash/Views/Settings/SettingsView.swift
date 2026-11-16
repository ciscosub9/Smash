import SwiftUI

struct SettingsView: View {
    @Environment(SmashStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Storage", selection: Binding(
                        get: { store.syncMode },
                        set: { store.switchMode($0) }
                    )) {
                        ForEach(SyncMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(store.syncMode.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Records stay in the storage they were created in — switching doesn't move existing data between this iPhone and iCloud.")
                }

                if store.syncMode == .iCloud && store.iCloudUnavailable {
                    Section {
                        Label(
                            "iCloud isn't available for Smash right now. Check that you're signed in to iCloud; if you built the app yourself, make sure the iCloud capability is enabled with your team.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://github.com/ciscosub9/Smash")!) {
                        Label("Source on GitHub", systemImage: "link")
                    }
                    LabeledContent("License", value: "MIT")
                }

                Section {
                    Text("Smash is free, open-source badminton tracking. Your data belongs to you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
