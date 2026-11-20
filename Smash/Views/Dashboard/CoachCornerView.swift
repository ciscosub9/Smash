import SwiftUI

/// A swipeable stack of one-card suggestions. The dots are always visible so
/// it's obvious there's more than one note — each card carries a single idea,
/// its evidence, and one concrete action.
struct CoachCornerView: View {
    let insights: [CoachInsight]

    @State private var selection = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The incoming deck can shrink between renders; never address past its end.
    private var safeSelection: Int {
        guard !insights.isEmpty else { return 0 }
        return min(max(selection, 0), insights.count - 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            if insights.isEmpty {
                Text("No coaching notes yet. Log a few matches to get a read.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            } else {
                HStack {
                    Label("Coach's Corner", systemImage: "lightbulb.fill")
                        .font(.headline)
                    Spacer()
                    Text("\(safeSelection + 1) of \(insights.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                TabView(selection: Binding<Int>(
                    get: { safeSelection },
                    set: { selection = $0 }
                )) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        CoachInsightCard(insight: insight)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 196)
                .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selection)
                .sensoryFeedback(.selection, trigger: selection)

                HStack(spacing: 6) {
                    ForEach(insights.indices, id: \.self) { index in
                        Circle()
                            .fill(index == safeSelection
                                  ? Color.accentColor
                                  : Color.secondary.opacity(0.25))
                            .frame(width: index == safeSelection ? 7 : 6,
                                   height: index == safeSelection ? 7 : 6)
                            .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: selection)
                    }
                }
                .frame(height: 8)
                .accessibilityLabel("Suggestion \(safeSelection + 1) of \(insights.count)")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SmashRadius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .onChange(of: insights.count) { _, count in
            if selection >= count { selection = max(0, count - 1) }
        }
    }
}

private struct CoachInsightCard: View {
    let insight: CoachInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: insight.symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: SmashRadius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Label(insight.confidence.label, systemImage: "checkmark.seal")
                        .font(.caption2)
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
            }

            Text(insight.observation)
                .font(.footnote)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(insight.evidence)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            Label(insight.action, systemImage: "arrow.right.circle")
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.observation) \(insight.evidence) Try: \(insight.action)")
    }

    /// Tone mapping is preserved, but the foreground uses the shared
    /// high-contrast text tokens so small labels stay readable in light mode.
    private var tint: Color {
        switch insight.tone {
        case .form: SmashColor.training
        case .context: SmashColor.infoText
        case .clutch: SmashColor.warningText
        case .opponent: SmashColor.lossText
        case .partner: SmashColor.partnerText
        }
    }
}
