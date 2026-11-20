import SwiftUI
import SwiftData
import StoreKit

/// The player card reached from the avatar on the Dashboard. Form rating sits
/// at the top, then the profile, Settings, and the policy and support links.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @AppStorage(PlayerProfile.skillKey) private var playerSkillRaw = ""
    @AppStorage(PlayerProfile.avatarKey) private var playerAvatar = PlayerProfile.defaultAvatar
    @AppStorage(PlayerProfile.avatarColorKey) private var playerAvatarColor = PlayerProfile.defaultAvatarColor
    @AppStorage(PlayerGoal.kindKey) private var goalKindRaw = GoalKind.weekly.rawValue
    @AppStorage(PlayerGoal.targetKey) private var goalTarget = 3
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    var body: some View {
        let rating = formRating

        NavigationStack {
            Form {
                Section {
                    scoreHighlight(rating)
                        .listRowBackground(Color.accentColor.opacity(0.10))
                } header: {
                    Text("Form rating")
                } footer: {
                    Text("Wins push it up, losses pull it down. Beating a stronger player moves it more than beating a beginner. Everyone starts at 1400.")
                }

                Section {
                    avatarPicker
                    TextField("Your Name", text: $playerName)
                        .textInputAutocapitalization(.words)
                    Picker("Skill level", selection: $playerSkillRaw) {
                        Text("Not set").tag("")
                        ForEach(SkillLevel.allCases) { level in
                            Text(level.label).tag(level.rawValue)
                        }
                    }
                    GoalControls(kindRaw: $goalKindRaw, target: $goalTarget)
                    Text("Your goal counts court time and training sessions. The Dashboard keeps your streak.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Profile")
                }

                Section {
                    NavigationLink {
                        SettingsView(embedded: true)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                Section {
                    Link(destination: AppLinks.privacyPolicy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.terms) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    Link(destination: AppLinks.usage) {
                        Label("Usage Guide", systemImage: "book")
                    }
                    Link(destination: AppLinks.license) {
                        Label("License (GPL-3.0)", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("Policies")
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        Label("Write an app review", systemImage: "star.bubble")
                    }
                } header: {
                    Text("Support Smash")
                } footer: {
                    Text("Smash is free and open-source. A review keeps it going — no ads, ever.")
                }

                Section {
                    aboutFooter
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var formRating: FormRating {
        CoachInsights.rating(matches: matches)
    }

    private func scoreHighlight(_ rating: FormRating) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(rating.current)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 2) {
                Text("Form rating")
                    .font(.subheadline.weight(.medium))
                Text(rating.matchesRated == 0
                     ? "Not rated yet"
                     : "\(rating.trendLabel) over the last 30 days")
                    .font(.caption)
                    .foregroundStyle(rating.matchesRated == 0
                        ? Color.secondary
                        : (rating.trend >= 0 ? SmashColor.winText : SmashColor.lossText))
            }
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("Developed with love")
            Text("by Cisco")
                .fontWeight(.medium)

            Spacer()
                .frame(height: 8)
                .accessibilityHidden(true)

            Text("Version \(appVersion)")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var avatarPicker: some View {
        AvatarPicker(avatar: $playerAvatar, color: $playerAvatarColor, compact: true)
            .padding(.vertical, 4)
    }
}

#Preview {
    ProfileView()
        .modelContainer(PreviewContainer.container)
}
