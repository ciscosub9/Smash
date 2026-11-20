import SwiftUI

/// A short, one-time orientation after the player card is set up. It can be
/// replayed any time from Settings → Personalization.
struct AppTourView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 56

    private struct Page: Identifiable {
        let symbol: String
        let title: String
        let message: String
        let tint: Color
        var id: String { title }
    }

    private let pages: [Page] = [
        Page(symbol: "square.grid.2x2", title: "Your dashboard",
             message: "Court time, streaks, win rate and goal progress sit on one screen. Your avatar is in the top-left, with your profile and settings behind it.",
             tint: SmashColor.winText),
        Page(symbol: "figure.play", title: "Sessions",
             message: "Tap the plus button to log Singles, Doubles or Training. The score goes in the same form as your court time. Everything lands in one Sessions list, newest first.",
             tint: SmashColor.infoText),
        Page(symbol: "person.2", title: "Players",
             message: "Save the people you play with and their levels. Pick them when you log a match, as an opponent or a partner.",
             tint: SmashColor.infoText),
        Page(symbol: "medal", title: "Tournaments",
             message: "Group matches under an event, note your placement, and keep the tactics that worked for next time.",
             tint: SmashColor.warningText),
        Page(symbol: "person.crop.circle", title: "Make it yours",
             message: "Settings lives in your profile. Pick light, dark, or system appearance, a 12- or 24-hour clock, and how often your goal resets.",
             tint: SmashColor.infoText),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: page)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 8, height: 8)
                            .animation(reduceMotion ? nil : .smooth, value: page)
                            .accessibilityElement()
                            .accessibilityLabel("Page \(index + 1) of \(pages.count)")
                            .accessibilityAddTraits(index == page ? [.isSelected] : [])
                    }
                }

                Button {
                    if page < pages.count - 1 {
                        page += 1
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Next" : "Start using Smash")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .sensoryFeedback(.selection, trigger: page)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("App tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { finish() }
                }
            }
            .interactiveDismissDisabled()
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 18) {
            Image(systemName: page.symbol)
                .font(.system(size: iconSize))
                // Flat, darkened semantic tint — hierarchical rendering over
                // a translucent fill loses contrast in light mode.
                .foregroundStyle(page.tint)
                .frame(width: 110, height: 110)
                .background(
                    page.tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title.weight(.bold))
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func finish() {
        PlayerProfile.appTourCompleted = true
        dismiss()
    }
}

#Preview {
    AppTourView()
}
