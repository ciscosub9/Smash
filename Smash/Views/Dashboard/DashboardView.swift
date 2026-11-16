import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(SmashStore.self) private var store
    @Query(sort: \PlaySession.date, order: .reverse) private var playSessions: [PlaySession]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statGrid
                    activityChart
                    recentMatches
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Stats

    private var activity: [DayActivity] {
        Stats.dailyActivity(play: playSessions, training: trainingSessions, days: 7)
    }

    private var weekMinutes: Int {
        activity.reduce(0) { $0 + $1.totalMinutes }
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "This week",
                value: AppFormat.duration(minutes: weekMinutes),
                symbol: "clock",
                tint: .green
            )
            StatCard(
                title: "Streak",
                value: streakLabel,
                symbol: "flame",
                tint: .orange
            )
            StatCard(
                title: "Win rate",
                value: winRateLabel,
                symbol: "chart.line.uptrend.xyaxis",
                tint: .blue
            )
            StatCard(
                title: "Matches",
                value: "\(matches.count)",
                symbol: "trophy",
                tint: .purple
            )
        }
    }

    private var streakLabel: String {
        if let streak = Stats.currentStreak(matches) {
            let kind = streak.kind == .win ? "W" : "L"
            return "\(streak.count)\(kind)"
        }
        let days = Stats.activityStreak(play: playSessions, training: trainingSessions)
        return days > 0 ? "\(days)d" : "–"
    }

    private var winRateLabel: String {
        let rate = MatchLogic.winRate(of: matches)
        return rate == 0 && matches.isEmpty
            ? "–"
            : rate.formatted(.percent.precision(.fractionLength(0)))
    }

    // MARK: - Chart

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days")
                .font(.headline)

            Chart(Array(activity.enumerated()), id: \.element.id) { index, day in
                BarMark(
                    x: .value("Day", "\(index)"),
                    y: .value("Minutes", day.playMinutes)
                )
                .foregroundStyle(Color.green.gradient)

                BarMark(
                    x: .value("Day", "\(index)"),
                    y: .value("Minutes", day.trainingMinutes)
                )
                .foregroundStyle(Color.blue.gradient)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(String.self).flatMap(Int.init),
                           activity.indices.contains(index) {
                            Text(activity[index].day, format: .dateTime.weekday(.narrow))
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

    private var recentMatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent matches")
                .font(.headline)

            if matches.isEmpty {
                Text("No matches yet — record your first one from the Matches tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches.prefix(3)) { match in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("vs \(match.opponent)")
                                .font(.subheadline.weight(.semibold))
                            Text(AppFormat.date(match.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        OutcomeBadge(outcome: MatchLogic.outcome(match))
                    }
                }
            }
        }
        .cardStyle()
    }
}

#Preview {
    DashboardView()
        .modelContainer(PreviewContainer.container)
        .environment(SmashStore(syncMode: .local))
}
