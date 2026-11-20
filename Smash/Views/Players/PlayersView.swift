import SwiftUI
import SwiftData

/// Saved opponents and partners. Pick one here when logging a match and the
/// name and level carry over, so regulars don't need typing twice.
struct PlayersView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Player.name) private var players: [Player]
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    @State private var searchText = ""
    @State private var showAdd = false
    @State private var editing: Player?
    @State private var detailFor: Player?

    /// Empty-state glyph follows Dynamic Type instead of staying 32pt.
    @ScaledMetric(relativeTo: .body) private var emptyGlyphSize: CGFloat = 32

    private var filtered: [Player] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return players }
        return players.filter { player in
            player.name.localizedCaseInsensitiveContains(query)
                || player.notes?.localizedCaseInsensitiveContains(query) == true
                || player.level?.label.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        // Group once per render instead of scanning every match for each card.
        let records = recordsByName
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: players.isEmpty ? "person.2" : "magnifyingglass")
                                .font(.system(size: emptyGlyphSize))
                                .foregroundStyle(.secondary)
                            Text(players.isEmpty ? "No players yet" : "No players found")
                                .font(.headline)
                            Text(players.isEmpty
                                 ? "Add the people you play with, then pick them when you log a session."
                                 : "Try a different name or note.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filtered) { player in
                            PlayerCard(
                                player: player,
                                record: record(for: player, from: records),
                                onDetail: { detailFor = player }
                            )
                            .swipeActions(edge: .leading) {
                                Button { editing = player } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(player) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Players")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name, level, note…")
            .overlay(alignment: .bottomTrailing) {
                Button { showAdd = true } label: {
                    AddButtonLabel()
                        .accessibilityLabel("Add player")
                }
                .buttonStyle(PressableStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showAdd) {
                PlayerFormView()
            }
            .sheet(item: $editing) { player in
                PlayerFormView(player: player)
            }
            .navigationDestination(item: $detailFor) { player in
                PlayerSessionsView(player: player)
            }
        }
    }

    /// A single pass builds every player's record. A match counts once per
    /// distinct name, whether that name is the opponent or the partner.
    private var recordsByName: [String: Record] {
        var grouped: [String: [Match]] = [:]
        for match in matches {
            for name in Set([match.opponent, match.partner].filter { !$0.isEmpty }) {
                grouped[name, default: []].append(match)
            }
        }
        var result: [String: Record] = [:]
        for (name, related) in grouped {
            result[name] = Record(
                label: name,
                wins: related.filter { MatchLogic.outcome($0) == .win }.count,
                losses: related.filter { MatchLogic.outcome($0) == .loss }.count,
                draws: related.filter { MatchLogic.outcome($0) == .draw }.count
            )
        }
        return result
    }

    private func record(for player: Player, from records: [String: Record]) -> Record {
        records[player.name] ?? Record(label: player.name, wins: 0, losses: 0, draws: 0)
    }

    private func delete(_ player: Player) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            context.delete(player)
        }
    }
}

// MARK: - Player card

private struct PlayerCard: View {
    let player: Player
    let record: Record
    let onDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onDetail) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let level = player.level {
                            Text(level.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Games")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline) {
                    stat(value: "\(record.total)", label: "Completed games")
                    Spacer()
                    stat(value: record.winRate.formatted(.percent.precision(.fractionLength(0))), label: "Win rate")
                    Spacer()
                    stat(value: "\(record.wins)-\(record.losses)", label: "W-L")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onDetail)
        }
        .cardStyle()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sessions for one player

struct PlayerSessionsView: View {
    let player: Player
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]
    @Query(sort: \PlaySession.date, order: .reverse) private var playSessions: [PlaySession]

    /// Empty-state glyph follows Dynamic Type instead of staying 32pt.
    @ScaledMetric(relativeTo: .body) private var emptyGlyphSize: CGFloat = 32

    private var playerMatches: [Match] {
        matches.filter { $0.opponent == player.name || $0.partner == player.name }
    }

    private var playerPlay: [PlaySession] {
        playSessions.filter { $0.opponents.contains(player.name) }
    }

    var body: some View {
        List {
            if playerMatches.isEmpty && playerPlay.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.play")
                        .font(.system(size: emptyGlyphSize))
                        .foregroundStyle(.secondary)
                    Text("No sessions yet")
                        .font(.headline)
                    Text("Sessions with \(player.name) show up here once you log them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                if !playerMatches.isEmpty {
                    Section("Matches") {
                        ForEach(playerMatches) { match in
                            NavigationLink(value: match) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(match.discipline.label) · Me vs \(match.opponent)")
                                            .font(.subheadline.weight(.medium))
                                        Text(AppFormat.dateTime(match.date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    OutcomeBadge(outcome: MatchLogic.outcome(match))
                                }
                            }
                        }
                    }
                }
                if !playerPlay.isEmpty {
                    Section("Play sessions") {
                        ForEach(playerPlay) { session in
                            HStack {
                                Label(AppFormat.duration(minutes: session.durationMinutes), systemImage: "clock")
                                    .font(.subheadline)
                                Spacer()
                                Text(AppFormat.dateTime(session.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
    }
}

// MARK: - Add or edit

struct PlayerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var players: [Player]

    let player: Player?

    @State private var name = ""
    @State private var level: SkillLevel?
    @State private var notes = ""
    @State private var nameError: String?
    @State private var isSaving = false
    @State private var didPopulate = false

    init(player: Player? = nil) {
        self.player = player
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Player name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Skill level", selection: $level) {
                        Text("Not set").tag(SkillLevel?.none)
                        ForEach(SkillLevel.allCases) { item in
                            Text(item.label).tag(SkillLevel?.some(item))
                        }
                    }
                } header: {
                    Text("Player details")
                }

                if let nameError {
                    Section {
                        Text(nameError)
                            .font(.caption)
                            .foregroundStyle(SmashColor.lossText)
                    }
                }

                Section("Notes") {
                    TextField("Anything useful to remember", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(player == nil ? "Add player" : "Edit player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty || isSaving)
                }
            }
            .onChange(of: name) { _, _ in nameError = nil }
            .onAppear {
                // onAppear can fire again when a sheet is covered and revealed;
                // never discard edits the user has already typed.
                guard !didPopulate, let player else { return }
                didPopulate = true
                name = player.name
                level = player.level
                notes = player.notes ?? ""
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        let cleanName = trimmedName
        guard !cleanName.isEmpty else { return }

        // Pickers elsewhere tag by name, so a case-only variant would create
        // two ambiguous tags and merge two different players' records.
        let duplicate = players.contains { existing in
            if let current = player, existing.id == current.id { return false }
            return existing.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(cleanName) == .orderedSame
        }
        guard !duplicate else {
            nameError = "A player named \"\(cleanName)\" already exists. Use a different name."
            return
        }

        isSaving = true
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let player {
            player.name = cleanName
            player.level = level
            player.notes = cleanNotes.isEmpty ? nil : cleanNotes
        } else {
            context.insert(Player(name: cleanName, level: level, notes: cleanNotes.isEmpty ? nil : cleanNotes))
        }
        dismiss()
    }
}

#Preview {
    PlayersView()
        .modelContainer(PreviewContainer.container)
}
