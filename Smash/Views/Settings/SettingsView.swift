import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SmashStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.system.rawValue

    // Player profile
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @AppStorage(PlayerProfile.skillKey) private var playerSkillRaw = ""
    @AppStorage(PlayerGoal.kindKey) private var goalKindRaw = GoalKind.none.rawValue
    @AppStorage(PlayerGoal.targetKey) private var goalTarget = 3

    // Export
    @State private var encryptExport = false
    @State private var exportPassword = ""
    @State private var exportPasswordVerify = ""
    @State private var shareFile: ShareableFile?

    // Import
    @State private var showImporter = false
    @State private var pendingEncrypted: Data?
    @State private var importPassword = ""

    // Storage migration
    @State private var pendingStorageMode: SyncMode?
    @State private var migratingStorage = false

    // Alerts
    @State private var importResult: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                playerSection
                appearanceSection
                storageSection
                dataSection
                supportSection
                aboutSection
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
            .sheet(item: $shareFile) { file in
                ActivityShareSheet(items: [file.url])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImportResult(result)
            }
            .alert(
                "Encrypted backup",
                isPresented: Binding(
                    get: { pendingEncrypted != nil },
                    set: { if !$0 { pendingEncrypted = nil } }
                )
            ) {
                SecureField("Password", text: $importPassword)
                Button("Import") { importEncrypted() }
                Button("Cancel", role: .cancel) { pendingEncrypted = nil }
            } message: {
                Text("Enter the password this backup was encrypted with.")
            }
            .alert(
                "Import complete",
                isPresented: Binding(
                    get: { importResult != nil },
                    set: { if !$0 { importResult = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importResult ?? "")
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                pendingStorageMode == .iCloud ? "Move data to iCloud?" : "Move data to this iPhone?",
                isPresented: Binding(
                    get: { pendingStorageMode != nil },
                    set: { if !$0 { pendingStorageMode = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Move data") { performMigration() }
                Button("Cancel", role: .cancel) { pendingStorageMode = nil }
            } message: {
                Text("Your current play, training, matches and tournaments will be copied to \(pendingStorageMode?.label ?? "the other storage"). The two stores stay separate after this.")
            }
            .overlay {
                if migratingStorage {
                    ProgressView("Moving your data…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Sections

    private var playerSection: some View {
        Section {
            TextField("Your name", text: $playerName)
                .textInputAutocapitalization(.words)
            Picker("Skill level", selection: $playerSkillRaw) {
                Text("Not set").tag("")
                ForEach(SkillLevel.allCases) { level in
                    Text(level.label).tag(level.rawValue)
                }
            }
            Picker("Activity goal", selection: $goalKindRaw) {
                ForEach(GoalKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            if let kind = GoalKind(rawValue: goalKindRaw), kind != .none {
                Stepper(value: $goalTarget, in: kind.targetRange) {
                    Text("\(goalTarget) sessions a \(kind.unit)")
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Player profile")
        } footer: {
            Text("You. The same levels (Beginner → Professional) can be set for each opponent on a match. The goal counts play and training sessions — the Dashboard tracks your progress.")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: Binding(
                get: { AppearancePreference(rawValue: appearanceRaw) ?? .system },
                set: { appearanceRaw = $0.rawValue }
            )) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            Text("Appearance")
        } footer: {
            Text("Automatic follows your iPhone's system setting. There's also a quick switch on the Dashboard.")
        }
    }

    @ViewBuilder private var storageSection: some View {
        Section {
            Picker("Storage", selection: Binding(
                get: { store.syncMode },
                set: { newMode in
                    if newMode != store.syncMode { pendingStorageMode = newMode }
                }
            )) {
                ForEach(SyncMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .disabled(migratingStorage)

            Text(store.syncMode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Storage")
        } footer: {
            Text("Switching copies your current data to the selected storage so you can move between this device and iCloud without losing anything.")
        }

        if store.iCloudUnavailable {
            Section {
                Label(
                    "iCloud isn't available for Smash right now. Check that you're signed in to iCloud; if you built the app yourself, make sure the iCloud capability is enabled with your team.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
    }

    private func performMigration() {
        guard let mode = pendingStorageMode else { return }
        pendingStorageMode = nil
        migratingStorage = true
        Task { @MainActor in
            defer { migratingStorage = false }
            do {
                if let summary = try store.migrate(to: mode, from: context) {
                    importResult = "Moved to \(mode.label). \(summary.description)"
                } else if store.iCloudUnavailable {
                    errorMessage = "iCloud isn't available for Smash right now. Your data stayed on \(store.syncMode.label)."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var dataSection: some View {
        Section {
            Toggle("Encrypt with password", isOn: $encryptExport)
            if encryptExport {
                SecureField("Password", text: $exportPassword)
                SecureField("Verify password", text: $exportPasswordVerify)
                if passwordMismatch {
                    Label("Passwords don't match", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Button {
                exportData()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            .disabled(passwordInvalid)
            Button {
                showImporter = true
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            Text(encryptExport
                 ? "Exports a password-encrypted file (AES-256). Without the password, the data can't be recovered — keep it safe."
                 : "Exports a readable JSON file you can share or archive. Import adds records from a file; existing records are never replaced.")
        }
    }

    private var supportSection: some View {
        Section("Support") {
            Link(destination: AppLinks.buyMeACoffee) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
            }
            Link(destination: AppLinks.feedback) {
                Label("Send feedback", systemImage: "envelope")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            Link(destination: AppLinks.sourceCode) {
                Label("Source on GitHub", systemImage: "link")
            }
            LabeledContent("License", value: "GPL-3.0")
        }
    }

    // MARK: - Export

    private var passwordMismatch: Bool {
        encryptExport && !exportPassword.isEmpty && exportPassword != exportPasswordVerify
    }

    private var passwordInvalid: Bool {
        encryptExport && (exportPassword.isEmpty || exportPassword != exportPasswordVerify)
    }

    private func exportData() {
        do {
            var data = try Backup.exportData(context: context)
            if encryptExport {
                data = try BackupCrypto.encrypt(data, password: exportPassword)
            }
            let stamp = DateFormatter.backupStamp.string(from: .now)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Smash-Backup-\(stamp).json")
            try data.write(to: url, options: .atomic)
            shareFile = ShareableFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Import

    private func handleImportResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            importFrom(url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func importFrom(_ url: URL) {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            if BackupCrypto.isEncrypted(data) {
                importPassword = ""
                pendingEncrypted = data
            } else {
                importResult = try Backup.importData(data, into: context).description
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importEncrypted() {
        guard let data = pendingEncrypted else { return }
        pendingEncrypted = nil
        do {
            let plain = try BackupCrypto.decrypt(data, password: importPassword)
            importResult = try Backup.importData(plain, into: context).description
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

// MARK: - Share plumbing

private struct ShareableFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The system share sheet, so exports can go to Files, AirDrop, Mail…
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension DateFormatter {
    /// File-name-safe timestamp: "2026-11-17-1430".
    static let backupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
