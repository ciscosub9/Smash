import Foundation

// MARK: - Coach's Corner
//
// A small, explainable rule engine over data Smash already records. Every
// insight carries its own evidence and a confidence label — nothing here
// claims causation, and nothing is shown on a sample smaller than three
// matches (two for a head-to-head or partner read).
//
// Both entry points use the same window and the same name/skill normalization,
// and every "worst"/"best" choice has a deterministic tie-break.

nonisolated enum CoachTone: String {
    case form
    case context
    case clutch
    case opponent
    case partner
}

nonisolated enum CoachConfidence: String {
    case high
    case medium
    case early

    var label: String {
        switch self {
        case .high: "Strong signal"
        case .medium: "Good read"
        case .early: "Early read"
        }
    }
}

nonisolated struct CoachInsight: Identifiable, Equatable {
    let id: String
    let tone: CoachTone
    let symbol: String
    let title: String
    let observation: String
    let evidence: String
    let action: String
    let confidence: CoachConfidence
    /// Internal ranking score: effect size × sample size.
    let weight: Double
}

nonisolated struct RatingPoint: Identifiable, Equatable {
    let date: Date
    let ratingBefore: Int
    let rating: Int

    var id: Date { date }
}

nonisolated struct FormRating: Equatable {
    let current: Int
    let starting: Int
    let trend: Int
    let peak: Int
    let matchesRated: Int
    let history: [RatingPoint]

    var trendLabel: String {
        if trend > 0 { return "+\(trend)" }
        if trend < 0 { return "\(trend)" }
        return "0"
    }

    /// Ready-made copy so callers don't render "1 matches rated".
    var matchesRatedLabel: String {
        matchesRated == 1 ? "1 match rated" : "\(matchesRated) matches rated"
    }
}

nonisolated enum CoachInsights {
    // MARK: Rating (ELO-style)

    /// Everyone starts at 1400 (intermediate). Opponents are seeded from the
    /// tier recorded on the match. K = 24 means a single result moves the
    /// number a few points; a long run of results moves it meaningfully.
    private static let baseline = 1400.0
    private static let kFactor = 24.0
    private static let tierRating: [String: Double] = [
        "beginner": 1000,
        "amateur": 1200,
        "intermediate": 1400,
        "advanced": 1600,
        "professional": 1800,
    ]

    static func rating(
        matches: [Match],
        now: Date = .now,
        calendar: Calendar = .current,
        windowDays: Int = 30
    ) -> FormRating {
        // The rating is a form rating: only matches inside the window count,
        // and the ordering is total so same-date results can't flip the number.
        let ordered = windowedMatches(matches, now: now, calendar: calendar, days: windowDays)

        var me = baseline
        var opponentRatings: [String: Double] = [:]
        var history: [RatingPoint] = []

        for match in ordered {
            let key = normalizedName(match.opponent)
            let levelKey = normalizedSkillRaw(match.opponentLevelRaw)
            let theirs = opponentRatings[key]
                ?? tierRating[levelKey] ?? baseline
            let expected = 1.0 / (1.0 + pow(10, (theirs - me) / 400.0))
            let actual: Double
            switch MatchLogic.outcome(match) {
            case .win: actual = 1
            case .loss: actual = 0
            case .draw: actual = 0.5
            }

            let before = me
            me += kFactor * (actual - expected)
            opponentRatings[key] = theirs + kFactor * (expected - actual)
            history.append(RatingPoint(
                date: match.date,
                ratingBefore: Int(before.rounded()),
                rating: Int(me.rounded())
            ))
        }

        let current = Int(me.rounded())
        let starting = history.first?.ratingBefore ?? current

        return FormRating(
            current: current,
            starting: starting,
            trend: current - starting,
            peak: history.map(\.rating).max() ?? current,
            matchesRated: history.count,
            history: history
        )
    }

    // MARK: Insights

    static func insights(
        matches: [Match],
        now: Date = .now,
        calendar: Calendar = .current,
        windowDays: Int = 30
    ) -> [CoachInsight] {
        let recent = windowedMatches(matches, now: now, calendar: calendar, days: windowDays)
        guard recent.count >= 3 else { return [] }

        let overall = MatchLogic.winRate(of: recent)
        // The profile is the caller's own tier when it has been set. With no
        // profile the level rule falls back to a deliberately quiet inference.
        let playerSkill = PlayerProfile.skillLevel
        var results: [CoachInsight] = []

        if let insight = deciderInsight(recent, overall: overall, days: windowDays) {
            results.append(insight)
        }
        if let insight = disciplineInsight(recent, overall: overall, days: windowDays) {
            results.append(insight)
        }
        if let insight = levelInsight(recent, overall: overall, days: windowDays, playerSkill: playerSkill) {
            results.append(insight)
        }
        if let insight = opponentInsight(recent, overall: overall, days: windowDays) {
            results.append(insight)
        }
        results.append(contentsOf: partnerInsights(recent, days: windowDays))
        results.append(formInsight(matches: matches, now: now, calendar: calendar, days: windowDays))

        return results.sorted { lhs, rhs in
            if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
            return lhs.id < rhs.id
        }
    }

    // MARK: Grouping

    /// A label plus the raw grouping key and its samples. The raw key keeps
    /// ids stable after name normalization; the label keeps the first sample's
    /// original spelling for user-facing copy.
    private struct SampleGroup<Key: Hashable> {
        let key: Key
        let label: String
        let matches: [Match]
    }

    /// Worse = lower win rate, then larger sample, then alphabetical label.
    /// Used with `min(by:)` when picking the worst group.
    private static func isWorse<Key>(_ lhs: SampleGroup<Key>, _ rhs: SampleGroup<Key>) -> Bool {
        let lhsRate = winRate(lhs.matches)
        let rhsRate = winRate(rhs.matches)
        if lhsRate != rhsRate { return lhsRate < rhsRate }
        if lhs.matches.count != rhs.matches.count { return lhs.matches.count > rhs.matches.count }
        return lhs.label < rhs.label
    }

    /// Better = higher win rate, then larger sample, then alphabetical label.
    /// Paired with `min(by:)` so a tie still prefers the bigger sample.
    private static func isBetter<Key>(_ lhs: SampleGroup<Key>, _ rhs: SampleGroup<Key>) -> Bool {
        let lhsRate = winRate(lhs.matches)
        let rhsRate = winRate(rhs.matches)
        if lhsRate != rhsRate { return lhsRate > rhsRate }
        if lhs.matches.count != rhs.matches.count { return lhs.matches.count > rhs.matches.count }
        return lhs.label < rhs.label
    }

    private static func groupsByName(
        _ matches: [Match],
        name: (Match) -> String
    ) -> [SampleGroup<String>] {
        Dictionary(grouping: matches, by: { normalizedName(name($0)) }).compactMap { entry in
            guard let first = entry.value.first else { return nil }
            return SampleGroup(
                key: entry.key,
                label: name(first).trimmingCharacters(in: .whitespacesAndNewlines),
                matches: entry.value
            )
        }
    }

    // MARK: Individual rules

    /// Straight-games record versus three-game deciders. A big drop means
    /// endurance or the between-game reset, not stroke technique.
    private static func deciderInsight(
        _ matches: [Match],
        overall: Double,
        days: Int
    ) -> CoachInsight? {
        let bestOfThree = matches.filter { $0.format == .bestOf3 }
        var deciders: [Match] = []
        var straights: [Match] = []
        for match in bestOfThree {
            switch thirdGameClassification(match) {
            case .decider: deciders.append(match)
            case .straight: straights.append(match)
            case .unknown: break
            }
        }
        guard deciders.count >= 3, !straights.isEmpty else { return nil }

        let deciderRate = MatchLogic.winRate(of: deciders)
        let straightRate = MatchLogic.winRate(of: straights)
        guard straightRate - deciderRate >= 0.10 else { return nil }

        return CoachInsight(
            id: "decider",
            tone: .clutch,
            symbol: "flag.checkered",
            title: "Finish it in two",
            observation: "\(percent(straightRate)) in straight games, but \(percent(deciderRate)) once it reaches a decider.",
            evidence: "\(recordText(deciders)) in deciders · \(recordText(straights)) in straight games · last \(days) days",
            action: "Add two third-game simulations to training next week — start each at 10–10 and play it out.",
            confidence: confidence(for: deciders.count),
            weight: (straightRate - deciderRate) * sqrt(Double(deciders.count))
        )
    }

    private enum ThirdGame {
        case decider
        case straight
        case unknown
    }

    /// A decider needs a recorded third game in BOTH score arrays. A straight
    /// needs both opening games played and a third that is absent or 0–0.
    /// Anything else (a partially missing third game, one game only, all zeros)
    /// is unknown and is left out of both buckets.
    private static func thirdGameClassification(_ match: Match) -> ThirdGame {
        let mine = match.myGameScores
        let theirs = match.opponentGameScores
        let hasThree = mine.count >= 3 && theirs.count >= 3

        if hasThree, (mine[2] > 0 || theirs[2] > 0) { return .decider }

        let hasTwo = mine.count >= 2 && theirs.count >= 2
        guard hasTwo,
              (mine[0] > 0 || theirs[0] > 0),
              (mine[1] > 0 || theirs[1] > 0) else { return .unknown }

        let thirdComplete = (mine.count < 3 && theirs.count < 3)
            || (hasThree && mine[2] == 0 && theirs[2] == 0)
        return thirdComplete ? .straight : .unknown
    }

    /// Where a discipline trails the player's overall rate.
    private static func disciplineInsight(
        _ matches: [Match],
        overall: Double,
        days: Int
    ) -> CoachInsight? {
        let eligible = Dictionary(grouping: matches, by: { $0.discipline }).map { entry in
            SampleGroup(key: entry.key, label: entry.key.label, matches: entry.value)
        }
        .filter { $0.matches.count >= 3 }

        guard let worst = eligible.min(by: { isWorse($0, $1) }),
              overall - winRate(worst.matches) >= 0.05 else { return nil }

        let rate = winRate(worst.matches)
        let best = eligible.min(by: { isBetter($0, $1) })
        let comparison: String
        if let best, best.key != worst.key, winRate(best.matches) - rate >= 0.10 {
            comparison = " against \(percent(winRate(best.matches))) in \(best.label.lowercased())"
        } else {
            comparison = " against \(percent(overall)) overall"
        }

        return CoachInsight(
            id: "discipline-\(worst.label)",
            tone: .context,
            symbol: worst.key.symbol,
            title: "Sharpen your \(worst.label.lowercased())",
            observation: "You're at \(percent(rate)) in \(worst.label.lowercased())\(comparison).",
            evidence: "\(recordText(worst.matches)) · last \(days) days",
            action: action(for: worst.key),
            confidence: confidence(for: worst.matches.count),
            weight: (overall - rate) * sqrt(Double(worst.matches.count))
        )
    }

    /// Losing to genuinely lower-tier opponents more often than to stronger
    /// ones is a focus/consistency signal. We never frame advanced or
    /// professional opposition as something the player should "coast" against.
    private static func levelInsight(
        _ matches: [Match],
        overall: Double,
        days: Int,
        playerSkill: SkillLevel?
    ) -> CoachInsight? {
        let eligible = Dictionary(grouping: matches, by: { normalizedSkillRaw($0.opponentLevelRaw) })
            .compactMap { entry -> SampleGroup<String>? in
                guard !entry.key.isEmpty, let first = entry.value.first else { return nil }
                return SampleGroup(
                    key: entry.key,
                    label: skillLabel(first.opponentLevelRaw),
                    matches: entry.value
                )
            }
            .filter { $0.matches.count >= 2 }

        let inferred = playerSkill ?? inferredPlayerSkill(from: matches, overall: overall)
        guard let worst = eligible.filter({ isCoastConcern(tierRaw: $0.key, playerSkill: inferred) })
                .min(by: { isWorse($0, $1) }),
              overall - winRate(worst.matches) >= 0.05 else { return nil }

        let rate = winRate(worst.matches)
        let label = worst.label
        return CoachInsight(
            id: "level-\(worst.key)",
            tone: .context,
            symbol: "eye",
            title: "Don't coast against \(label.lowercased()) players",
            observation: "Only \(percent(rate)) against \(label.lowercased()) opponents, versus \(percent(overall)) overall.",
            evidence: "\(recordText(worst.matches)) vs \(label) · last \(days) days",
            action: "Treat these as focused practice: keep the same serve-and-first-three-shot routine you use against stronger players.",
            confidence: confidence(for: worst.matches.count),
            weight: (overall - rate) * sqrt(Double(worst.matches.count)) * 0.9
        )
    }

    /// Without a profile, only claim an inferred intermediate tier when there
    /// is real evidence of beating intermediate-or-better opponents.
    private static func inferredPlayerSkill(from matches: [Match], overall: Double) -> SkillLevel? {
        let intermediate = tierRating["intermediate"] ?? baseline
        let strongWins = matches.filter { match in
            guard let rating = tierRating[normalizedSkillRaw(match.opponentLevelRaw)],
                  rating >= intermediate else { return false }
            return MatchLogic.outcome(match) == .win
        }.count
        return (strongWins >= 2 && overall >= 0.5) ? .intermediate : nil
    }

    /// Beginner/amateur only, and strictly below the player's own tier.
    private static func isCoastConcern(tierRaw: String, playerSkill: SkillLevel?) -> Bool {
        guard let tier = SkillLevel(rawValue: tierRaw) else { return false }
        let intermediate = tierRating["intermediate"] ?? baseline
        let groupRating = tierRating[tier.rawValue] ?? baseline
        guard groupRating < intermediate else { return false }
        if let playerSkill {
            return groupRating < (tierRating[playerSkill.rawValue] ?? baseline)
        }
        // Unknown player tier: stay quiet unless the opponents are beginners.
        return tier == .beginner
    }

    /// A specific, repeatable head-to-head pattern.
    private static func opponentInsight(
        _ matches: [Match],
        overall: Double,
        days: Int
    ) -> CoachInsight? {
        let eligible = groupsByName(matches, name: { $0.opponent })
            .filter { $0.matches.count >= 2 }
        guard let worst = eligible.min(by: { isWorse($0, $1) }),
              winRate(worst.matches) < 0.5,
              winRate(worst.matches) < overall else { return nil }

        let name = worst.label
        let margins = worst.matches.map { match in
            match.myGameScores.reduce(0, +) - match.opponentGameScores.reduce(0, +)
        }
        let allClose = margins.allSatisfy { abs($0) <= 6 }
        let detail = allClose
            ? " Every meeting was within six points."
            : " It's your weakest repeat match-up."

        return CoachInsight(
            id: "opponent-\(worst.key)",
            tone: .opponent,
            symbol: "person.crop.circle.badge.exclamationmark",
            title: "Break the \(name) pattern",
            observation: "You're \(recordText(worst.matches)) against \(name).\(detail)",
            evidence: "\(worst.matches.count) \(matchesWord(worst.matches.count)) · last \(days) days",
            action: "Write down what won the first point in each game against \(name), then rehearse that one opening before you meet again.",
            confidence: confidence(for: worst.matches.count),
            weight: (0.5 - winRate(worst.matches) + 0.2) * sqrt(Double(worst.matches.count)) * 0.8
        )
    }

    /// Partners turn a generic doubles note into a named one. The observation
    /// is factual (the actual win rate) rather than an unsupported superlative.
    private static func partnerInsights(_ matches: [Match], days: Int) -> [CoachInsight] {
        let doubles = matches.filter { $0.usesPartner && !normalizedName($0.partner).isEmpty }
        let eligible = groupsByName(doubles, name: { $0.partner })
            .filter { $0.matches.count >= 2 }

        return eligible.compactMap { entry in
            let rate = winRate(entry.matches)
            let isStrength = rate >= 0.75
            guard isStrength || rate <= 0.5 else { return nil }

            let name = entry.label
            return CoachInsight(
                id: "partner-\(entry.key)",
                tone: .partner,
                symbol: isStrength ? "person.2.wave.2" : "questionmark.circle",
                title: isStrength ? "Keep pairing with \(name)" : "Partner check: \(name)",
                observation: "You're \(recordText(entry.matches)) with \(name) — \(percent(rate)) of those matches.",
                evidence: "\(entry.matches.count) doubles matches together · last \(days) days",
                action: isStrength
                    ? "Lean on that chemistry in tight games — keep the same front/back roles that have been working."
                    : "Switch front and back roles for one game with \(name), then keep the formation that scores more.",
                confidence: confidence(for: entry.matches.count),
                weight: abs(rate - 0.5) * sqrt(Double(entry.matches.count)) * 0.95
            )
        }
    }

    /// The rating gets a plain-language read so the number means something.
    private static func formInsight(
        matches: [Match],
        now: Date,
        calendar: Calendar,
        days: Int
    ) -> CoachInsight {
        let rating = rating(matches: matches, now: now, calendar: calendar, windowDays: days)
        let climbing = rating.trend >= 20
        let slipping = rating.trend <= -20

        let title: String
        let observation: String
        let action: String
        let insightConfidence: CoachConfidence
        if rating.matchesRated == 0 {
            title = "No recent form data"
            observation = "No matches in the last \(days) days — log one to start a form rating."
            action = "Play or record a match this week to build a form read."
            insightConfidence = .early
        } else if climbing {
            title = "Form is climbing"
            observation = "Your form rating is up \(abs(rating.trend)) points over the last \(days) days — now \(rating.current)."
            action = "Keep the current mix of play and training; you're beating what your results predict."
            insightConfidence = confidence(for: rating.matchesRated)
        } else if slipping {
            title = "Form is dipping"
            observation = "Your form rating is down \(abs(rating.trend)) points over the last \(days) days — now \(rating.current)."
            action = "Focus on one repeatable strength in your next two matches rather than changing everything."
            insightConfidence = confidence(for: rating.matchesRated)
        } else {
            title = "Form is holding steady"
            observation = "Your form rating is \(rating.current), essentially flat over the last \(days) days."
            action = "To move it, aim for one result against a higher-tier opponent this week."
            insightConfidence = confidence(for: rating.matchesRated)
        }

        return CoachInsight(
            id: "form",
            tone: .form,
            symbol: "chart.line.uptrend.xyaxis",
            title: title,
            observation: observation,
            evidence: "\(rating.matchesRatedLabel) · seeded from opponent levels",
            action: action,
            confidence: insightConfidence,
            // Context, not advice — let actionable notes lead the deck.
            weight: rating.matchesRated == 0 ? 0 : 0.3 + Double(abs(rating.trend)) / 800.0
        )
    }

    // MARK: Helpers

    /// Inclusive 30-calendar-day window: today and the previous (days - 1)
    /// days, with an upper bound at `now` so future-dated matches never leak in.
    private static func windowStart(now: Date, calendar: Calendar, days: Int) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday)
            ?? startOfToday
    }

    private static func windowedMatches(
        _ matches: [Match],
        now: Date,
        calendar: Calendar,
        days: Int
    ) -> [Match] {
        let start = windowStart(now: now, calendar: calendar, days: days)
        return matches
            .filter { !normalizedName($0.opponent).isEmpty }
            .filter { $0.date >= start && $0.date <= now }
            .sorted { matchOrder($0, $1) }
    }

    /// Total order for same-date matches: date, opponent, partner, type,
    /// point system, level, then the full score set. Results with identical
    /// keys are equivalent, so any remaining order is immaterial.
    private static func matchOrder(_ lhs: Match, _ rhs: Match) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }

        let lhsOpponent = normalizedName(lhs.opponent)
        let rhsOpponent = normalizedName(rhs.opponent)
        if lhsOpponent != rhsOpponent { return lhsOpponent < rhsOpponent }

        let lhsPartner = normalizedName(lhs.partner)
        let rhsPartner = normalizedName(rhs.partner)
        if lhsPartner != rhsPartner { return lhsPartner < rhsPartner }

        if lhs.disciplineRaw != rhs.disciplineRaw { return lhs.disciplineRaw < rhs.disciplineRaw }
        if lhs.formatRaw != rhs.formatRaw { return lhs.formatRaw < rhs.formatRaw }
        if lhs.pointSystemRaw != rhs.pointSystemRaw { return lhs.pointSystemRaw < rhs.pointSystemRaw }

        let lhsLevel = normalizedSkillRaw(lhs.opponentLevelRaw)
        let rhsLevel = normalizedSkillRaw(rhs.opponentLevelRaw)
        if lhsLevel != rhsLevel { return lhsLevel < rhsLevel }

        let lhsScores = scoreSignature(lhs)
        let rhsScores = scoreSignature(rhs)
        return lhsScores < rhsScores
    }

    private static func scoreSignature(_ match: Match) -> String {
        let mine = match.myGameScores.map { "\($0)" }.joined(separator: ",")
        let theirs = match.opponentGameScores.map { "\($0)" }.joined(separator: ",")
        return "\(mine)|\(theirs)"
    }

    /// One normalization for every name used for grouping or filtering — both
    /// here and in the rating. Display copy uses the first sample's spelling.
    private static func normalizedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Invalid or blank skill strings never become group keys or user copy.
    private static func normalizedSkillRaw(_ raw: String?) -> String {
        let key = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SkillLevel(rawValue: key) != nil ? key : ""
    }

    private static func skillLabel(_ raw: String?) -> String {
        SkillLevel(rawValue: normalizedSkillRaw(raw))?.label ?? "opponent"
    }

    private static func winRate(_ matches: [Match]) -> Double {
        MatchLogic.winRate(of: matches)
    }

    private static func recordText(_ matches: [Match]) -> String {
        let wins = matches.filter { MatchLogic.outcome($0) == .win }.count
        let losses = matches.filter { MatchLogic.outcome($0) == .loss }.count
        let draws = matches.filter { MatchLogic.outcome($0) == .draw }.count
        let base = "\(wins)W–\(losses)L"
        return draws > 0 ? "\(base)–\(draws)D" : base
    }

    private static func matchesWord(_ count: Int) -> String {
        count == 1 ? "match" : "matches"
    }

    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func confidence(for count: Int) -> CoachConfidence {
        count >= 10 ? .high : (count >= 5 ? .medium : .early)
    }

    private static func action(for discipline: Discipline) -> String {
        switch discipline {
        case .singles:
            "Carry your doubles net play into singles — practise one drop-and-lift pattern in your next solo session."
        case .doubles:
            "Drill front-court rotation with your partner: one net-interception set before your next match."
        case .mixedDoubles:
            "Rehearse the front/back rotation with your partner so the net player finishes the rally."
        }
    }
}
