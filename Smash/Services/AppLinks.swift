import Foundation

/// External links shown in the app.
///
/// ⚠️ Update these before shipping:
/// - `buyMeACoffee`: create a page at buymeacoffee.com and paste your URL.
/// - `feedbackEmail`: any inbox you check.
nonisolated enum AppLinks {
    /// "Buy me a coffee" support page.
    static let buyMeACoffee = URL(string: "https://www.buymeacoffee.com/ciscosub9")!

    /// Pre-filled feedback email.
    static var feedback: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Smash app feedback")]
        return components.url ?? buyMeACoffee
    }

    static let feedbackEmail = "ciscosub9@users.noreply.github.com"

    /// The public repository (linked from Settings).
    static let sourceCode = URL(string: "https://github.com/ciscosub9/Smash")!
}
