import SwiftUI
import SwiftData

/// The Court time form. Date, start time and duration have sensible defaults;
/// the opponents and the final score are the parts Smash won't let you skip.
struct PlayFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var savedPlayers: [Player]
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    @State private var day = Date.now
    @State private var startTime = Date.now
    @State private var hours = 1
    @State private var discipline: Discipline = .singles
    @State private var intensity: Intensity? = .moderate
    @State private var opponentOne = ""
    @State private var opponentTwo = ""
    @State private var partner = ""
    @State private var notes = ""

    @State private var pointSystem: PointSystem = .points21
    @State private var format: MatchFormat = .bestOf3
    @State private var gameCount = 3
    @State private var myScores = [0, 0, 0]
    @State private var opponentScores = [0, 0, 0]
    @State private var showScoreEditor = false
    @State private var showValidation = false
    @State private var validationText = ""

    /// The linked Match is resolved once when the form is populated, then reused.
    /// Re-matching after the date or names are edited would lose it and insert a
    /// duplicate. Keeping the exact object also excludes tournament matches.
    @State private var linkedMatchState: Match?
    /// Population happens once per editing target. Re-running it after a sheet
    /// returns would throw away unsaved edits.
    @State private var didPopulate = false
    /// Blocks a second Save tap while the first one is writing to the context.
    @State private var isSaving = false

    private let editing: PlaySession?
    /// Editing a scored match uses this same form, whether or not it has a
    /// PlaySession attached. Add and edit therefore look and behave identically.
    private let editingMatch: Match?
    private let presetDiscipline: Discipline?
    var embedded: Bool
    var onSaved: (() -> Void)?

    init(
        session: PlaySession? = nil,
        match: Match? = nil,
        presetDiscipline: Discipline? = nil,
        embedded: Bool = false,
        onSaved: (() -> Void)? = nil
    ) {
        self.editing = session
        self.editingMatch = match
        self.presetDiscipline = presetDiscipline
        self.embedded = embedded
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            if embedded {
                formContent
            } else {
                NavigationStack { formContent }
            }
        }
    }

    private var formContent: some View {
        Form {
            Section("Court time") {
                DatePicker("Date", selection: $day, in: ...Date.now, displayedComponents: .date)
                HStack {
                    Text("Start time")
                    Spacer()
                    Text(AppFormat.time(startTime))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                StartTimePicker(time: $startTime)
                Picker("Duration on Court", selection: $hours) {
                    ForEach(1...8, id: \.self) { value in
                        Text("\(value) hour\(value == 1 ? "" : "s")").tag(value)
                    }
                }
            }

            Section("Game Record") {
                if discipline != .singles {
                    Picker("Discipline", selection: $discipline) {
                        ForEach(Discipline.allCases) { Text($0.label).tag($0) }
                    }
                }
                Picker("Intensity", selection: $intensity) {
                    Text("Not set").tag(Intensity?.none)
                    ForEach(Intensity.allCases) { Text($0.label).tag(Intensity?.some($0)) }
                }
                Picker("Point system", selection: $pointSystem) {
                    // Continuous is a stored, legitimate point system; let it be
                    // selected and edited instead of silently rewriting scores.
                    ForEach(PointSystem.allCases) { Text($0.label).tag($0) }
                }
                Picker("Format", selection: Binding(
                    get: { format },
                    set: { newValue in
                        // Only a genuine user choice resets the game count.
                        // Population assigns `format` directly, so it never goes
                        // through this binding and cannot drop games 2–N.
                        guard newValue != format else { return }
                        format = newValue
                        setFormat(newValue)
                    }
                )) {
                    Text("Best of 3").tag(MatchFormat.bestOf3)
                    Text("Continuous games").tag(MatchFormat.singleGame)
                }
                if discipline.usesPartner {
                    if savedPlayers.isEmpty {
                        TextField("Partner", text: $partner)
                            .textInputAutocapitalization(.words)
                    } else {
                        Picker("Partner", selection: $partner) {
                            Text("Choose a player").tag("")
                            ForEach(savedPlayers) { Text($0.name).tag($0.name) }
                        }
                    }
                }

                opponentPickers
            }

            Section("Score") {
                scoreRow("You", myScores)
                scoreRow("Opponent", opponentScores)
                Button { showScoreEditor = true } label: {
                    Label("Edit score", systemImage: "square.and.pencil")
                }
            }

            Section("Notes") {
                TextField("Anything worth remembering?", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(editing == nil && editingMatch == nil ? "Court time" : "Edit session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
            }
        }
        .sheet(isPresented: $showScoreEditor) {
            ScoreEditorView(
                gameCount: $gameCount,
                myScores: $myScores,
                opponentScores: $opponentScores,
                isContinuous: format == .singleGame,
                pointRange: scorePointRange,
                pointSystem: pointSystem,
                format: format
            )
        }
        .alert("Missing information", isPresented: $showValidation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationText)
        }
        .onAppear(perform: populate)
    }

    // MARK: - Helpers

    /// Singles takes one opponent; doubles takes exactly two.
    private var opponentCount: Int { discipline.usesPartner ? 2 : 1 }

    private var opponentNames: [String] {
        var result = [opponentOne.trimmingCharacters(in: .whitespacesAndNewlines)]
        if discipline.usesPartner {
            result.append(opponentTwo.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }

    private var opponentPickers: some View {
        Group {
            if savedPlayers.isEmpty {
                TextField(opponentCount == 1 ? "Opponent name" : "First opponent", text: $opponentOne)
                    .textInputAutocapitalization(.words)
                if opponentCount == 2 {
                    TextField("Second opponent", text: $opponentTwo)
                        .textInputAutocapitalization(.words)
                }
            } else {
                Picker(opponentCount == 1 ? "Opponent" : "First opponent", selection: $opponentOne) {
                    Text("Choose a player").tag("")
                    ForEach(savedPlayers) { Text($0.name).tag($0.name) }
                }
                if opponentCount == 2 {
                    Picker("Second opponent", selection: $opponentTwo) {
                        Text("Choose a player").tag("")
                        ForEach(savedPlayers.filter { $0.name != opponentOne }) {
                            Text($0.name).tag($0.name)
                        }
                    }
                }
            }
        }
    }

    /// One string for the linked Match. Doubles keeps both names.
    private var opponentName: String {
        opponentNames.filter { !$0.isEmpty }.joined(separator: " & ")
    }

    private var sessionDate: Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
        let timeParts = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        parts.hour = timeParts.hour
        parts.minute = timeParts.minute
        return Calendar.current.date(from: parts) ?? day
    }

    /// Continuous play has no cap, so its wheels go up to a generous ceiling.
    private var scorePointRange: ClosedRange<Int> {
        pointSystem == .continuous ? 0...999 : 0...(pointSystem.capPoints ?? 30)
    }

    /// "Alice & Bob" and ["Bob", "Alice"] describe the same doubles opponents.
    private static func normalizedNames(_ values: [String]) -> Set<String> {
        Set(
            values
                .flatMap { $0.components(separatedBy: " & ") }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    /// Same rules as SessionsView.linkedMatch(for:): no tournament match, same
    /// day, same set of opponent names. An exact timestamp wins if there are
    /// several candidates; otherwise the newest match on that day is used.
    private func resolveLinkedMatch(date: Date, opponents: [String]) -> Match? {
        let names = Self.normalizedNames(opponents)
        guard !names.isEmpty else { return nil }
        let calendar = Calendar.current
        let candidates = matches.filter { match in
            guard match.tournament == nil,
                  calendar.isDate(match.date, inSameDayAs: date) else { return false }
            return Self.normalizedNames([match.opponent]) == names
        }
        return candidates.first { $0.date == date } ?? candidates.first
    }

    private var missingInformation: [String] {
        var problems: [String] = []
        let picked = opponentNames.filter { !$0.isEmpty }
        if picked.count < opponentCount {
            problems.append(opponentCount == 1 ? "Pick an opponent." : "Pick two opponents.")
        }
        if discipline.usesPartner && partner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("Pick a partner.")
        }
        if sessionDate > Date.now {
            problems.append("Date can't be in the future.")
        }
        if let issue = MatchLogic.validationMessage(
            myGameScores: myScores,
            opponentGameScores: opponentScores,
            format: format,
            pointSystem: pointSystem,
            gameCount: gameCount
        ) {
            problems.append(issue)
        }
        return problems
    }

    /// Fixed-width cells keep the You and Opponent rows lined up per game.
    private func scoreRow(_ label: String, _ values: [Int]) -> some View {
        let shown = min(gameCount, 5)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .frame(width: 72, alignment: .leading)
            ForEach(0..<shown, id: \.self) { index in
                Text(scoreCell(values, index))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 34, alignment: .center)
            }
            if gameCount > shown {
                Text("+\(gameCount - shown)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func scoreCell(_ values: [Int], _ index: Int) -> String {
        guard index < values.count, values[index] > 0 else { return "-" }
        return "\(values[index])"
    }

    private func padded(_ values: [Int]) -> [Int] {
        let target = max(3, gameCount)
        var result = Array(values.prefix(target))
        while result.count < target { result.append(0) }
        return result
    }

    private func setFormat(_ newValue: MatchFormat) {
        gameCount = newValue == .bestOf3 ? 3 : 1
        let target = max(3, gameCount)
        while myScores.count < target { myScores.append(0) }
        while opponentScores.count < target { opponentScores.append(0) }
    }

    private func populate() {
        guard !didPopulate else { return }
        didPopulate = true

        if let editing {
            day = editing.date
            startTime = editing.date
            hours = max(1, editing.durationMinutes / 60)
            discipline = editing.discipline
            intensity = editing.intensity
            opponentOne = editing.opponents.first ?? ""
            opponentTwo = editing.opponents.count > 1 ? editing.opponents[1] : ""
            notes = editing.notes ?? ""
            linkedMatchState = editingMatch
                ?? resolveLinkedMatch(date: editing.date, opponents: editing.opponents)
            if let match = linkedMatchState { applyMatch(match) }
            return
        }

        if let match = editingMatch {
            linkedMatchState = match
            populate(from: match)
            return
        }

        if let presetDiscipline { discipline = presetDiscipline }
    }

    /// Fill the form from a match that was logged without a PlaySession.
    private func populate(from match: Match) {
        day = match.date
        startTime = match.date
        hours = 1
        discipline = match.discipline
        intensity = match.intensity
        let names = match.opponent
            .components(separatedBy: " & ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        opponentOne = names.first ?? ""
        opponentTwo = names.count > 1 ? names[1] : ""
        notes = match.notes ?? ""
        applyMatch(match)
    }

    private func applyMatch(_ match: Match) {
        // Continuous is a real stored point system with no cap; coercing it to
        // 21-point rules would invalidate scores like 57–41 on save.
        pointSystem = match.pointSystem
        format = match.format
        gameCount = match.gameCount
        myScores = padded(match.myGameScores)
        opponentScores = padded(match.opponentGameScores)
        partner = match.partner
    }

    private func makeMatch(when: Date, notes: String?) -> Match {
        Match(
            date: when,
            opponent: opponentName,
            partner: discipline.usesPartner ? partner.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            discipline: discipline,
            pointSystem: pointSystem,
            format: format,
            myGameScores: Array(myScores.prefix(gameCount)),
            opponentGameScores: Array(opponentScores.prefix(gameCount)),
            notes: notes,
            intensity: intensity
        )
    }

    private func applyScores(to match: Match) {
        match.pointSystem = pointSystem
        match.format = format
        match.myGameScores = Array(myScores.prefix(gameCount))
        match.opponentGameScores = Array(opponentScores.prefix(gameCount))
    }

    private func save() {
        guard !isSaving else { return }
        let problems = missingInformation
        guard problems.isEmpty else {
            validationText = problems.joined(separator: "\n")
            showValidation = true
            return
        }
        isSaving = true

        let when = sessionDate
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes = cleanNotes.isEmpty ? nil : cleanNotes
        let people = opponentNames.filter { !$0.isEmpty }

        if let editing {
            editing.date = when
            editing.durationMinutes = hours * 60
            editing.discipline = discipline
            editing.intensity = intensity
            editing.opponents = people
            editing.notes = finalNotes
        } else if editingMatch == nil {
            context.insert(PlaySession(
                date: when,
                durationMinutes: hours * 60,
                discipline: discipline,
                intensity: intensity,
                opponents: people,
                notes: finalNotes
            ))
        }

        if let match = linkedMatchState {
            match.date = when
            match.opponent = opponentName
            match.partner = discipline.usesPartner ? partner.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            match.discipline = discipline
            match.notes = finalNotes
            match.intensity = intensity
            applyScores(to: match)
        } else {
            context.insert(makeMatch(when: when, notes: finalNotes))
        }

        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}

// MARK: - Score editor

private struct ScoreEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var gameCount: Int
    @Binding var myScores: [Int]
    @Binding var opponentScores: [Int]
    let isContinuous: Bool
    let pointRange: ClosedRange<Int>
    let pointSystem: PointSystem
    let format: MatchFormat

    @State private var showValidation = false
    @State private var validationText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Score") {
                    ForEach(0..<gameCount, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Game \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                pointsColumn("You", selection: Binding(
                                    get: { myScores[index] },
                                    set: { myScores[index] = $0 }
                                ))
                                pointsColumn("Opponent", selection: Binding(
                                    get: { opponentScores[index] },
                                    set: { opponentScores[index] = $0 }
                                ))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if isContinuous {
                        HStack {
                            Button { removeGame() } label: {
                                Label("Remove game", systemImage: "minus.circle")
                            }
                            .disabled(gameCount <= 1)
                            Spacer()
                            Button { addGame() } label: {
                                Label("Add game", systemImage: "plus.circle")
                            }
                            .disabled(gameCount >= 20)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Check the score", isPresented: $showValidation) {
                Button("Fix score", role: .cancel) {}
            } message: {
                Text(validationText)
            }
        }
    }

    /// Done is the gate: no impossible score (30–12, 21–12, 25–15…) gets out
    /// of the editor, in either format, and the alert says exactly why.
    private func finish() {
        if let message = MatchLogic.validationMessage(
            myGameScores: Array(myScores.prefix(gameCount)),
            opponentGameScores: Array(opponentScores.prefix(gameCount)),
            format: format,
            pointSystem: pointSystem,
            gameCount: gameCount
        ) {
            validationText = message
            showValidation = true
            return
        }
        dismiss()
    }

    private func pointsColumn(_ label: String, selection: Binding<Int>) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Picker(label, selection: selection) {
                ForEach(pointRange, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 100)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    private func addGame() {
        guard gameCount < 20 else { return }
        gameCount += 1
        myScores.append(0)
        opponentScores.append(0)
    }

    private func removeGame() {
        guard gameCount > 1 else { return }
        gameCount -= 1
        if myScores.count > gameCount { myScores.removeLast() }
        if opponentScores.count > gameCount { opponentScores.removeLast() }
    }
}

#Preview {
    PlayFormView()
        .modelContainer(PreviewContainer.container)
}
