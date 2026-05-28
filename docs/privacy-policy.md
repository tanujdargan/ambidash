# AmbiDash Privacy Policy

**Last updated:** May 28, 2026

## What We Collect

AmbiDash collects only what's needed to help you track your goals:

- **Account info**: Name, age (provided during onboarding)
- **Goals and plans**: Goal titles, subtitles, horizons, progress data
- **Reflections**: Daily mood, blockers, freeform notes
- **Health data** (opt-in): Sleep, steps, workouts, heart rate via Apple Health
- **Calendar data** (opt-in): Event times for free-time computation
- **Usage patterns**: Plan completion rates, streak data

## How We Use It

- Generate your daily action plans and mentor insights
- Track progress across your life pillars
- Show trends in your weekly and monthly reviews
- Improve AI mentor accuracy over time

## Where Data Lives

- **On your device**: All data is stored locally via SwiftData. The app works fully offline.
- **Cloud sync** (opt-in): When you sign in with Apple, data syncs to Supabase (hosted on AWS). This enables multi-device access.
- **AI processing**: When you use AI features, an anonymized context summary (goal names, health stats — not raw data) is sent to Anthropic's Claude API via our server-side edge function. Anthropic does not retain this data.

## What We Don't Do

- We don't sell your data
- We don't track you across apps
- We don't share data with advertisers
- We don't store raw health records on our servers
- We don't use your data for model training

## Data Retention

- Local data persists until you delete it via Settings > Delete All Data
- Cloud data is deleted when you delete your account
- AI context summaries are not stored after the response is generated

## Your Rights

- **Export**: Settings > Export My Data (JSON format)
- **Delete**: Settings > Delete All Data (irreversible)
- **Opt out of sync**: Use the app without signing in — fully functional offline

## Contact

privacy@ambidash.app
