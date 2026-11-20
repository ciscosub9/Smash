import SwiftUI

/// A black badge with an icon tinted the colour the player picked. The badge
/// never changes colour; only the artwork does. Both values are stored as
/// strings so backups carry them without changes.
struct AvatarView: View {
    let name: String
    let color: String

    var body: some View {
        Circle()
            .fill(Color(red: 0.09, green: 0.09, blue: 0.10))
            .overlay {
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
                    .foregroundStyle(Color(hex: color))
            }
    }
}

/// The Dashboard's profile button. It keeps the regular app-avatar size and
/// dark circular badge, but shows the avatar the player actually picked —
/// tinted in their chosen colour — with a matching coloured border.
struct ToolbarAvatarView: View {
    let name: String
    let color: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.25, blue: 0.28),
                            Color(red: 0.10, green: 0.10, blue: 0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(Color(hex: color))
        }
        .frame(width: 34, height: 34)
        .overlay {
            Circle()
                .strokeBorder(Color(hex: color), lineWidth: 1.5)
        }
        .shadow(color: Color(hex: color).opacity(0.35), radius: 4, y: 1)
        .accessibilityHidden(true)
    }
}

extension Color {
    /// Builds a SwiftUI colour from a stored `#RRGGBB` string.
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard raw.count == 6,
              let value = Int(raw, radix: 16) else {
            self = .white
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
