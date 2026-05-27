# AmbiDash

A quiet instrument for an ambitious life.

## What it is

AmbiDash is a native iOS life dashboard for ambitious people who juggle too many goals. It doesn't gamify your habits or nag you with streaks. It watches quietly, asks better questions than you'd ask yourself, and remembers what you said you cared about — when you forget.

## Architecture

- **SwiftUI** + **SwiftData** + **CloudKit** — pure Apple stack
- **Claude API** — AI mentor for insights, plan generation, honest mirror
- **WidgetKit** — home screen vitals widget
- **App Intents** — Siri shortcuts
- **HealthKit** + **EventKit** — passive data integration
- **StoreKit 2** — freemium subscription

## Setup

```bash
# Requires: Xcode 16+, iOS 17+, xcodegen
brew install xcodegen  # if not installed
xcodegen generate
open ambidash.xcodeproj
# Set your team in Signing & Capabilities, then Cmd+R
```

## Project Structure

```
ambidash/
├── App/             — Entry point, root routing, tab bar
├── Models/          — 12 SwiftData @Model classes
├── Services/        — 23 service modules (AI, health, events, etc.)
├── Views/           — 29 view files across 8 sections
├── Theme/           — Design system, components, animations
├── Utilities/       — Enums, helpers, deep links
├── Intents/         — Siri shortcut definitions
└── Assets.xcassets/ — Colors, app icon
```

## Design

Editorial instrument aesthetic — serif for reflection, monospace for data, sans for UI. Four palettes (Yellow, Cool, Forest, Rose) × dark/light × three typography styles × two density modes.

## Testing

```bash
# Unit tests (36)
xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:ambidashTests

# UI tests (5)
xcodebuild test -scheme ambidash -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:ambidashUITests
```

## License

Private — not open source.
