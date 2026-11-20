import Foundation

/// External links shown in the app.
nonisolated enum AppLinks {
    /// The public repository (linked from Settings).
    static let sourceCode = URL(string: "https://github.com/ciscosub9/Smash")!

    // MARK: Policies
    //
    // Hosted in the public GitHub repo so the same URLs work in the App Store
    // privacy fields and in the app. The repo must be public for these to load.
    private static let docsBase = "https://github.com/ciscosub9/Smash/blob/main/Docs/"
    static let privacyPolicy = URL(string: "\(docsBase)PRIVACY.md")!
    static let terms = URL(string: "\(docsBase)TERMS.md")!
    static let usage = URL(string: "\(docsBase)USAGE.md")!

    /// The MIT license text, linked from Profile → Policies.
    static let license = URL(string: "https://github.com/ciscosub9/Smash/blob/main/LICENSE")!
}
