# Ambidash Website Blocker — Chrome Extension

A Chrome Manifest V3 extension that blocks distracting websites during focus sessions. Designed with an ADHD-friendly, calming approach — gentle nudges instead of aggressive walls.

## Features

- **Declarative website blocking** using Chrome's `declarativeNetRequest` API
- **Calming blocked page** with breathing exercises, motivational messages, and session timer
- **Native messaging** integration with the Ambidash macOS app for automatic domain syncing
- **Standalone mode** — works independently with manual domain management
- **Popup dashboard** showing blocking status, blocked domains, and time remaining
- **Options page** for domain management, import/export, and native host configuration

## Quick Start

### 1. Load the Extension (Developer Mode)

1. Open Chrome and navigate to `chrome://extensions/`
2. Enable **Developer mode** (toggle in top-right corner)
3. Click **Load unpacked**
4. Select the `ambidash-chrome-extension/` directory
5. The extension icon (🎯) will appear in your toolbar

### 2. Add Domains to Block

**Option A — Via the Options page:**
1. Right-click the extension icon → **Options**
2. Type a domain (e.g., `reddit.com`) and click **+ Add**
3. Or use **Import** to bulk-add domains (one per line)

**Option B — Via the Ambidash macOS app** (see Native Messaging below):
Domains are automatically synced when a focus session starts.

### 3. Start a Focus Session

Once domains are configured, blocking activates when:
- You toggle **Website Blocking** ON in the popup
- The Ambidash app starts a focus session (via native messaging)
- You manually activate blocking via the options page

## Native Messaging (Ambidash App Integration)

The extension can connect to the Ambidash macOS app for automatic domain syncing. When connected, blocked domains are managed by the app and synced in real-time during focus sessions.

### Building the Native Messaging Host

1. **Compile the host executable:**

   ```bash
   cd native-messaging-host/
   swiftc -O -o ambidash-blocker host.swift
   ```

2. **Install the host manifest:**

   Copy `ambidash-blocker.json` to Chrome's native messaging hosts directory:

   ```bash
   # For Google Chrome
   cp ambidash-blocker.json ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/

   # For Chromium
   cp ambidash-blocker.json ~/Library/Application\ Support/Chromium/NativeMessagingHosts/

   # For Microsoft Edge
   cp ambidash-blocker.json ~/Library/Application\ Support/Microsoft\ Edge/NativeMessagingHosts/
   ```

3. **Update the manifest path:**

   Edit `ambidash-blocker.json` and set `path` to the actual location of the compiled binary:

   ```json
   {
     "name": "ambidash.blocker",
     "description": "Ambidash Website Blocker Native Messaging Host",
     "path": "/Users/yourusername/path/to/ambidash-blocker",
     "type": "stdio",
     "allowed_origins": [
       "chrome-extension://YOUR_EXTENSION_ID/"
     ]
   }
   ```

   Replace `YOUR_EXTENSION_ID` with the actual extension ID shown on `chrome://extensions/`.

4. **Make the binary executable:**

   ```bash
   chmod +x ambidash-blocker
   ```

### Connecting to the Ambidash macOS App

When the Ambidash app is installed:

1. The app writes blocked domains to App Group UserDefaults (`group.com.ambidash.restrictions`)
2. The native messaging host reads from this shared storage
3. The extension polls the host every 6 seconds for updates
4. Domains are automatically synced when a focus session starts/stops

The extension works in **standalone mode** when the native host is unavailable. You can manage domains manually via the Options page.

### App Group UserDefaults Keys

| Key | Type | Description |
|-----|------|-------------|
| `applimits.ag.blockedWebDomains` | `[String]` | Array of domain strings |
| `applimits.ag.isWebBlockingActive` | `Bool` | Whether blocking is active |
| `applimits.ag.focusEndsAt` | `Double` | Focus session end timestamp (ms) |
| `applimits.ag.overrideUntil` | `Double` | Override expiry timestamp (s) |

## File Structure

```
ambidash-chrome-extension/
├── manifest.json              # Chrome Manifest V3 configuration
├── background.js              # Service worker (core logic)
├── rules.json                 # Default empty ruleset (rules added dynamically)
├── blocked.html               # ADHD-friendly blocked page
├── blocked.js                 # Blocked page logic (timer, breathing, quotes)
├── popup.html                 # Extension popup UI
├── popup.js                   # Popup logic
├── options.html               # Settings page
├── options.js                 # Settings logic
├── icons/                     # Extension icons (16, 32, 48, 128 px)
├── native-messaging-host/
│   ├── ambidash-blocker.json  # Chrome native messaging host manifest
│   └── host.swift             # Native messaging host (Swift)
└── README.md                  # This file
```

## Architecture

```
┌─────────────────────┐
│  Ambidash macOS App  │
│  (writes to App Group│
│   UserDefaults)      │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│  Native Messaging    │
│  Host (host.swift)   │
│  Reads App Group     │
│  UserDefaults        │
└──────────┬──────────┘
           │ stdin/stdout (native messaging protocol)
┌──────────▼──────────┐
│  Chrome Extension    │
│  Service Worker      │
│  (background.js)     │
│  - Polls host 6s     │
│  - Updates rules     │
│  - Falls back to     │
│    local storage     │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌──────────┐
│ Blocked  │ │ Popup /  │
│ Page     │ │ Options  │
└─────────┘ └──────────┘
```

## Blocked Page Design

The blocked page is designed with ADHD-friendly principles:

- **Calming color palette** — soft blues, greens, and warm neutrals
- **Gentle animation** — subtle floating particles, breathing card glow
- **"Stay focused! 🎯"** — encouraging, not punishing
- **Motivational messages** — randomly selected positive affirmations
- **Built-in breathing exercise** — 4-4-6-2 pattern for self-regulation
- **Session timer** — shows remaining time so the user knows the end is in sight
- **Minimal design** — no clutter, no guilt, just a gentle nudge back

## Chrome Web Store Distribution

To publish on the Chrome Web Store:

1. Create a ZIP of the extension directory (exclude `native-messaging-host/` source files)
2. Go to the [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole)
3. Pay the one-time $5 developer registration fee
4. Upload the ZIP and fill in listing details
5. Submit for review (typically 1-3 business days)

### Permissions Justification

For the Web Store listing, you'll need to justify these permissions:

| Permission | Justification |
|-----------|---------------|
| `declarativeNetRequest` | Core functionality: blocking/redirecting requests to blocked domains |
| `declarativeNetRequestFeedback` | Monitoring rule effectiveness |
| `storage` | Persisting blocked domain lists and session state locally |
| `nativeMessaging` | Communication with Ambidash macOS app for domain syncing |
| `alarms` | Periodic polling for domain updates from native host |
| `tabs` | Reading tab URL for blocked page context |
| `<all_urls>` host permission | Required to match any domain the user wants to block |

### Privacy

- No data is sent to external servers
- All domain lists are stored locally in Chrome's extension storage
- Native messaging communicates only with the local Ambidash app
- The blocked page makes no network requests

## Development

### Testing Blocked Pages

To test the blocked page without blocking actual sites:

1. Navigate to `chrome-extension://YOUR_EXTENSION_ID/blocked.html?domain=example.com`

### Testing Native Messaging

Test the native host independently:

```bash
# Build
cd native-messaging-host/
swiftc -O -o ambidash-blocker host.swift

# Test with a JSON message (length-prefixed)
echo -n '{"type":"getStatus","data":{}}' | python3 -c "
import sys, struct
msg = sys.stdin.buffer.read()
sys.stdout.buffer.write(struct.pack('<I', len(msg)))
sys.stdout.buffer.write(msg)
" | ./ambidash-blocker | python3 -c "
import sys, struct
data = sys.stdin.buffer.read()
length = struct.unpack('<I', data[:4])[0]
import json
print(json.loads(data[4:4+length]))
"
```

### Updating Rules at Runtime

Rules are managed entirely via `chrome.declarativeNetRequest.updateDynamicRules()`. The static `rules.json` file is required by the manifest but remains empty — all blocking rules are created dynamically based on the current domain list.

## Troubleshooting

| Issue | Solution |
|-------|---------|
| Native host not connecting | Check `ambidash-blocker.json` is in the correct path and `allowed_origins` matches your extension ID |
| Domains not being blocked | Ensure blocking is toggled ON in the popup; check that domains are normalized (no `https://` prefix) |
| Blocked page not showing | Verify `blocked.html` is included in the extension and the `declarativeNetRequest` rules are active |
| Extension not loading | Check for errors on `chrome://extensions/` — ensure all required files are present |

## License

Part of the Ambidash productivity app. See the main project license for details.
