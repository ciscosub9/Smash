import SwiftUI
import SwiftData

/// One tab for everything you log. The card at the top picks what to add;
/// the list below mixes play sessions, scored matches and training, newest first.
struct SessionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \PlaySession.date, order: .reverse) private var playSessions: [PlaySession]
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]

    @State private var searchText = ""
    @State private var showLog = false
    @State private var editingPlay: PlaySession?
    @State private var editingTraining: TrainingSession?

    /// Empty-state glyph follows Dynamic Type instead of staying 32pt.
    @ScaledMetric(relativeTo: .body) private var emptyGlyphSize: CGFloat = 32

    /// One saved action is one card. A scored play session stores a
    /// `PlaySession` and a linked `Match`; both appear together on one card.
    private enum SessionItem: Identifiable {
        case play(PlaySession, Match?)
        case match(Match)
        case training(TrainingSession)

        var id: String {
            switch self {
            case .play(let session, _): "play-\(session.id)"
            case .match(let match): "match-\(match.id)"
            case .training(let session): "training-\(session.id)"
            }
        }

        var date: Date {
            switch self {
            case .play(let session, _): session.date
            case .match(let match): match.date
            case .training(let session): session.date
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    emptyList
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(items) { item in
                                card(for: item)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Sessions")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Opponent, drill, notes…")
            .overlay(alignment: .bottomTrailing) {
                Button { showLog = true } label: {
                    AddButtonLabel()
                        .accessibilityLabel("Log a session")
                }
                .buttonStyle(PressableStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
            .fullScreenCover(isPresented: $showLog) {
                SessionLogView()
            }
            .sheet(item: $editingPlay) { PlayFormView(session: $0) }
            .sheet(item: $editingTraining) { TrainingFormView(session: $0) }
        }
    }

    // MARK: - Empty

    private var emptyList: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.play")
                .font(.system(size: emptyGlyphSize))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.headline)
            Text("Tap the plus button to log your first session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func card(for item: SessionItem) -> some View {
        Group {
            switch item {
            case .play(let session, let match):
                Button { editingPlay = session } label: {
                    PlaySessionRow(session: session, linkedMatch: match)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            case .match(let match):
                NavigationLink(value: match) {
                    MatchRow(match: match)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            case .training(let session):
                Button { editingTraining = session } label: {
                    TrainingSessionRow(session: session)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) { delete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(_ item: SessionItem) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            switch item {
            case .play(let session, let match):
                if let match { context.delete(match) }
                context.delete(session)
            case .match(let match): context.delete(match)
            case .training(let session): context.delete(session)
            }
        }
    }

    // MARK: - Data

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A `Match` saved together with a `PlaySession` shares the same day and
    /// opponent set. That pair is the key used to fold both into one card.
    private struct MatchLinkKey: Hashable {
        let day: Date
        let names: [String]
    }

    private func linkKey(day: Date, names: [String]) -> MatchLinkKey? {
        let cleaned = Set(names.filter { !$0.isEmpty })
        guard !cleaned.isEmpty else { return nil }
        return MatchLinkKey(day: Calendar.current.startOfDay(for: day), names: cleaned.sorted())
    }

    /// One pass over all matches builds this lookup. Previously the list
    /// scanned every match to collect linked IDs, then scanned all matches
    /// again for each play session — O(sessions × matches).
    private var matchLookup: [MatchLinkKey: [Match]] {
        var result: [MatchLinkKey: [Match]] = [:]
        for match in matches where match.tournament == nil {
            let names = match.opponent
                .components(separatedBy: " & ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let key = linkKey(day: match.date, names: names) else { continue }
            result[key, default: []].append(match)
        }
        return result
    }

    private var allItems: [SessionItem] {
        let lookup = matchLookup
        var linkedMatchIDs = Set<PersistentIdentifier>()
        let paired = playSessions.map { session -> (PlaySession, Match?) in
            guard let key = linkKey(day: session.date, names: session.opponents),
                  let match = lookup[key]?.first(where: { !linkedMatchIDs.contains($0.id) })
            else { return (session, nil) }
            linkedMatchIDs.insert(match.id)
            return (session, match)
        }

        var result: [SessionItem] = paired.map { SessionItem.play($0.0, $0.1) }
        result += matches.filter { !linkedMatchIDs.contains($0.id) }.map { .match($0) }
        result += trainingSessions.map { .training($0) }
        return result.sorted { $0.date > $1.date }
    }

    private var items: [SessionItem] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { item in
            switch item {
            case .play(let session, let match):
                matchesPlay(session) || (match.map { matchesMatch($0) } ?? false)
            case .match(let match): matchesMatch(match)
            case .training(let session): matchesTraining(session)
            }
        }
    }

    private func matchesPlay(_ session: PlaySession) -> Bool {
        guard !query.isEmpty else { return true }
        return session.opponents.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || session.location?.localizedCaseInsensitiveContains(query) == true
            || session.notes?.localizedCaseInsensitiveContains(query) == true
            || session.discipline.label.localizedCaseInsensitiveContains(query)
            || session.intensity?.label.localizedCaseInsensitiveContains(query) == true
    }

    private func matchesMatch(_ match: Match) -> Bool {
        guard !query.isEmpty else { return true }
        return match.opponent.localizedCaseInsensitiveContains(query)
            || match.partner.localizedCaseInsensitiveContains(query)
            || match.notes?.localizedCaseInsensitiveContains(query) == true
            || match.tournament?.name.localizedCaseInsensitiveContains(query) == true
            || match.discipline.label.localizedCaseInsensitiveContains(query)
            || match.intensity?.label.localizedCaseInsensitiveContains(query) == true
            || match.opponentLevel?.label.localizedCaseInsensitiveContains(query) == true
    }

    private func matchesTraining(_ session: TrainingSession) -> Bool {
        guard !query.isEmpty else { return true }
        return session.focusAreas.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || session.drillsDescription.localizedCaseInsensitiveContains(query)
            || session.drillNames.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || session.notes?.localizedCaseInsensitiveContains(query) == true
            || session.intensity?.label.localizedCaseInsensitiveContains(query) == true
    }
}

// MARK: - Play row

private struct PlaySessionRow: View {
    let session: PlaySession
    var linkedMatch: Match? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(AppFormat.duration(minutes: session.durationMinutes), systemImage: "clock")
                    .font(.headline)
                Spacer()
                Text(AppFormat.dateTime(session.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Label(session.discipline.label, systemImage: session.discipline.symbol)
                if let intensity = session.intensity {
                    Text(intensity.label)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(intensityTint.opacity(0.15), in: Capsule())
                        .foregroundStyle(intensityTextTint)
                }
                Spacer()
                if !session.opponents.isEmpty {
                    Text(session.opponents.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let match = linkedMatch {
                Divider()
                scoreSummary(for: match)
            }
        }
        .padding(.vertical, 2)
    }

    private func scoreSummary(for match: Match) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Me vs \(match.opponent)")
                    .font(.subheadline.weight(.semibold))
                if match.usesPartner && !match.partner.isEmpty {
                    Text("with \(match.partner)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                OutcomeBadge(outcome: MatchLogic.outcome(match))
            }
            if !games(for: match).isEmpty {
                HStack(spacing: 8) {
                    ForEach(games(for: match), id: \.number) { game in
                        HStack(spacing: 4) {
                            Text("\(game.mine)")
                                .foregroundStyle(game.mine > game.theirs ? SmashColor.winText : Color.secondary)
                            Text("–")
                                .foregroundStyle(.secondary)
                            Text("\(game.theirs)")
                                .foregroundStyle(game.theirs > game.mine ? SmashColor.lossText : Color.secondary)
                        }
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary, in: Capsule())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Game \(game.number): you \(game.mine), opponent \(game.theirs), \(gameResult(game))")
                    }
                }
            }
        }
    }

    private func games(for match: Match) -> [GameScore] {
        zip(match.myGameScores, match.opponentGameScores).enumerated().map { index, pair in
            GameScore(number: index + 1, mine: pair.0, theirs: pair.1)
        }
    }

    private func gameResult(_ game: GameScore) -> String {
        game.mine > game.theirs ? "won" : game.mine < game.theirs ? "lost" : "drew"
    }

    private struct GameScore {
        let number: Int
        let mine: Int
        let theirs: Int
    }

    /// Bright fill for the capsule; keep fills vivid in both modes.
    private var intensityTint: Color {
        switch session.intensity {
        case .easy: .green
        case .moderate: .orange
        case .hard: .red
        case nil: .gray
        }
    }

    /// Contrast-safe foreground for the same capsule in light mode.
    private var intensityTextTint: Color {
        switch session.intensity {
        case .easy: SmashColor.winText
        case .moderate: SmashColor.warningText
        case .hard: SmashColor.lossText
        case nil: Color.secondary
        }
    }
}

// MARK: - Training row

private struct TrainingSessionRow: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(AppFormat.duration(minutes: session.durationMinutes), systemImage: "clock")
                    .font(.headline)
                Spacer()
                Text(AppFormat.dateTime(session.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !session.focusAreas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(session.focusAreas, id: \.self) { focus in
                            Text(focus)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(SmashColor.training)
                        }
                    }
                }
            }
            if !session.drillEntries.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(session.drillEntries) { drill in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(drill.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 6)
                            Text("\(drill.sets) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            if let level = drill.intensity {
                                Text(level.label)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(intensityTint(level).opacity(0.15), in: Capsule())
                                    .foregroundStyle(intensityTextTint(level))
                            }
                        }
                    }
                }
            }
            if !session.drillsDescription.isEmpty {
                Text(session.drillsDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    /// Bright fill, with a contrast-safe text token for the same chip.
    private func intensityTint(_ level: Intensity) -> Color {
        switch level {
        case .easy: .green
        case .moderate: .orange
        case .hard: .red
        }
    }

    private func intensityTextTint(_ level: Intensity) -> Color {
        switch level {
        case .easy: SmashColor.winText
        case .moderate: SmashColor.warningText
        case .hard: SmashColor.lossText
        }
    }
}

#Preview {
    SessionsView()
        .modelContainer(PreviewContainer.container)
}
