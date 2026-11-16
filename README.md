<div align="center">

# 🏸 Smash

**Free, open-source badminton tracking for iPhone.**

Track daily play, coaching sessions, matches with full scoring, and tournaments — with a native Apple design language.

[![Platform](https://img.shields.io/badge/platform-iOS%2018+-black)](#)
[![Swift](https://img.shields.io/badge/swift-6-orange)](#)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

## Features

- **Play** — log daily sessions with duration, discipline (singles / doubles / mixed), intensity, court, and who you played with.
- **Training** — record coaching and drill sessions: what you worked on (footwork, smashes, net play…), with whom, and notes on what to repeat.
- **Matches** — full score tracking with three point systems (15-point, 21-point rally, continuous) in single-game or best-of-3 format. Win rate is computed automatically per opponent and per scoring system.
- **Tournaments** — round robin, knockout, league, and ladder formats. Link matches to a tournament, track wins/losses and placement, and keep strategy notes.
- **Dashboard** — weekly on-court time, day streaks, win rate, and recent results at a glance (Swift Charts).
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

- [ ] App icon & App Store assets
- [ ] Export data (CSV / JSON)
- [ ] Per-opponent history drill-down
- [ ] Apple Watch companion
- [ ] Widgets & App Intents shortcuts

## Contributing

Issues and pull requests welcome — this project exists to be forked, improved, and played with. For large changes, open an issue first to discuss.

## License

[MIT](LICENSE) — free to use, modify, and ship, including on the App Store.
