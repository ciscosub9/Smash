import SwiftUI

/// Browse the full badminton drill library and pick one for the session.
/// Selecting a drill returns to the form with the name filled in.
struct DrillLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    @State private var search = ""
    @State private var category = "All"

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [BadmintonDrill] {
        BadmintonDrillLibrary.drills.filter { drill in
            (category == "All" || drill.category == category)
                && (query.isEmpty
                    || drill.name.localizedCaseInsensitiveContains(query)
                    || drill.detail.localizedCaseInsensitiveContains(query)
                    || drill.category.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        // Group the filtered drills once rather than re-filtering the whole
        // library for every section header.
        let grouped = Dictionary(grouping: filtered, by: \.category)
        NavigationStack {
            List {
                Section {
                    Picker("Category", selection: $category) {
                        Text("All").tag("All")
                        ForEach(BadmintonDrillLibrary.categories, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("\(BadmintonDrillLibrary.drills.count) drills across footwork, strokes, defense, doubles, and match play.")
                }

                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(BadmintonDrillLibrary.categories, id: \.self) { name in
                        let drills = grouped[name] ?? []
                        if !drills.isEmpty {
                            Section(name) {
                                ForEach(drills) { drill in
                                    Button {
                                        selection = drill.name
                                        dismiss()
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(drill.name)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(drill.detail)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if selection == drill.name {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name, detail, category…")
            .navigationTitle("Drill library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DrillLibraryView(selection: .constant("Shadow footwork"))
}
