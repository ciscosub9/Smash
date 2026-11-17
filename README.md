<div align="center">

<img src="Docs/app-icon-rounded.png" width="180" alt="Smash app icon" />

# Smash

**Free, open-source badminton tracking for iPhone.**

Track daily play, coaching sessions, matches with full scoring, and tournaments — with a native Apple design language.

[![Platform](https://img.shields.io/badge/platform-iOS%2018+-black)](#)
[![Swift](https://img.shields.io/badge/swift-6-orange)](#)
[![License: GPL v3](https://img.shields.io/badge/license-GPL--v3-blue)](LICENSE)

</div>

## Features

- **Play** — log daily sessions with duration, discipline (singles / doubles / mixed), intensity, court, and who you played with.
- **Training** — record coaching and drill sessions: pick the drill (presets or custom), sets completed, difficulty, focus areas, coach, and notes on what to repeat.
- **Matches** — full score tracking with three point systems (15-point, 21-point rally, continuous) in single-game or best-of-3 format. Tag each match with intensity and opponent level (Beginner → Professional); win rate is computed automatically.
- **Tournaments** — round robin, knockout, league, and ladder formats. Link matches to a tournament, track wins/losses and placement, and keep strategy notes.
- **Dashboard** — weekly on-court time, streaks, win rate, and recent results at a glance (Swift Charts). One-tap light/dark switch up top.
- **Appearance** — Automatic (follows system), Light, or Dark — quick switch on the Dashboard, full control in Settings.
- **Backup & import** — export all data as JSON from Settings, optionally encrypted with a password (PBKDF2 + AES-256-GCM). Import merges records back without overwriting anything.
- **Player profile** — your name and skill level, kept alongside the same Beginner → Professional scale used for opponents.
- **Activity goals** — set a weekly or monthly target ("5 sessions a week") in your profile; the Dashboard tracks progress live and celebrates when you hit it.
- **Your data, your choice** — store everything locally on device (default, private) or flip on iCloud sync in Settings. No accounts, no analytics, no tracking.

## Design

Smash follows Apple's Human Interface Guidelines and the [apple-design principles](https://github.com/emilkowalski/skills) distilled from Apple's WWDC design talks: spring-based interruptible motion, instant press feedback, materials over hard borders, system typography with Dynamic Type, and haptics that land on the same frame as the visual change.

## Building

Requirements: Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/ciscosub9/Smash.git
cd Smash
xcodegen generate   # creates Smash.xcodeproj from project.yml
open Smash.xcodeproj
```

Then select the **Smash** scheme and run on an iPhone simulator (⌘R).

Run tests with **⌘U** (Swift Testing).

### iCloud sync

iCloud sync uses CloudKit and requires the iCloud capability with your own development team:

1. Open the generated project → **Smash target → Signing & Capabilities**.
2. Add your team; the iCloud container `iCloud.com.smashapp.smash` is already declared.
3. In-app, switch **Settings → Storage → iCloud**.

Without the capability, the app gracefully stays on local storage.

## Architecture

```
Smash/
├── Models/       SwiftData models: PlaySession, TrainingSession, Match, Tournament
├── Services/     SmashStore (container + sync mode), Stats (pure aggregation logic)
├── Views/        One folder per tab: Dashboard, Play, Matches, Training, Tournaments, Settings
├── Design/       Shared components: press styles, stat cards, empty states
└── Tests/        Swift Testing suites for scoring and stats logic
```

- **Swift 6** with main-actor-by-default and approachable concurrency.
- **SwiftData** for persistence; scoring and stats logic is pure and unit-tested, independent of the database.
- No third-party dependencies.

## Roadmap

- [x] App icon
- [ ] App Store listing assets
- [x] Export data (JSON, optional password encryption) · import merges back
- [ ] Per-opponent history drill-down
- [ ] Apple Watch companion
- [ ] Widgets & App Intents shortcuts

## Contributing

Issues and pull requests welcome — this project exists to be forked, improved, and played with. For large changes, open an issue first to discuss. Note that all contributions land under GPL-3.0.

## License

Smash is [free software](https://www.gnu.org/philosophy/free-sw.en.html), licensed under the [GNU General Public License v3.0](LICENSE).

- **Use, study, modify, share** — anyone may do all of these.
- **Copyleft** — any fork or derivative, including commercial or App Store distributions, must be released under GPL-3.0 with its full source code. Closed-source clones of this code are not permitted.
- **Attribution appreciated** — if you build on Smash, a credit and a link back to this repository are welcome.
- **A note on the App Store** — the GPL is widely considered incompatible with Apple's App Store distribution terms (Apple's DRM and remote-review requirements don't fit the GPL's rules). As the copyright holder, I may still distribute my own builds on the App Store — the license doesn't bind the copyright owner. Anyone else doing so must comply with the GPL.
