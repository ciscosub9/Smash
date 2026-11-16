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

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 14))
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
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    private var label: String {
        switch outcome {
        case .win: "Win"
        case .loss: "Loss"
        case .draw: "Draw"
        }
    }

    private var tint: Color {
        switch outcome {
        case .win: .green
        case .loss: .red
        case .draw: .orange
        }
    }
}

// MARK: - List row backgrounds

/// A grouped-list card look: rounded, subtle fill, no separator needed.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}
