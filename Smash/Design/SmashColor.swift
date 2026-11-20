import SwiftUI
import UIKit

/// Shared semantic colours.
///
/// The brand accent (`#34C759` light / `#30D158` dark) stays bright for fills
/// such as buttons and badges. The `*Text` variants are darkened in light mode
/// so small labels on white or tinted capsules meet WCAG AA contrast. Use the
/// `Text` variants for foreground text and the brand accent for fills.
enum SmashColor {
    static let winText = dynamic(
        light: (0x1B, 0x7F, 0x3B), // #1B7F3B — 5.3:1 on white
        dark: (0x30, 0xD1, 0x58)   // #30D158
    )
    static let lossText = dynamic(
        light: (0xC0, 0x27, 0x1E), // #C0271E — 5.7:1 on white
        dark: (0xFF, 0x45, 0x3A)
    )
    static let warningText = dynamic(
        light: (0xB2, 0x5E, 0x00), // #B25E00 — 5.0:1 on white
        dark: (0xFF, 0x9F, 0x0A)
    )
    static let infoText = dynamic(
        light: (0x00, 0x56, 0xCC), // #0056CC — 6.3:1 on white
        dark: (0x0A, 0x84, 0xFF)
    )

    /// Training is consistently blue everywhere (chart, chips, form, logger tile).
    static let training = infoText

    private static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(rgb.0) / 255,
                           green: CGFloat(rgb.1) / 255,
                           blue: CGFloat(rgb.2) / 255,
                           alpha: 1)
        })
    }
}

/// One corner-radius system. All call sites should use `.continuous` corners.
enum SmashRadius {
    static let card: CGFloat = 16
    static let tile: CGFloat = 14
    static let chip: CGFloat = 12
}
