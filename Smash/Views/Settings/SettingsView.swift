import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    /// When pushed from Profile, the surrounding NavigationStack is supplied
    /// by ProfileView, so this view doesn't wrap itself in another one.
    var embedded = false

    @Environment(SmashStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.dark.rawValue
    @AppStorage(TimePreference.storageKey) private var timeFormatRaw = TimePreference.Format.twelveHour.rawValue

    // App tour
    @State private var showTour = false

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

    // Backup work (PBKDF2, JSON, file I/O) runs off the main actor.
    @State private var processingBackup = false

    // Alerts
    @State private var importResult: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if embedded {
                settingsContent
            } else {
                NavigationStack {
                    settingsContent
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            }
        }
    }

    private var settingsContent: some View {
        Form {
            personalizationSection
            storageSection
            dataSection
            moreSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareFile) { file in
            ActivityShareSheet(items: [file.url])
        }
        .onChange(of: shareFile) { oldFile, _ in
            // The share sheet sets shareFile to nil when it dismisses: delete
            // the previous temp export as soon as we're done with it.
            if let oldFile { Self.removeBackup(at: oldFile.url) }
        }
        .sheet(isPresented: $showTour) {
            AppTourView()
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
            Text("\(importResult ?? "")\n\nYour name, skill, avatar, colour and goal were restored from the backup.")
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
            Text("Your play, training, matches and tournaments will be copied to \(pendingStorageMode?.label ?? "the other storage"). The two stores stay separate after this.")
        }
        .overlay {
            if migratingStorage || processingBackup {
                ProgressView(migratingStorage ? "Moving your data…" : "Working with your backup…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Sections

    private var personalizationSection: some View {
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

            Picker("Time format", selection: Binding(
                get: { TimePreference.Format(rawValue: timeFormatRaw) ?? .twelveHour },
                set: { timeFormatRaw = $0.rawValue }
            )) {
                ForEach(TimePreference.Format.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button {
                showTour = true
            } label: {
                Label("Replay app tour", systemImage: "hand.point.up.left")
            }
        } header: {
            Text("Personalization")
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
                .foregroundStyle(SmashColor.warningText)
            }
        }

        if let storeError = store.storeError {
            Section {
                Label(storeError, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(SmashColor.warningText)
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
                if let summary = try await store.migrate(to: mode, from: context) {
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
                        .foregroundStyle(SmashColor.warningText)
                }
            }
            Button {
                exportData()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            .disabled(passwordInvalid || processingBackup || migratingStorage)
            Button {
                showImporter = true
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
            .disabled(processingBackup || migratingStorage)
        } header: {
            Text("Data")
        } footer: {
            Text(encryptExport
                 ? "Exports a password-encrypted file (AES-256). Without the password, the data can't be recovered — keep it safe. Import adds records without replacing any, then restores your profile settings from the backup."
                 : "Exports a readable JSON file you can share or archive. Import adds records without replacing any, then restores your name, skill, avatar, colour and goal from the backup.")
        }
    }

    private var moreSection: some View {
        Section {
            Link(destination: AppLinks.feedback) {
                Label("Send feedback", systemImage: "envelope")
            }
            Link(destination: AppLinks.sourceCode) {
                Label("Source on GitHub", systemImage: "link")
            }
        } header: {
            Text("More")
        } footer: {
            Text("Smash is free, open-source badminton tracking. Your data belongs to you.")
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
        // Reading the store belongs on the main actor; encoding, encryption
        // and file I/O are pushed to a detached task below.
        let bundle: BackupBundle
        do {
            bundle = try Backup.makeBundle(context: context)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let password = exportPassword
        let encrypted = encryptExport
        processingBackup = true
        Task { @MainActor in
            defer { processingBackup = false }
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    var bytes = try Backup.encode(bundle)
                    if encrypted { bytes = try BackupCrypto.encrypt(bytes, password: password) }
                    return try Self.writeBackup(bytes)
                }.value
                shareFile = ShareableFile(url: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private nonisolated static func writeBackup(_ data: Data) throws -> URL {
        // Keep the .json extension so the file importer still accepts encrypted
        // backups (they are JSON too). UUID avoids collisions; complete file
        // protection keeps the records at rest until the device is unlocked.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Smash-Backup-\(UUID().uuidString).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private nonisolated static func removeBackup(at url: URL) {
        guard url.path.hasPrefix(FileManager.default.temporaryDirectory.path) else { return }
        try? FileManager.default.removeItem(at: url)
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

    private enum LoadedBackup: Sendable {
        case plaintext(ValidatedBackup)
        case encrypted(Data)
    }

    /// File access, size limit, decryption detection and JSON validation all
    /// happen in a detached task. The security scope is taken there too so it
    /// stays active for the whole read.
    private nonisolated static func loadBackup(from url: URL) throws -> LoadedBackup {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values.fileSize, size > BackupFormat.maxBackupBytes {
            throw Backup.Failure(message: "That file is over 50 MB — too large to import.")
        }
        let data = try Data(contentsOf: url)
        if BackupCrypto.isEncrypted(data) {
            return .encrypted(data)
        }
        return .plaintext(try Backup.prepare(data))
    }

    private func importFrom(_ url: URL) {
        processingBackup = true
        Task { @MainActor in
            defer { processingBackup = false }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try Self.loadBackup(from: url)
                }.value
                switch loaded {
                case .encrypted(let data):
                    importPassword = ""
                    pendingEncrypted = data
                case .plaintext(let validated):
                    try applyBackup(validated)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importEncrypted() {
        guard let data = pendingEncrypted else { return }
        pendingEncrypted = nil
        let password = importPassword
        processingBackup = true
        Task { @MainActor in
            defer { processingBackup = false }
            do {
                let validated = try await Task.detached(priority: .userInitiated) {
                    try Backup.prepare(BackupCrypto.decrypt(data, password: password))
                }.value
                try applyBackup(validated)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// The only step that touches SwiftData and UserDefaults, after every
    /// byte has been decoded, bounded and validated.
    @MainActor private func applyBackup(_ validated: ValidatedBackup) throws {
        importResult = try Backup.apply(validated, into: context).description
    }

}

// MARK: - Share plumbing

private struct ShareableFile: Identifiable, Equatable {
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
