import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(SmashStore.self) private var store
    @Query(sort: \PlaySession.date, order: .reverse) private var playSessions: [PlaySession]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    /// Screenshots and UI tests can open the player card directly:
    /// `simctl launch com.smashapp.smash -settings`
    @State private var showProfile = CommandLine.arguments.contains("-settings")
    @State private var showSearch = false
    @AppStorage(PlayerProfile.avatarKey) private var playerAvatar = PlayerProfile.defaultAvatar
    @AppStorage(PlayerProfile.avatarColorKey) private var playerAvatarColor = PlayerProfile.defaultAvatarColor
    @AppStorage(AppearancePreference.storageKey) private var appearanceRaw = AppearancePreference.dark.rawValue
    @AppStorage(PlayerGoal.kindKey) private var goalKindRaw = GoalKind.weekly.rawValue
    @AppStorage(PlayerGoal.targetKey) private var goalTarget = 3
    @AppStorage(DashboardPeriod.storageKey) private var dashboardPeriodRaw = DashboardPeriod.Period.weekly.rawValue
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The scheme actually in effect — an explicit preference, or the system's.
    private var isDark: Bool {
        (AppearancePreference(rawValue: appearanceRaw)?.colorScheme ?? systemColorScheme) == .dark
    }

    var body: some View {
        // Derived values can be expensive; compute each once per body pass.
        let period = self.period
        let periodWord = self.periodWord
        let periodMatches = self.periodMatches
        let insights = self.coachInsights
        let rating = self.formRating
        let activity = self.activity

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statGrid(periodWord: periodWord, matches: periodMatches)
                    if !insights.isEmpty {
                        CoachCornerView(insights: insights)
                    }
                    formRatingCard(rating: rating)
                    if goalProgress != nil {
                        goalCard
                    }
                    activityChart(activity: activity, period: period)
                    recentMatches(periodWord: periodWord, periodMatches: periodMatches)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        Label {
                            Text("Profile")
                        } icon: {
                            ToolbarAvatarView(name: playerAvatar, color: playerAvatarColor)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .sensoryFeedback(.selection, trigger: showProfile)
                    .accessibilityLabel("Profile")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Search everything")

                    // Quick light/dark switch — one tap, no dig through Settings.
                    Button {
                        appearanceRaw = (isDark ? AppearancePreference.light : .dark).rawValue
                    } label: {
                        Label(isDark ? "Light mode" : "Dark mode",
                              systemImage: isDark ? "sun.max.fill" : "moon.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PressableStyle())
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: isDark)
                    .sensoryFeedback(.selection, trigger: appearanceRaw)
                    .accessibilityLabel(isDark ? "Switch to light mode" : "Switch to dark mode")
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showSearch) {
                GlobalSearchView()
            }
        }
    }

    // MARK: - Stats

    /// One setting switches every metric on this screen between the current
    /// calendar week and the current calendar month.
    private var period: DashboardPeriod.Period {
        DashboardPeriod.Period(rawValue: dashboardPeriodRaw) ?? .weekly
    }

    private var periodInterval: DateInterval? {
        Stats.interval(for: period.goalKind)
    }

    private var activity: [DayActivity] {
        if let interval = periodInterval {
            return Stats.dailyActivity(play: playSessions, training: trainingSessions, in: interval)
        }
        return Stats.dailyActivity(play: playSessions, training: trainingSessions, days: 7)
    }

    private var periodSessions: Int {
        guard let interval = periodInterval else { return 0 }
        return Stats.sessions(play: playSessions, training: trainingSessions, in: interval)
    }

    private var periodMatches: [Match] {
        guard let interval = periodInterval else { return matches }
        return Stats.matches(matches, in: interval)
    }

    private var periodWord: String { period == .weekly ? "week" : "month" }

    private func statGrid(periodWord: String, matches: [Match]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "This \(periodWord) on court",
                value: "\(periodSessions)",
                symbol: "figure.play",
                tint: SmashColor.winText,
                caption: "play + training in number of sessions"
            )
            StatCard(
                title: "Matches",
                value: "\(matches.count)",
                symbol: "trophy",
                tint: SmashColor.partnerText,
                caption: "games this \(periodWord)"
            )
            StatCard(
                title: "Win rate",
                value: winRateLabel(for: matches),
                symbol: "chart.line.uptrend.xyaxis",
                tint: SmashColor.infoText,
                caption: "of matches this \(periodWord)"
            )
            StatCard(
                title: "Loss rate",
                value: lossRateLabel(for: matches),
                symbol: "chart.line.downtrend.xyaxis",
                tint: SmashColor.lossText,
                caption: "of matches this \(periodWord)"
            )
        }
    }

    private var goalKind: GoalKind { GoalKind(rawValue: goalKindRaw) ?? .none }

    private func winRateLabel(for matches: [Match]) -> String {
        let rate = MatchLogic.winRate(of: matches)
        return matches.isEmpty
            ? "–"
            : rate.formatted(.percent.precision(.fractionLength(0)))
    }

    private func lossRateLabel(for matches: [Match]) -> String {
        guard !matches.isEmpty else { return "–" }
        let losses = matches.filter { MatchLogic.outcome($0) == .loss }.count
        return (Double(losses) / Double(matches.count))
            .formatted(.percent.precision(.fractionLength(0)))
    }

    // MARK: - Goal
    //
    // v1 placement: a live progress card. The end-of-week recap / celebration
    // screen is intentionally left for a later design pass.

    private var goalProgress: (count: Int, target: Int, kind: GoalKind)? {
        guard goalKind != .none, let interval = Stats.interval(for: goalKind) else { return nil }
        let count = Stats.sessions(play: playSessions, training: trainingSessions, in: interval)
        return (count, max(1, goalTarget), goalKind)
    }

    private var goalCard: some View {
        let progress = goalProgress!
        let isMet = progress.count >= progress.target
        let fraction = min(Double(progress.count) / Double(progress.target), 1)
        let remaining = max(progress.target - progress.count, 0)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(progress.kind == .weekly ? "Weekly goal" : "Monthly goal", systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isMet {
                    Label("Smashed!", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SmashColor.winText)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Text("\(progress.count) of \(progress.target)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(isMet ? .green : .accentColor)

            Text(isMet
                 ? "Goal met — \(progress.target) sessions this \(progress.kind.unit). See you on court."
                 : "\(remaining) session\(remaining == 1 ? "" : "s") to go this \(progress.kind.unit).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isMet)
        .sensoryFeedback(.success, trigger: isMet)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isMet
            ? "Goal smashed: \(progress.count) of \(progress.target) sessions this \(progress.kind.unit)"
            : "\(progress.count) of \(progress.target) sessions this \(progress.kind.unit), \(remaining) to go"
        )
    }

    // MARK: - Coach

    /// Always the last 30 days: a single dashboard week usually has too few
    /// matches for a pattern to mean anything.
    private var coachInsights: [CoachInsight] {
        CoachInsights.insights(matches: matches)
    }

    private var formRating: FormRating {
        CoachInsights.rating(matches: matches)
    }

    private func formRatingCard(rating: FormRating) -> some View {
        let hasData = rating.matchesRated > 0
        let rising = rating.trend >= 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Form rating", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Zero rated matches is not a positive or negative trend.
                Text(hasData ? "\(rating.trendLabel) · 30 days" : "No recent matches")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        hasData
                            ? (rising ? SmashColor.winText : SmashColor.lossText)
                            : Color.secondary
                    )
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(rating.current)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                Text(hasData ? rating.matchesRatedLabel : "log matches to get a rating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Wins lift it, losses drop it. Beating a stronger player moves it more than beating a beginner.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            hasData
                ? "Form rating \(rating.current), \(rating.trendLabel) over 30 days"
                : "Form rating \(rating.current), no recent matches"
        )
    }

    // MARK: - Chart

    private func activityChart(activity: [DayActivity], period: DashboardPeriod.Period) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(period == .weekly ? "This week" : "This month")
                    .font(.headline)
                Text("in number of sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(Array(activity.enumerated()), id: \.element.id) { index, day in
                BarMark(
                    x: .value("Day", "\(index)"),
                    y: .value("Sessions", day.playCount)
                )
                .foregroundStyle(by: .value("Type", "Play"))

                BarMark(
                    x: .value("Day", "\(index)"),
                    y: .value("Sessions", day.trainingCount)
                )
                .foregroundStyle(by: .value("Type", "Training"))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(String.self).flatMap(Int.init),
                           activity.indices.contains(index) {
                            if activity.count > 10 {
                                Text(activity[index].day, format: .dateTime.day())
                            } else {
                                Text(activity[index].day, format: .dateTime.weekday(.narrow))
                            }
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "Play": Color.green,
                "Training": Color.blue,
            ])
            .chartLegend(position: .bottom)
            .frame(height: 180)
        }
        .cardStyle()
    }

    // MARK: - Recent matches

    private func recentMatches(periodWord: String, periodMatches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent matches")
                .font(.headline)

            if periodMatches.isEmpty {
                Text("No matches this \(periodWord). Log one from the Sessions tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let shown = Array(periodMatches.prefix(3))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, match in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Me vs \(match.opponent)")
                                    .font(.subheadline.weight(.semibold))
                                Text(AppFormat.dateTime(match.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            OutcomeBadge(outcome: MatchLogic.outcome(match))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                        if index < shown.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Global search

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlaySession.date, order: .reverse) private var playSessions: [PlaySession]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]
    @Query(sort: \Tournament.startDate, order: .reverse) private var tournaments: [Tournament]

    @State private var searchText = ""

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: "Search everything",
                        message: "Find opponents, locations, drills, focus areas, tournaments, and notes."
                    )
                } else if filteredMatches.isEmpty && filteredPlay.isEmpty && filteredTraining.isEmpty && filteredTournaments.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    if !filteredMatches.isEmpty {
                        Section("Matches") {
                            ForEach(filteredMatches) { match in
                                NavigationLink(value: match) {
                                    MatchRow(match: match)
                                }
                            }
                        }
                    }
                    if !filteredPlay.isEmpty {
                        Section("Play") {
                            ForEach(filteredPlay) { session in
                                PlaySearchRow(session: session)
                            }
                        }
                    }
                    if !filteredTraining.isEmpty {
                        Section("Training") {
                            ForEach(filteredTraining) { session in
                                TrainingSearchRow(session: session)
                            }
                        }
                    }
                    if !filteredTournaments.isEmpty {
                        Section("Tournaments") {
                            ForEach(filteredTournaments) { tournament in
                                NavigationLink(value: tournament) {
                                    TournamentSearchRow(tournament: tournament)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Opponents, places, drills, notes…")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Match.self) { match in
                MatchDetailView(match: match)
            }
            .navigationDestination(for: Tournament.self) { tournament in
                TournamentDetailView(tournament: tournament)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func contains(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return false }
        return text.localizedCaseInsensitiveContains(query)
    }

    private var filteredMatches: [Match] {
        guard !query.isEmpty else { return [] }
        return matches.filter { match in
            contains(match.opponent)
            || match.myGameScores.contains(where: { "\($0)".contains(query) })
            || match.opponentGameScores.contains(where: { "\($0)".contains(query) })
            || contains(match.notes)
            || contains(match.discipline.label)
            || contains(match.pointSystem.label)
            || contains(match.intensity?.label)
            || contains(match.opponentLevel?.label)
            || contains(match.tournament?.name)
        }
    }

    private var filteredPlay: [PlaySession] {
        guard !query.isEmpty else { return [] }
        return playSessions.filter { session in
            session.opponents.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || contains(session.location)
            || contains(session.notes)
            || contains(session.discipline.label)
            || contains(session.intensity?.label)
        }
    }

    private var filteredTraining: [TrainingSession] {
        guard !query.isEmpty else { return [] }
        return trainingSessions.filter { session in
            session.focusAreas.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || contains(session.drillsDescription)
            || session.drillNames.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || contains(session.notes)
            || contains(session.intensity?.label)
        }
    }

    private var filteredTournaments: [Tournament] {
        guard !query.isEmpty else { return [] }
        return tournaments.filter { tournament in
            contains(tournament.name)
            || contains(tournament.strategyNotes)
            || contains(tournament.type.label)
            || contains(tournament.placement?.label)
        }
    }
}

private struct PlaySearchRow: View {
    let session: PlaySession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(AppFormat.duration(minutes: session.durationMinutes), systemImage: "figure.play")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(AppFormat.dateTime(session.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text([session.discipline.label, session.location, session.opponents.joined(separator: ", ")]
                .compactMap { $0?.isEmpty == false ? $0 : nil }
                .joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct TrainingSearchRow: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(AppFormat.duration(minutes: session.durationMinutes), systemImage: "dumbbell")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(AppFormat.dateTime(session.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let detail = (session.drillNames + session.focusAreas)
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct TournamentSearchRow: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(tournament.name, systemImage: tournament.type.symbol)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let placement = tournament.placement {
                    Text(placement.label)
                        .font(.caption)
                        .foregroundStyle(SmashColor.warningText)
                }
            }
            Text("\(tournament.type.label) · \(tournament.recordDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(PreviewContainer.container)
        .environment(SmashStore(syncMode: .local))
}
