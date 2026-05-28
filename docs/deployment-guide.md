# AmbiDash Deployment Guide

## Prerequisites

- Xcode 16+ with iOS 17+ SDK
- Apple Developer Program membership
- Supabase account (supabase.com)
- Anthropic API key (console.anthropic.com)
- xcodegen (`brew install xcodegen`)

## 1. Supabase Cloud Setup

```bash
# Link to your Supabase project
supabase link --project-ref <your-project-ref>

# Deploy database schema (7 tables with RLS)
supabase db push

# Deploy AI edge function
supabase functions deploy ai-mentor

# Set the Anthropic API key as a secret
supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-...
```

### Enable Sign in with Apple

1. In Supabase Dashboard → Authentication → Providers → Apple
2. Enable Apple provider
3. Add your Apple Services ID and private key
4. Set callback URL to: `https://<project-ref>.supabase.co/auth/v1/callback`

### Configure Apple Developer Portal

1. Certificates, Identifiers & Profiles → Identifiers
2. Create a Services ID for Sign in with Apple
3. Configure the domain and return URL from Supabase
4. Create a key for Sign in with Apple

## 2. iOS App Configuration

### Signing & Capabilities

1. Open `ambidash.xcodeproj` in Xcode
2. Select the `ambidash` target → Signing & Capabilities
3. Set your Team
4. Verify these capabilities are enabled:
   - Sign in with Apple
   - HealthKit
   - CloudKit (iCloud)
   - App Groups (group.com.ambidash.app)

### Set Supabase URL + Key

In the app, go to Settings and configure the Supabase URL and anon key. Or set them programmatically:

```swift
SupabaseService.shared.configure(
    url: "https://<project-ref>.supabase.co",
    anonKey: "<your-anon-key>"
)
```

For production, embed these in a config file or use environment variables in the Xcode scheme.

## 3. StoreKit Setup

1. In App Store Connect, create subscription products:
   - `com.ambidash.premium.monthly` ($9.99/month)
   - `com.ambidash.premium.yearly` ($79.99/year)
2. For testing in simulator, use `ambidash/Products.storekit`
3. In Xcode scheme → Run → Options → StoreKit Configuration → select `Products.storekit`

## 4. Build & Archive

```bash
# Generate Xcode project
xcodegen generate

# Build for release
xcodebuild archive \
  -scheme ambidash \
  -archivePath build/AmbiDash.xcarchive \
  -destination generic/platform=iOS

# Export for App Store
xcodebuild -exportArchive \
  -archivePath build/AmbiDash.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

Or in Xcode: Product → Archive → Distribute to App Store Connect.

## 5. App Store Connect

1. Create new app with bundle ID `com.ambidash.app`
2. Fill in metadata from `docs/app-store-metadata.md`
3. Upload build from Xcode Organizer
4. Set privacy policy URL (host `docs/privacy-policy.md` content)
5. Set App Review notes from `docs/app-review-notes.md`
6. Submit for review

## 6. Post-Launch

- Monitor Supabase dashboard for database usage
- Monitor edge function logs: `supabase functions logs ai-mentor`
- Monitor App Store Connect for crash reports
- Check Xcode Organizer for energy and performance reports

## Environment Variables

| Variable | Where | Value |
|---|---|---|
| `ANTHROPIC_API_KEY` | Supabase Secrets | Your Anthropic API key |
| `SUPABASE_URL` | App config | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | App config | Your publishable anon key |
