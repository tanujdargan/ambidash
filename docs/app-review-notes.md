# App Store Review Notes

## Demo Account
This app does not require login. All features are available without authentication.

## AI Features
AI-powered features (insights, plan generation, honest mirror) require an Anthropic API key configured in Settings > AI Configuration. Without a key, the app uses template-based plan generation and shows a prompt to configure the key.

To test AI features during review, use the Anthropic API key: [REDACTED — provide to Apple in App Review Notes field]

## In-App Purchases
Monthly ($9.99) and Yearly ($79.99) subscriptions unlock unlimited AI features. Free tier provides 1 AI plan and 1 AI insight per day.

## Health Data
The app reads health data (sleep, steps, workouts, heart rate) to power the self-awareness dashboard. No health data is written, modified, or transmitted off-device.

## Privacy
All user data is stored on-device via SwiftData. Health data never leaves the device. AI context is assembled as an anonymized summary on-device before being sent to the AI API.

## Account Deletion
Users can delete all data via Settings > Delete All Data. This permanently removes all goals, assessments, plans, reflections, preferences, and API keys.
