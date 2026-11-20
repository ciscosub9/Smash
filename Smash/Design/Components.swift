import SwiftUI

// MARK: - Formatting helpers

enum AppFormat {
    /// "1h 30m" style duration label from minutes.
    static func duration(minutes: Int) -> String {
        let duration = Duration.seconds(minutes * 60)
        return duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "Mon 16 Sep" style date label.
    static func date(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// "Nov 16, 2026, 6:30 PM" — or "18:30" in 24-hour mode.
    static func dateTime(_ date: Date) -> String {
        dateTimeFormatters[TimePreference.format]!.string(from: date)
    }

    /// Time portion only, following the player's clock preference.
    static func time(_ date: Date) -> String {
        timeFormatters[TimePreference.format]!.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// One formatter per clock preference — built once, not on every call.
    private static let dateTimeFormatters: [TimePreference.Format: DateFormatter] = {
        var formatters: [TimePreference.Format: DateFormatter] = [:]
        for format in TimePreference.Format.allCases {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format == .twelveHour
                ? "MMM d, y, h:mm a"
                : "MMM d, y, HH:mm"
            formatters[format] = formatter
        }
        return formatters
    }()

    private static let timeFormatters: [TimePreference.Format: DateFormatter] = {
        var formatters: [TimePreference.Format: DateFormatter] = [:]
        for format in TimePreference.Format.allCases {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format == .twelveHour ? "h:mm a" : "HH:mm"
            formatters[format] = formatter
        }
        return formatters
    }()

}

/// Hours + minutes picker used for session and training durations.
struct DurationPicker: View {
    @Binding var totalMinutes: Int
    var hourRange: ClosedRange<Int> = 0...8
    var minuteStep: Int = 5

    private var hours: Int { totalMinutes / 60 }
    private var minutes: Int { totalMinutes % 60 }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: Binding(
                get: { hours },
                set: { totalMinutes = max(minuteStep, $0 * 60 + minutes) }
            )) {
                ForEach(hourRange, id: \.self) { hour in
                    Text("\(hour) h").tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Minutes", selection: Binding(
                get: { (minutes / minuteStep) * minuteStep },
                set: { totalMinutes = max(minuteStep, hours * 60 + $0) }
            )) {
                ForEach(Array(stride(from: 0, through: 55, by: minuteStep)), id: \.self) { minute in
                    Text("\(minute) m").tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 120)
        .sensoryFeedback(.selection, trigger: totalMinutes)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Date + time entry
//
/// One control for "when". The AM/PM wheel exists only in 12-hour mode; in
/// 24-hour mode hours run 0–23 and no AM/PM is shown anywhere.
struct DateTimeEntry: View {
    @Binding var date: Date
    @AppStorage(TimePreference.storageKey) private var timeFormatRaw = TimePreference.Format.twelveHour.rawValue

    private var is24Hour: Bool {
        (TimePreference.Format(rawValue: timeFormatRaw) ?? .twelveHour) == .twentyFourHour
    }
    private var calendar: Calendar { .current }
    private var hour: Int { calendar.component(.hour, from: date) }
    private var minute: Int { calendar.component(.minute, from: date) }
    private var isPM: Bool { hour >= 12 }
    private var displayHour: Int {
        guard !is24Hour else { return hour }
        let base = hour % 12
        return base == 0 ? 12 : base
    }
    private var hourRange: Range<Int> { is24Hour ? 0..<24 : 1..<13 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker("Date", selection: datePreservingTime, in: ...Date.now, displayedComponents: .date)

            HStack(spacing: 0) {
                Picker("Hour", selection: Binding(get: { displayHour }, set: setHour)) {
                    ForEach(hourRange, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Text(":")
                    .foregroundStyle(.secondary)

                Picker("Minute", selection: Binding(get: { minute }, set: setMinute)) {
                    ForEach(0..<60, id: \.self) { value in
                        Text(String(format: "%02d", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                if !is24Hour {
                    Picker("AM / PM", selection: Binding(get: { isPM ? 1 : 0 }, set: setPeriod)) {
                        Text("AM").tag(0)
                        Text("PM").tag(1)
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90)
                    .clipped()
                }
            }
            .frame(height: 100)
            .accessibilityElement(children: .contain)
        }
    }

    private var datePreservingTime: Binding<Date> {
        Binding(
            get: { date },
            set: { newDate in
                var parts = calendar.dateComponents([.year, .month, .day], from: newDate)
                parts.hour = hour
                parts.minute = minute
                date = calendar.date(from: parts) ?? newDate
            }
        )
    }

    private func setHour(_ shown: Int) {
        var parts = calendar.dateComponents([.year, .month, .day, .minute], from: date)
        parts.hour = is24Hour ? shown : (shown % 12) + (isPM ? 12 : 0)
        date = calendar.date(from: parts) ?? date
    }

    private func setMinute(_ value: Int) {
        var parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        parts.minute = value
        date = calendar.date(from: parts) ?? date
    }

    private func setPeriod(_ value: Int) {
        var parts = calendar.dateComponents([.year, .month, .day, .minute], from: date)
        parts.hour = (hour % 12) + (value == 1 ? 12 : 0)
        date = calendar.date(from: parts) ?? date
    }
}

// MARK: - Start time
//
/// Time-only wheels for the Court time card. The AM/PM wheel is present only
/// when the player uses a 12-hour clock.
struct StartTimePicker: View {
    @Binding var time: Date
    @AppStorage(TimePreference.storageKey) private var timeFormatRaw = TimePreference.Format.twelveHour.rawValue

    private var is24Hour: Bool {
        (TimePreference.Format(rawValue: timeFormatRaw) ?? .twelveHour) == .twentyFourHour
    }
    private var calendar: Calendar { .current }
    private var hour: Int { calendar.component(.hour, from: time) }
    private var minute: Int { calendar.component(.minute, from: time) }
    private var isPM: Bool { hour >= 12 }
    private var displayHour: Int {
        guard !is24Hour else { return hour }
        let base = hour % 12
        return base == 0 ? 12 : base
    }
    private var hourRange: Range<Int> { is24Hour ? 0..<24 : 1..<13 }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hour", selection: Binding(get: { displayHour }, set: setHour)) {
                ForEach(hourRange, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Text(":")
                .foregroundStyle(.secondary)

            Picker("Minute", selection: Binding(get: { minute }, set: setMinute)) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            if !is24Hour {
                Picker("AM / PM", selection: Binding(get: { isPM ? 1 : 0 }, set: setPeriod)) {
                    Text("AM").tag(0)
                    Text("PM").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 90)
                .clipped()
            }
        }
        .frame(height: 100)
        .accessibilityElement(children: .contain)
    }

    private func setHour(_ shown: Int) {
        var parts = calendar.dateComponents([.year, .month, .day, .minute], from: time)
        parts.hour = is24Hour ? shown : (shown % 12) + (isPM ? 12 : 0)
        time = calendar.date(from: parts) ?? time
    }

    private func setMinute(_ value: Int) {
        var parts = calendar.dateComponents([.year, .month, .day, .hour], from: time)
        parts.minute = value
        time = calendar.date(from: parts) ?? time
    }

    private func setPeriod(_ value: Int) {
        var parts = calendar.dateComponents([.year, .month, .day, .minute], from: time)
        parts.hour = (hour % 12) + (value == 1 ? 12 : 0)
        time = calendar.date(from: parts) ?? time
    }
}

// MARK: - Press feedback
//
// apple-design skill: feedback must land on press-down, never on release,
// and the spring is critically damped — a card press isn't a momentum
// gesture, so no bounce.

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1.0), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: SmashRadius.tile, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SmashRadius.tile, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 0.5)
        }
        .foregroundStyle(tint)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Outcome badge

struct OutcomeBadge: View {
    let outcome: MatchOutcome

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(fill.opacity(0.15), in: Capsule())
            .foregroundStyle(textColor)
    }

    private var label: String {
        switch outcome {
        case .win: "Win"
        case .loss: "Loss"
        case .draw: "Draw"
        }
    }

    /// Bright brand colour for the capsule fill only.
    private var fill: Color {
        switch outcome {
        case .win: .green
        case .loss: .red
        case .draw: .orange
        }
    }

    /// Darkened foreground so small text clears WCAG AA in light mode.
    private var textColor: Color {
        switch outcome {
        case .win: SmashColor.winText
        case .loss: SmashColor.lossText
        case .draw: SmashColor.warningText
        }
    }
}

// MARK: - List row backgrounds

/// A grouped-list card look: rounded fill with a hairline edge so the card
/// still reads as a card in light mode, where the grouped background and the
/// secondary background are close in colour.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                .background.secondary,
                in: RoundedRectangle(cornerRadius: SmashRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SmashRadius.card, style: .continuous)
                    .stroke(.separator.opacity(0.35), lineWidth: 0.5)
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

// MARK: - Match row

/// One scored match in a list. Used by Sessions, Tournaments and Dashboard.
struct MatchRow: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Me vs \(match.opponent)")
                    .font(.headline)
                if match.usesPartner && !match.partner.isEmpty {
                    Text("with \(match.partner)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                OutcomeBadge(outcome: MatchLogic.outcome(match))
            }

            if !games.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(games, id: \.number) { game in
                            gameCard(game)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text(match.pointSystem.label)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
                if match.tournament != nil {
                    Image(systemName: "medal")
                        .font(.caption)
                        .foregroundStyle(SmashColor.warningText)
                }
                Spacer()
                Text(AppFormat.dateTime(match.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func gameCard(_ game: GameScore) -> some View {
        VStack(spacing: 3) {
            Text("Game \(game.number)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("\(game.mine)")
                    .foregroundStyle(game.mine > game.theirs ? SmashColor.winText : .secondary)
                Text("–")
                    .foregroundStyle(.tertiary)
                Text("\(game.theirs)")
                    .foregroundStyle(game.theirs > game.mine ? SmashColor.lossText : .secondary)
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            .fill.tertiary,
            in: RoundedRectangle(cornerRadius: SmashRadius.chip, style: .continuous)
        )
    }

    private var games: [GameScore] {
        zip(match.myGameScores, match.opponentGameScores).enumerated().map { index, pair in
            GameScore(number: index + 1, mine: pair.0, theirs: pair.1)
        }
    }

    private struct GameScore {
        let number: Int
        let mine: Int
        let theirs: Int
    }
}

// MARK: - Floating add button

/// The same round plus button on Sessions, Players and Tournaments.
struct AddButtonLabel: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.semibold))
            // White on the brand green is only ~2:1 in dark mode; a dark glyph
            // stays legible on both the light and dark accent fills.
            .foregroundStyle(.black.opacity(0.85))
            .frame(width: 54, height: 54)
            .background(Color.accentColor, in: Circle())
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}

// MARK: - Avatar picker

/// The avatar + colour picker shared by onboarding and Profile. `compact`
/// reproduces the slightly tighter metrics used inside the Profile form.
struct AvatarPicker: View {
    @Binding var avatar: String
    @Binding var color: String
    var compact: Bool = false

    private var avatarHeight: CGFloat { compact ? 46 : 50 }
    private var swatchSize: CGFloat { compact ? 28 : 30 }
    private var selectionWidth: CGFloat { compact ? 2 : 2.5 }
    private var labelFont: Font { compact ? .subheadline.weight(.semibold) : .caption.weight(.semibold) }
    private var labelColor: Color { compact ? .primary : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Avatar")
                    .font(labelFont)
                    .foregroundStyle(labelColor)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(PlayerProfile.avatarChoices, id: \.self) { icon in
                        Button { avatar = icon } label: {
                            AvatarView(name: icon, color: color)
                                .frame(height: avatarHeight)
                                .overlay {
                                    if avatar == icon {
                                        Circle().stroke(Color.accentColor, lineWidth: selectionWidth)
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .sensoryFeedback(.selection, trigger: avatar == icon)
                        .accessibilityLabel("Avatar \(icon)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Colour")
                    .font(labelFont)
                    .foregroundStyle(labelColor)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PlayerProfile.avatarColors, id: \.self) { hex in
                            Button { color = hex } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: swatchSize, height: swatchSize)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                        if color == hex {
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectionWidth)
                                                .padding(2)
                                        }
                                    }
                            }
                            .buttonStyle(PressableStyle())
                            .sensoryFeedback(.selection, trigger: color == hex)
                            .accessibilityLabel("Avatar Colour \(hex)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Goal controls

/// One goal picker used on the first run and in Profile. The target is chosen
/// from a list, so both screens read and write the same stored values.
struct GoalControls: View {
    @Binding var kindRaw: String
    @Binding var target: Int

    private var kind: GoalKind { GoalKind(rawValue: kindRaw) ?? .weekly }

    var body: some View {
        Picker("Goal", selection: $kindRaw) {
            Text("Off").tag(GoalKind.none.rawValue)
            Text("Weekly").tag(GoalKind.weekly.rawValue)
            Text("Monthly").tag(GoalKind.monthly.rawValue)
        }
        .pickerStyle(.segmented)

        if kind != .none {
            Picker("Sessions each \(kind.unit)", selection: $target) {
                ForEach(kind.targetRange, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
