import SwiftUI

/// First-run setup. The player card is created before any stats exist, so
/// everything on the Dashboard feels like it belongs to them. No gallery
/// access, no account, no permissions — the avatars ship with the app.
struct OnboardingView: View {
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @AppStorage(PlayerProfile.skillKey) private var playerSkillRaw = ""
    @AppStorage(PlayerProfile.avatarKey) private var playerAvatar = PlayerProfile.defaultAvatar
    @AppStorage(PlayerProfile.avatarColorKey) private var playerAvatarColor = PlayerProfile.defaultAvatarColor
    @AppStorage(PlayerGoal.kindKey) private var goalKindRaw = GoalKind.weekly.rawValue
    @AppStorage(PlayerGoal.targetKey) private var goalTarget = 3

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    avatarCard
                    detailsCard
                    goalCard
                    Text("Your data stays on this device. No account, no tracking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Welcome to Smash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { finish() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: finish) {
                        Text("Get started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                }
                .background(.bar)
            }
        }
    }

    private func finish() {
        PlayerProfile.onboardingCompleted = true
        dismiss()
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 8) {
            Text("Your court, your numbers.")
                .font(.title2.weight(.bold))
            Text("Start with your name, your level and an icon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var avatarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Pick your avatar", systemImage: "person.crop.circle")
                .font(.headline)

            AvatarPicker(avatar: $playerAvatar, color: $playerAvatarColor)
        }
        .cardStyle()
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Player details", systemImage: "person.crop.circle")
                .font(.headline)

            TextField("Your Name", text: $playerName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Picker("Skill level", selection: $playerSkillRaw) {
                Text("Not set").tag("")
                ForEach(SkillLevel.allCases) { level in
                    Text(level.label).tag(level.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .cardStyle()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Goal", systemImage: "target")
                .font(.headline)

            GoalControls(kindRaw: $goalKindRaw, target: $goalTarget)

            Text("Your goal counts court time and training sessions. The Dashboard keeps your streak.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

#Preview {
    OnboardingView()
}
