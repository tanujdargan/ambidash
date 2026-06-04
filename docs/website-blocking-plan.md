# Website Blocking Technical Plan
## Safari & Chrome Extensions for Focus Window Website Blocking

**Date**: June 2026
**Status**: Technical Design
**Integration**: Extends existing `feat/v5-app-restrictions` feature

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Research Findings](#2-research-findings)
3. [Architecture Overview](#3-architecture-overview)
4. [Apple Framework Integration (ManagedSettings)](#4-apple-framework-integration-managedsettings)
5. [Safari Web Extension](#5-safari-web-extension)
6. [Chrome Extension (Manifest V3)](#6-chrome-extension-manifest-v3)
7. [Native App ↔ Extension Communication](#7-native-app--extension-communication)
8. [Entitlements & Capabilities](#8-entitlements--capabilities)
9. [Code Structure](#9-code-structure)
10. [Integration with Existing Restrictions Feature](#10-integration-with-existing-restrictions-feature)
11. [Complexity Estimates](#11-complexity-estimates)
12. [Risks & Mitigations](#12-risks--mitigations)
13. [Implementation Phases](#13-implementation-phases)

---

## 1. Executive Summary

This plan covers building website blocking for Safari and Chrome during scheduled focus windows. The solution uses a **dual-layer approach**:

- **Layer 1 (Safari)**: Apple's `ManagedSettings.ShieldSettings.webDomains` — native OS-level web domain blocking that covers Safari AND all WebKit-based browsers. Requires `Family Controls` entitlement.
- **Layer 2 (Chrome)**: A Chrome Extension using `declarativeNetRequest` API (Manifest V3) to redirect blocked domains to a local "blocked" page.
- **Layer 3 (Both)**: Safari Web Extension as a fallback/supplement for Safari-specific blocking with richer UI.

**Key Insight**: `ManagedSettings.ShieldSettings.webDomains` blocks web domains at the OS level for Safari and all WebKit browsers. Chrome uses its own rendering engine, so it requires a separate extension.

---

## 2. Research Findings

### 2.1 How ManagedSettings Blocks Web Domains

Apple's `ManagedSettings` framework (iOS 15+, Mac Catalyst 15+) provides:

```swift
struct ShieldSettings {
    // Block specific web domains with a shield overlay
    var webDomains: Set<WebDomainToken>?
    
    // Block web domain categories
    var webDomainCategories: ShieldSettings.CategorySpecificSelection<ActivityCategoryToken>?
}

struct WebDomain {
    let domain: String?          // e.g., "facebook.com"
    let token: WebDomainToken?   // Opaque token for privacy
}
```

**How it works**:
- Create `WebDomain` objects from domain strings: `WebDomain(domain: "facebook.com")`
- Get the `WebDomainToken` from the domain
- Set `store.shield.webDomains` to a set of these tokens
- The system displays a shield overlay over Safari tabs showing blocked domains
- Works for Safari and all WebKit-based browsers (not Chrome/Firefox)

**Important**: The `WebDomainToken` is device-local and privacy-preserving — you can't see which domain a token represents unless you created it. This matches how `ApplicationToken` works for apps.

### 2.2 Safari Web Extensions

Safari Web Extensions are built using standard web extension APIs (JavaScript, HTML, CSS) and work across Chrome, Firefox, and Edge with minimal changes. Key facts:

- **Distribution**: Must be packaged as a macOS app extension (inside a host app)
- **APIs**: Uses standard `chrome.*` / `browser.*` APIs
- **Content Blockers**: Can use `declarativeNetRequest` or the older content blocker JSON format
- **Native Messaging**: Can communicate with the host macOS app via native messaging
- **Permissions**: Requires user to enable in Safari Preferences → Extensions

**Relevant APIs for blocking**:
- `declarativeNetRequest` — declarative URL blocking/redirecting
- `webNavigation` — detect page loads
- `tabs` — monitor and redirect tabs
- `storage` — store blocked domain lists locally

### 2.3 Chrome Extension (Manifest V3)

Chrome Manifest V3 uses `declarativeNetRequest` for website blocking:

```json
{
  "manifest_version": 3,
  "permissions": ["declarativeNetRequest", "declarativeNetRequestFeedback"],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  },
  "declarative_net_request": {
    "rule_resources": [{
      "id": "block_rules",
      "enabled": true,
      "path": "rules.json"
    }]
  }
}
```

**Blocking Rule Format**:
```json
[{
  "id": 1,
  "priority": 1,
  "action": {
    "type": "redirect",
    "redirect": { "extensionPath": "/blocked.html" }
  },
  "condition": {
    "urlFilter": "||facebook.com",
    "resourceTypes": ["main_frame"]
  }
}]
```

**Dynamic Rules**: Can add/remove rules at runtime via `chrome.declarativeNetRequest.updateDynamicRules()` — this is how we'll sync blocked domains from the native app.

### 2.4 Family Controls Entitlement

The `Family Controls` capability is required for using `ManagedSettings`:

- **Entitlement**: `com.apple.developer.family-controls`
- **Authorization**: Must call `AuthorizationCenter.shared.requestAuthorization(for: .individual)` 
- **App Review**: Must request permission from Apple before App Store submission
- **Limitation**: On macOS, this is designed for parental controls but works for individual device management
- **Important**: The authorization prompt is system-controlled — users see a biometric auth dialog

**macOS Considerations**:
- Available on Mac Catalyst 15.0+
- NOT available on native macOS (AppKit) — must use Mac Catalyst or SwiftUI with Mac Catalyst
- The app must be built with Mac Catalyst support enabled
- DeviceActivity monitors run in a separate extension process

### 2.5 One Extension vs Two

**Separate extensions are required**:

| Browser | Extension Type | Blocking Mechanism |
|---------|---------------|-------------------|
| Safari | Safari Web Extension (packaged in host app) | `declarativeNetRequest` + `ManagedSettings` |
| Chrome | Chrome Extension (distributed separately or via Chrome Web Store) | `declarativeNetRequest` |

**Why separate**:
1. Safari extensions use Apple's extension model (app extension inside a macOS app)
2. Chrome extensions use Google's extension model (CRX package)
3. Different distribution channels (Mac App Store vs Chrome Web Store)
4. Different APIs for native communication (Safari: native messaging; Chrome: native messaging with different host format)

**Shared code opportunity**: The core logic (domain list management, blocking page UI) can be shared as JavaScript modules, but packaging and native messaging must be browser-specific.

### 2.6 Bridging Native App ↔ Browser Extensions

**Communication approaches**:

1. **Shared App Group UserDefaults** (Safari only):
   - The native app writes blocked domains to a shared UserDefaults suite
   - The Safari extension reads from the same suite
   - Works because both are in the same app bundle

2. **Native Messaging** (Both browsers):
   - Extensions communicate with a native messaging host
   - The host reads/writes to the shared App Group
   - More complex but works for both Safari and Chrome

3. **Local HTTP Server** (Alternative for Chrome):
   - The native app runs a local HTTP server on localhost
   - Chrome extension polls or uses WebSocket for updates
   - Simple but less elegant

**Recommended approach**: 
- **Safari**: Shared App Group UserDefaults (simpler, already in use for DeviceActivity monitor)
- **Chrome**: Native Messaging Host (standard approach, works cross-platform)

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Ambidash macOS App                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            AppLimitController + Restrictions          │  │
│  │  - Manages RestrictionWindow schedules                │  │
│  │  - Manages AppBudget limits                           │  │
│  │  - Manages Focus Sessions                             │  │
│  │  - NEW: Manages blocked web domains list              │  │
│  └──────────────┬───────────────────────────┬────────────┘  │
│                 │                           │               │
│    ┌────────────▼────────────┐  ┌───────────▼──────────┐   │
│    │   ManagedSettingsStore  │  │  App Group UserDefaults│   │
│    │   - shield.applications │  │  - blockedDomains:    │   │
│    │   - shield.webDomains   │  │    [String]           │   │
│    │   (Safari/WebKit only)  │  │  - isBlockingActive:  │   │
│    └─────────────────────────┘  │    Bool               │   │
│                                 │  - blockedPageHTML:   │   │
│                                 │    String             │   │
│                                 └───────────┬──────────┘   │
│                                             │               │
└─────────────────────────────────────────────┼───────────────┘
                                              │
        ┌─────────────────────────────────────┼────────────────┐
        │                                     │                │
        ▼                                     ▼                ▼
┌───────────────┐              ┌───────────────────┐  ┌────────────────┐
│ Safari Web    │              │ Chrome Extension  │  │ DeviceActivity │
│ Extension     │              │ (Native Messaging)│  │ Monitor        │
│               │              │                   │  │ Extension      │
│ - background.js│             │ - background.js   │  │                │
│ - content.js  │              │ - rules.json      │  │ - Shields apps │
│ - blocked.html│              │ - blocked.html    │  │ - NEW: shields │
│               │              │                   │  │   web domains  │
│ Reads from    │              │ Communicates via  │  │                │
│ App Group     │              │ native messaging  │  │ Reads from     │
│ UserDefaults  │              │ host              │  │ App Group      │
└───────────────┘              └───────────────────┘  └────────────────┘
```

---

## 4. Apple Framework Integration (ManagedSettings)

### 4.1 Adding Web Domain Blocking to DeviceActivityMonitor

The existing `AmbidashDeviceActivityMonitor` needs to be extended to also block web domains:

```swift
// In DeviceActivityMonitorExtension.swift

// Add to AGKey enum
enum AGKey {
    // ... existing keys ...
    static let blockedWebDomains = "applimits.ag.blockedWebDomains"  // Data: [String]
}

// New method for web domain shielding
private func shieldWebDomains() {
    guard let domainStrings = defaults?.stringArray(forKey: Key.blockedWebDomains) else { return }
    
    let webDomainTokens: Set<WebDomainToken> = Set(
        domainStrings.compactMap { domain in
            WebDomain(domain: domain).token
        }
    )
    
    // Merge with existing shield
    var current = store.shield.webDomains ?? Set<WebDomainToken>()
    current.formUnion(webDomainTokens)
    store.shield.webDomains = current.isEmpty ? nil : current
}

// Update shieldShared() to also shield web domains
private func shieldShared() {
    // ... existing app shielding code ...
    
    // Add web domain shielding
    shieldWebDomains()
}

// Update clearShield() to also clear web domains
private func clearShield() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil  // Clear web domain shield
}
```

### 4.2 AppLimitController Extensions for Web Domains

```swift
// New extension or addition to AppLimitController+Restrictions.swift

extension AppLimitController {
    
    /// Blocked web domain strings (e.g., ["facebook.com", "twitter.com"])
    var blockedWebDomains: [String] {
        get { defaults?.stringArray(forKey: AGKey.blockedWebDomains) ?? [] }
        set { defaults?.set(newValue, forKey: AGKey.blockedWebDomains) }
    }
    
    /// Add domains to the blocked list and update all shields
    func blockWebDomains(_ domains: [String]) {
        var current = Set(blockedWebDomains)
        current.formUnion(domains)
        blockedWebDomains = Array(current)
        updateWebDomainShield()
    }
    
    /// Remove domains from the blocked list
    func unblockWebDomains(_ domains: [String]) {
        var current = Set(blockedWebDomains)
        current.subtract(domains)
        blockedWebDomains = Array(current)
        updateWebDomainShield()
    }
    
    /// Apply the current web domain list to ManagedSettings
    private func updateWebDomainShield() {
        #if os(iOS)
        guard authState == .approved else { return }
        
        let tokens: Set<WebDomainToken> = Set(
            blockedWebDomains.compactMap { WebDomain(domain: $0).token }
        )
        
        if isBlockingActive || isFocusSessionActive {
            store.shield.webDomains = tokens.isEmpty ? nil : tokens
        }
        #endif
    }
}
```

### 4.3 SwiftData Model Extension

Add web domain blocking to the existing `RestrictionWindow` model:

```swift
@Model
final class RestrictionWindow {
    // ... existing properties ...
    
    /// JSON-encoded array of web domain strings to block during this window
    /// e.g., ["facebook.com", "twitter.com", "reddit.com"]
    var blockedWebDomainsData: Data? = nil
    
    /// Computed property for blocked domains
    var blockedWebDomains: [String] {
        get {
            guard let data = blockedWebDomainsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            blockedWebDomainsData = try? JSONEncoder().encode(newValue)
        }
    }
}
```

---

## 5. Safari Web Extension

### 5.1 Project Structure

```
ambidash/
├── ambidash-safari-extension/
│   ├── Info.plist
│   ├── SafariWebExtensionHandler.swift    # Native messaging handler
│   └── Resources/
│       ├── manifest.json                  # Web extension manifest
│       ├── background.js                  # Service worker
│       ├── content.js                     # Content script (optional)
│       ├── blocked.html                   # Blocked page UI
│       ├── blocked.js                     # Blocked page logic
│       ├── blocked.css                    # Blocked page styles
│       └── icons/
│           ├── icon-16.png
│           ├── icon-32.png
│           ├── icon-48.png
│           └── icon-128.png
```

### 5.2 Manifest.json (Safari Web Extension)

```json
{
  "manifest_version": 3,
  "name": "Ambidash Website Blocker",
  "version": "1.0",
  "description": "Blocks distracting websites during focus sessions",
  "permissions": [
    "declarativeNetRequest",
    "declarativeNetRequestFeedback",
    "storage",
    "nativeMessaging"
  ],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  },
  "declarative_net_request": {
    "rule_resources": [{
      "id": "dynamic_rules",
      "enabled": true,
      "path": "rules.json"
    }]
  },
  "action": {
    "default_popup": "popup.html",
    "default_icon": {
      "16": "icons/icon-16.png",
      "32": "icons/icon-32.png"
    }
  },
  "icons": {
    "48": "icons/icon-48.png",
    "128": "icons/icon-128.png"
  }
}
```

### 5.3 background.js (Safari Extension)

```javascript
// background.js — Safari Web Extension service worker

const APP_GROUP_SUITE = 'group.com.ambidash.app';
const BLOCKED_DOMAINS_KEY = 'applimits.ag.blockedWebDomains';
const IS_BLOCKING_ACTIVE_KEY = 'applimits.ag.isWebBlockingActive';

// Check for updates from native app periodically
let checkInterval = null;

// Initialize extension
chrome.runtime.onInstalled.addListener(() => {
  console.log('Ambidash Website Blocker installed');
  startCheckingForUpdates();
});

chrome.runtime.onStartup.addListener(() => {
  startCheckingForUpdates();
});

// Start periodic check for blocked domain updates
function startCheckingForUpdates() {
  if (checkInterval) clearInterval(checkInterval);
  checkInterval = setInterval(checkForUpdates, 5000); // Check every 5 seconds
}

// Check native app for blocked domain updates
async function checkForUpdates() {
  try {
    // Use native messaging to communicate with host app
    const response = await sendNativeMessage({ type: 'getStatus' });
    
    if (response && response.blockedDomains) {
      await updateBlockingRules(response.blockedDomains, response.isActive);
    }
  } catch (error) {
    // Native messaging not available, fall back to storage
    const stored = await chrome.storage.local.get(['blockedDomains', 'isActive']);
    if (stored.blockedDomains) {
      await updateBlockingRules(stored.blockedDomains, stored.isActive);
    }
  }
}

// Update declarativeNetRequest rules
async function updateBlockingRules(domains, isActive) {
  // Get existing dynamic rules
  const existingRules = await chrome.declarativeNetRequest.getDynamicRules();
  
  if (!isActive || !domains || domains.length === 0) {
    // Remove all rules if blocking is inactive
    if (existingRules.length > 0) {
      await chrome.declarativeNetRequest.updateDynamicRules({
        removeRuleIds: existingRules.map(r => r.id)
      });
    }
    return;
  }
  
  // Create new rules for each domain
  const newRules = domains.map((domain, index) => ({
    id: index + 1,
    priority: 1,
    action: {
      type: 'redirect',
      redirect: { extensionPath: '/blocked.html?domain=' + encodeURIComponent(domain) }
    },
    condition: {
      urlFilter: `||${domain}`,
      resourceTypes: ['main_frame']
    }
  }));
  
  // Update rules
  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: existingRules.map(r => r.id),
    addRules: newRules
  });
}

// Native messaging helper
function sendNativeMessage(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendNativeMessage('com.ambidash.weblocker', message, (response) => {
      if (chrome.runtime.lastError) {
        reject(chrome.runtime.lastError);
      } else {
        resolve(response);
      }
    });
  });
}

// Listen for messages from popup or content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'getBlockedDomains') {
    chrome.storage.local.get(['blockedDomains', 'isActive'], (result) => {
      sendResponse(result);
    });
    return true; // Keep channel open for async response
  }
});
```

### 5.4 SafariWebExtensionHandler.swift (Native Messaging)

```swift
// SafariWebExtensionHandler.swift
import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    
    private let appGroup = "group.com.ambidash.app"
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
    
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any]
        
        guard let messageType = message?["type"] as? String else {
            context.completeRequest(returningItems: nil)
            return
        }
        
        var response: [String: Any] = [:]
        
        switch messageType {
        case "getStatus":
            response = getStatus()
        case "getBlockedDomains":
            response = getBlockedDomains()
        default:
            response = ["error": "Unknown message type"]
        }
        
        let responseItem = NSExtensionItem()
        responseItem.userInfo = [SFExtensionMessageKey: response]
        context.completeRequest(returningItems: [responseItem])
    }
    
    private func getStatus() -> [String: Any] {
        let domains = defaults?.stringArray(forKey: "applimits.ag.blockedWebDomains") ?? []
        let isActive = defaults?.bool(forKey: "applimits.ag.isWebBlockingActive") ?? false
        let overrideUntil = defaults?.double(forKey: "applimits.ag.overrideUntil") ?? 0
        let isOverrideActive = Date().timeIntervalSince1970 < overrideUntil
        
        return [
            "blockedDomains": domains,
            "isActive": isActive && !isOverrideActive,
            "isOverrideActive": isOverrideActive
        ]
    }
    
    private func getBlockedDomains() -> [String: Any] {
        let domains = defaults?.stringArray(forKey: "applimits.ag.blockedWebDomains") ?? []
        return ["blockedDomains": domains]
    }
}
```

---

## 6. Chrome Extension (Manifest V3)

### 6.1 Project Structure

```
ambidash-chrome-extension/
├── manifest.json
├── background.js
├── blocked.html
├── blocked.js
├── blocked.css
├── popup.html
├── popup.js
├── popup.css
├── native-messaging-host/
│   ├── com.ambidash.weblocker.json    # Native messaging host manifest
│   └── host.py                         # Native messaging host script (or Swift)
└── icons/
    ├── icon-16.png
    ├── icon-32.png
    ├── icon-48.png
    └── icon-128.png
```

### 6.2 manifest.json (Chrome Extension)

```json
{
  "manifest_version": 3,
  "name": "Ambidash Website Blocker",
  "version": "1.0",
  "description": "Blocks distracting websites during focus sessions for Ambidash",
  "permissions": [
    "declarativeNetRequest",
    "declarativeNetRequestFeedback",
    "storage",
    "nativeMessaging",
    "alarms"
  ],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  },
  "declarative_net_request": {
    "rule_resources": [{
      "id": "block_rules",
      "enabled": true,
      "path": "rules.json"
    }]
  },
  "action": {
    "default_popup": "popup.html",
    "default_icon": {
      "16": "icons/icon-16.png",
      "32": "icons/icon-32.png"
    }
  },
  "icons": {
    "48": "icons/icon-48.png",
    "128": "icons/icon-128.png"
  }
}
```

### 6.3 rules.json (Default/Static Rules)

```json
[]
```

Note: All rules are added dynamically. The static rules file can be empty.

### 6.4 background.js (Chrome Extension)

```javascript
// background.js — Chrome Extension service worker

const NATIVE_HOST_NAME = 'com.ambidash.weblocker';
const CHECK_ALARM_NAME = 'checkBlockedDomains';

// Initialize
chrome.runtime.onInstalled.addListener(() => {
  console.log('Ambidash Website Blocker installed');
  setupAlarms();
});

chrome.runtime.onStartup.addListener(() => {
  setupAlarms();
});

// Setup periodic alarm to check for updates
function setupAlarms() {
  chrome.alarms.create(CHECK_ALARM_NAME, {
    delayInMinutes: 0.1,    // First check after 6 seconds
    periodInMinutes: 0.1    // Then every 6 seconds
  });
}

// Listen for alarms
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === CHECK_ALARM_NAME) {
    checkForUpdates();
  }
});

// Check native app for blocked domain updates
async function checkForUpdates() {
  try {
    const response = await sendNativeMessage({ type: 'getStatus' });
    
    if (response && response.blockedDomains) {
      await updateBlockingRules(response.blockedDomains, response.isActive);
      
      // Also store locally for offline access
      await chrome.storage.local.set({
        blockedDomains: response.blockedDomains,
        isActive: response.isActive,
        lastUpdate: Date.now()
      });
    }
  } catch (error) {
    console.log('Native messaging unavailable, using cached data');
    
    // Fall back to cached data
    const cached = await chrome.storage.local.get(['blockedDomains', 'isActive']);
    if (cached.blockedDomains) {
      await updateBlockingRules(cached.blockedDomains, cached.isActive);
    }
  }
}

// Update declarativeNetRequest rules
async function updateBlockingRules(domains, isActive) {
  const existingRules = await chrome.declarativeNetRequest.getDynamicRules();
  const existingIds = existingRules.map(r => r.id);
  
  if (!isActive || !domains || domains.length === 0) {
    // Remove all rules
    if (existingIds.length > 0) {
      await chrome.declarativeNetRequest.updateDynamicRules({
        removeRuleIds: existingIds
      });
    }
    return;
  }
  
  // Create rules for each domain
  const newRules = domains.map((domain, index) => ({
    id: index + 1,
    priority: 1,
    action: {
      type: 'redirect',
      redirect: { 
        url: chrome.runtime.getURL('blocked.html') + '?domain=' + encodeURIComponent(domain)
      }
    },
    condition: {
      urlFilter: `||${domain}`,
      resourceTypes: ['main_frame', 'sub_frame']
    }
  }));
  
  // Update rules atomically
  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: existingIds,
    addRules: newRules
  });
  
  console.log(`Updated blocking rules for ${domains.length} domains`);
}

// Native messaging
function sendNativeMessage(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendNativeMessage(NATIVE_HOST_NAME, message, (response) => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else {
        resolve(response);
      }
    });
  });
}

// Listen for messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'getStatus') {
    chrome.storage.local.get(['blockedDomains', 'isActive', 'lastUpdate'], (result) => {
      sendResponse(result);
    });
    return true;
  }
  
  if (message.type === 'forceRefresh') {
    checkForUpdates().then(() => {
      sendResponse({ success: true });
    });
    return true;
  }
});
```

### 6.5 Native Messaging Host (macOS)

#### com.ambidash.weblocker.json (Install to ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/)

```json
{
  "name": "com.ambidash.weblocker",
  "description": "Ambidash Website Blocker Native Host",
  "path": "/Applications/Ambidash.app/Contents/Library/LoginItems/AmbidashNativeHost.app/Contents/MacOS/AmbidashNativeHost",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://YOUR_EXTENSION_ID/"
  ]
}
```

#### NativeHost.swift (Separate executable or embedded in main app)

```swift
// NativeHost.swift — Native messaging host for Chrome extension
import Foundation

class NativeMessagingHost {
    let appGroup = "group.com.ambidash.app"
    var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
    
    func run() {
        while true {
            guard let message = readMessage() else { break }
            let response = handleMessage(message)
            writeMessage(response)
        }
    }
    
    private func readMessage() -> [String: Any]? {
        // Read message length (4 bytes, little-endian)
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        guard FileHandle.standardInput.read(&lengthBytes, maxLength: 4) == 4 else {
            return nil
        }
        
        let length = Int(lengthBytes[0]) | 
                     Int(lengthBytes[1]) << 8 | 
                     Int(lengthBytes[2]) << 16 | 
                     Int(lengthBytes[3]) << 24
        
        // Read message body
        guard let data = FileHandle.standardInput.readData(ofLength: length) as Data?,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    private func writeMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        
        // Write length (4 bytes, little-endian)
        var length = UInt32(data.count)
        let lengthData = Data(bytes: &length, count: 4)
        
        FileHandle.standardOutput.write(lengthData)
        FileHandle.standardOutput.write(data)
    }
    
    private func handleMessage(_ message: [String: Any]) -> [String: Any] {
        guard let type = message["type"] as? String else {
            return ["error": "Missing message type"]
        }
        
        switch type {
        case "getStatus":
            return getStatus()
        case "getBlockedDomains":
            return getBlockedDomains()
        default:
            return ["error": "Unknown message type"]
        }
    }
    
    private func getStatus() -> [String: Any] {
        let domains = defaults?.stringArray(forKey: "applimits.ag.blockedWebDomains") ?? []
        let isActive = defaults?.bool(forKey: "applimits.ag.isWebBlockingActive") ?? false
        let overrideUntil = defaults?.double(forKey: "applimits.ag.overrideUntil") ?? 0
        let isOverrideActive = Date().timeIntervalSince1970 < overrideUntil
        
        return [
            "blockedDomains": domains,
            "isActive": isActive && !isOverrideActive,
            "isOverrideActive": isOverrideActive
        ]
    }
    
    private func getBlockedDomains() -> [String: Any] {
        let domains = defaults?.stringArray(forKey: "applimits.ag.blockedWebDomains") ?? []
        return ["blockedDomains": domains]
    }
}

// Entry point
let host = NativeMessagingHost()
host.run()
```

---

## 7. Native App ↔ Extension Communication

### 7.1 Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Native App (SwiftUI)                     │
│                                                             │
│  User adds "facebook.com" to blocked domains                │
│         │                                                   │
│         ▼                                                   │
│  AppLimitController.blockWebDomains(["facebook.com"])       │
│         │                                                   │
│         ├──────────────────┬──────────────────┐             │
│         ▼                  ▼                  ▼             │
│  ManagedSettings      App Group         App Group           │
│  Store                UserDefaults      UserDefaults        │
│  (Safari shield)      (blockedDomains)  (isBlockingActive)  │
│         │                  │                  │             │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
   ┌──────────┐      ┌──────────────┐    ┌──────────────┐
   │ Safari   │      │ Safari Web   │    │ Chrome       │
   │ (native) │      │ Extension    │    │ Extension    │
   │          │      │ (reads from  │    │ (native msg) │
   │ Shield   │      │ App Group)   │    │ host reads   │
   │ overlay  │      │              │    │ App Group)   │
   └──────────┘      └──────────────┘    └──────────────┘
```

### 7.2 App Group UserDefaults Keys

| Key | Type | Description |
|-----|------|-------------|
| `applimits.ag.blockedWebDomains` | `[String]` | Array of domain strings to block |
| `applimits.ag.isWebBlockingActive` | `Bool` | Whether web blocking is currently active |
| `applimits.ag.overrideUntil` | `Double` | Timestamp when override expires (existing) |
| `applimits.ag.focusEndsAt` | `Double` | Timestamp when focus session ends (existing) |
| `applimits.ag.windowConfigs` | `Data` | JSON-encoded window configs (existing) |

### 7.3 Sync Strategy

1. **Safari (ManagedSettings)**: Immediate — `ManagedSettingsStore` applies instantly
2. **Safari (Extension)**: Near real-time — Extension polls App Group every 5 seconds
3. **Chrome**: Near real-time — Native host polls App Group every 6 seconds (via alarm)

**Optimization**: Use Darwin notifications or distributedNotificationCenter to push updates instead of polling:

```swift
// In AppLimitController
DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("com.ambidash.blockedDomainsChanged"),
    object: nil,
    userInfo: ["domains": blockedWebDomains, "isActive": isWebBlockingActive]
)
```

---

## 8. Entitlements & Capabilities

### 8.1 Required Entitlements

| Entitlement | Purpose | Request Process |
|-------------|---------|-----------------|
| `com.apple.developer.family-controls` | Use ManagedSettings for app/web shielding | Request from Apple Developer Portal |
| `com.apple.security.application-groups` | Shared UserDefaults between app and extensions | Add in Xcode Capabilities |
| `com.apple.developer.device-activity-monitor-extension` | DeviceActivity monitor extension | Automatic with Family Controls |
| `com.apple.Safari.web-extension` | Safari Web Extension | Automatic with Safari Extension target |

### 8.2 Capabilities to Enable in Xcode

1. **Main App Target**:
   - Family Controls
   - App Groups (group.com.ambidash.app)
   - Background Modes (if needed for native messaging)

2. **DeviceActivity Monitor Extension**:
   - App Groups (group.com.ambidash.app)

3. **Safari Web Extension Target**:
   - App Groups (group.com.ambidash.app)

4. **Native Messaging Host** (if separate target):
   - App Groups (group.com.ambidash.app)

### 8.3 Info.plist Entries

**Main App**:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.services</string>
</dict>
```

**Safari Extension**:
```xml
<key>SFSafariWebExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.Safari.web-extension</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).SafariWebExtensionHandler</string>
</dict>
```

---

## 9. Code Structure

### 9.1 New Files to Create

```
ambidash/
├── ambidash/
│   ├── Services/
│   │   ├── WebDomainBlockingService.swift        # NEW: Core web domain logic
│   │   └── AppLimitController+WebDomains.swift   # NEW: Extension for web domains
│   ├── Models/
│   │   └── RestrictionModels.swift               # MODIFY: Add blockedWebDomains
│   └── Views/
│       └── Settings/
│           └── WebDomainsSettingsView.swift       # NEW: UI for managing blocked domains
│
├── ambidash-monitor/
│   └── DeviceActivityMonitorExtension.swift       # MODIFY: Add web domain shielding
│
├── ambidash-safari-extension/
│   ├── Info.plist
│   ├── SafariWebExtensionHandler.swift
│   └── Resources/
│       ├── manifest.json
│       ├── background.js
│       ├── blocked.html
│       ├── blocked.js
│       ├── blocked.css
│       └── icons/
│
├── ambidash-chrome-extension/                     # NEW: Chrome extension (separate repo/folder)
│   ├── manifest.json
│   ├── background.js
│   ├── rules.json
│   ├── blocked.html
│   ├── blocked.js
│   ├── blocked.css
│   ├── popup.html
│   ├── popup.js
│   ├── popup.css
│   └── icons/
│
└── ambidash-native-host/                          # NEW: Native messaging host
    ├── NativeHost.swift
    └── Info.plist
```

### 9.2 WebDomainBlockingService.swift

```swift
// WebDomainBlockingService.swift
import Foundation
import ManagedSettings
import FamilyControls

/// Service for managing web domain blocking across Safari and Chrome
@Observable
class WebDomainBlockingService {
    let store = ManagedSettingsStore()
    let appGroup = "group.com.ambidash.app"
    
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
    
    /// List of currently blocked web domains
    var blockedDomains: [String] {
        get { defaults?.stringArray(forKey: "applimits.ag.blockedWebDomains") ?? [] }
        set {
            defaults?.set(newValue, forKey: "applimits.ag.blockedWebDomains")
            notifyExtensions()
        }
    }
    
    /// Whether web blocking is currently active
    var isBlockingActive: Bool {
        get { defaults?.bool(forKey: "applimits.ag.isWebBlockingActive") ?? false }
        set {
            defaults?.set(newValue, forKey: "applimits.ag.isWebBlockingActive")
            if newValue {
                applyWebDomainShield()
            } else {
                clearWebDomainShield()
            }
            notifyExtensions()
        }
    }
    
    // MARK: - Domain Management
    
    func addDomain(_ domain: String) {
        let normalized = normalizeDomain(domain)
        guard !blockedDomains.contains(normalized) else { return }
        blockedDomains.append(normalized)
        
        if isBlockingActive {
            applyWebDomainShield()
        }
    }
    
    func removeDomain(_ domain: String) {
        let normalized = normalizeDomain(domain)
        blockedDomains.removeAll { $0 == normalized }
        
        if isBlockingActive {
            applyWebDomainShield()
        }
    }
    
    func addDomains(_ domains: [String]) {
        let normalized = domains.map(normalizeDomain)
        let unique = Set(blockedDomains + normalized)
        blockedDomains = Array(unique)
        
        if isBlockingActive {
            applyWebDomainShield()
        }
    }
    
    func clearAllDomains() {
        blockedDomains = []
        clearWebDomainShield()
    }
    
    // MARK: - Shield Management
    
    /// Apply the ManagedSettings shield for web domains (Safari/WebKit browsers)
    func applyWebDomainShield() {
        let tokens: Set<WebDomainToken> = Set(
            blockedDomains.compactMap { WebDomain(domain: $0).token }
        )
        store.shield.webDomains = tokens.isEmpty ? nil : tokens
    }
    
    /// Clear the ManagedSettings shield for web domains
    func clearWebDomainShield() {
        store.shield.webDomains = nil
    }
    
    // MARK: - Extension Notification
    
    /// Notify browser extensions of changes
    private func notifyExtensions() {
        // Post distributed notification for native messaging host
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.ambidash.blockedDomainsChanged"),
            object: nil,
            userInfo: [
                "domains": blockedDomains,
                "isActive": isBlockingActive
            ]
        )
    }
    
    // MARK: - Helpers
    
    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove protocol
        if normalized.hasPrefix("http://") {
            normalized = String(normalized.dropFirst(7))
        } else if normalized.hasPrefix("https://") {
            normalized = String(normalized.dropFirst(8))
        }
        
        // Remove www.
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        
        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
}
```

---

## 10. Integration with Existing Restrictions Feature

### 10.1 Changes to RestrictionWindow

The existing `RestrictionWindow` model needs web domain support:

```swift
// In RestrictionModels.swift

@Model
final class RestrictionWindow {
    // ... existing properties ...
    
    /// JSON-encoded array of web domain strings to block during this window
    var blockedWebDomainsData: Data? = nil
    
    var blockedWebDomains: [String] {
        get {
            guard let data = blockedWebDomainsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            blockedWebDomainsData = try? JSONEncoder().encode(newValue)
        }
    }
}
```

### 10.2 Changes to AppLimitController+Restrictions.swift

```swift
// Add to existing extension

extension AppLimitController {
    // ... existing code ...
    
    /// Web domain blocking service (lazy initialized)
    private static let webDomainService = WebDomainBlockingService()
    
    var webDomainService: WebDomainBlockingService {
        Self.webDomainService
    }
    
    /// Update web domain blocking when schedules change
    func applySchedulesWithWebDomains(windows: [RestrictionWindow], budgets: [AppBudget]) {
        // Call existing method
        applySchedules(windows: windows, budgets: budgets)
        
        // Also update web domain blocking
        let allDomains = windows.flatMap { $0.blockedWebDomains }
        webDomainService.blockedDomains = Array(Set(allDomains))
    }
    
    /// Start focus session with web domains
    func startFocusSessionWithWebDomains(minutes: Int, webDomains: [String]) {
        // Start existing focus session
        startFocusSession(minutes: minutes)
        
        // Also block web domains
        webDomainService.addDomains(webDomains)
        webDomainService.isBlockingActive = true
    }
    
    /// End focus session and clear web domains
    func endFocusSessionWithWebDomains() {
        endFocusSession()
        webDomainService.isBlockingActive = false
    }
}
```

### 10.3 Changes to DeviceActivityMonitorExtension.swift

```swift
// Add to existing monitor

class AmbidashDeviceActivityMonitor: DeviceActivityMonitor {
    // ... existing code ...
    
    // Add to Key enum
    private enum Key {
        // ... existing keys ...
        static let blockedWebDomains = "applimits.ag.blockedWebDomains"
        static let isWebBlockingActive = "applimits.ag.isWebBlockingActive"
    }
    
    // Update shieldShared() to include web domains
    private func shieldShared() {
        // ... existing app shielding ...
        
        // Add web domain shielding
        shieldWebDomains()
    }
    
    // New method for web domain shielding
    private func shieldWebDomains() {
        guard let domainStrings = defaults?.stringArray(forKey: Key.blockedWebDomains),
              !domainStrings.isEmpty else { return }
        
        let webDomainTokens: Set<WebDomainToken> = Set(
            domainStrings.compactMap { WebDomain(domain: $0).token }
        )
        
        var current = store.shield.webDomains ?? Set<WebDomainToken>()
        current.formUnion(webDomainTokens)
        store.shield.webDomains = current.isEmpty ? nil : current
        
        // Update active flag for extensions
        defaults?.set(true, forKey: Key.isWebBlockingActive)
    }
    
    // Update clearShield() to include web domains
    private func clearShield() {
        // ... existing code ...
        store.shield.webDomains = nil
        defaults?.set(false, forKey: Key.isWebBlockingActive)
    }
}
```

---

## 11. Complexity Estimates

### 11.1 Development Effort

| Component | Estimated Hours | Complexity |
|-----------|----------------|------------|
| **WebDomainBlockingService.swift** | 8-12 | Medium |
| **AppLimitController extensions** | 6-8 | Low |
| **RestrictionWindow model updates** | 2-4 | Low |
| **DeviceActivityMonitor updates** | 4-6 | Low |
| **WebDomainsSettingsView.swift** | 12-16 | Medium |
| **Safari Web Extension (JS + Swift)** | 20-30 | High |
| **Chrome Extension (JS)** | 16-20 | Medium |
| **Native Messaging Host** | 12-16 | High |
| **Testing & Integration** | 20-30 | High |
| **Total** | **100-142 hours** | **High** |

### 11.2 Timeline Estimate

- **Phase 1 (Native App + Safari)**: 3-4 weeks
- **Phase 2 (Chrome Extension)**: 2-3 weeks
- **Phase 3 (Polish + Testing)**: 2-3 weeks
- **Total**: 7-10 weeks

---

## 12. Risks & Mitigations

### 12.1 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Family Controls entitlement rejection | High | Request early; provide clear use case documentation |
| ManagedSettings not working on macOS (Catalyst) | High | Test early; fallback to extension-only blocking |
| Chrome extension permissions rejection | Medium | Minimal permissions; clear privacy policy |
| Native messaging complexity | Medium | Use well-tested libraries; extensive error handling |
| Sync latency between app and extensions | Low | 5-6 second polling is acceptable; add push notifications |

### 12.2 User Experience Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Users confused by Safari shield overlay | Medium | Customize shield message; provide clear instructions |
| Chrome extension requires manual installation | Medium | Provide clear setup guide; consider Chrome Web Store |
| Domain blocking can be bypassed (incognito, other browsers) | High | Document limitations; consider DNS-level blocking as future feature |

### 12.3 Limitations

1. **Safari Only (ManagedSettings)**: The native shield only works for Safari and WebKit browsers
2. **Chrome Only (Extension)**: The Chrome extension only works for Chrome
3. **No Firefox/Edge**: Would require additional extensions
4. **Incognito Mode**: Extensions can work in incognito if user enables; ManagedSettings shield works regardless
5. **VPN/Proxy**: Users can bypass via VPN; not addressable at app level
6. **Other Browsers**: Brave, Arc, etc. need their own solutions

---

## 13. Implementation Phases

### Phase 1: Native App + Safari (Weeks 1-4)

**Goal**: Website blocking in Safari using ManagedSettings

1. **Week 1**: Core infrastructure
   - Create `WebDomainBlockingService.swift`
   - Update `RestrictionModels.swift`
   - Update `AppLimitController+Restrictions.swift`
   - Update `DeviceActivityMonitorExtension.swift`

2. **Week 2**: Safari Web Extension
   - Create extension target in Xcode
   - Implement `manifest.json` and `background.js`
   - Create blocked page UI
   - Implement native messaging handler

3. **Week 3**: UI & Integration
   - Create `WebDomainsSettingsView.swift`
   - Integrate with existing restriction window UI
   - Add domain picker/management UI

4. **Week 4**: Testing & Polish
   - Test all blocking scenarios
   - Test override/lift functionality
   - Test focus sessions
   - Edge cases (midnight crossing, multiple windows)

### Phase 2: Chrome Extension (Weeks 5-7)

**Goal**: Website blocking in Chrome via native messaging

1. **Week 5**: Chrome Extension
   - Create extension project
   - Implement `manifest.json` (Manifest V3)
   - Implement `background.js` with `declarativeNetRequest`
   - Create blocked page UI

2. **Week 6**: Native Messaging Host
   - Create native messaging host executable
   - Implement message protocol
   - Create host manifest file
   - Test communication

3. **Week 7**: Integration & Testing
   - Test Chrome extension with native app
   - Test domain sync
   - Test edge cases

### Phase 3: Polish & Release (Weeks 8-10)

1. **Week 8**: User Experience
   - Polish UI/UX
   - Add setup guides
   - Create onboarding flow

2. **Week 9**: Testing
   - Comprehensive testing
   - Beta testing with users
   - Bug fixes

3. **Week 10**: Release Prep
   - Request Family Controls entitlement
   - Prepare App Store submission
   - Create Chrome Web Store listing (optional)
   - Documentation

---

## Appendix A: Sample Domain Lists

### Common Distracting Websites

```swift
let commonDistractingDomains = [
    // Social Media
    "facebook.com",
    "instagram.com",
    "twitter.com",
    "x.com",
    "tiktok.com",
    "snapchat.com",
    "linkedin.com",
    "reddit.com",
    
    // Video/Entertainment
    "youtube.com",
    "netflix.com",
    "twitch.tv",
    "tumblr.com",
    
    // News
    "cnn.com",
    "bbc.com",
    "nytimes.com",
    
    // Other
    "pinterest.com",
    "quora.com",
    "buzzfeed.com"
]
```

---

## Appendix B: Blocked Page HTML Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Website Blocked - Ambidash</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        
        .container {
            text-align: center;
            padding: 3rem;
            max-width: 600px;
        }
        
        .icon {
            font-size: 5rem;
            margin-bottom: 1.5rem;
        }
        
        h1 {
            font-size: 2rem;
            margin-bottom: 1rem;
        }
        
        .domain {
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 2rem;
            padding: 0.5rem 1rem;
            background: rgba(255,255,255,0.2);
            border-radius: 8px;
            display: inline-block;
        }
        
        p {
            font-size: 1.1rem;
            opacity: 0.8;
            line-height: 1.6;
            margin-bottom: 2rem;
        }
        
        .timer {
            font-size: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .button {
            display: inline-block;
            padding: 0.8rem 2rem;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 25px;
            font-weight: 600;
            transition: transform 0.2s;
        }
        
        .button:hover {
            transform: scale(1.05);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🎯</div>
        <h1>Website Blocked</h1>
        <div class="domain" id="domain">facebook.com</div>
        <p>This website is blocked during your focus session. Stay focused on what matters!</p>
        <div class="timer" id="timer"></div>
        <a href="javascript:history.back()" class="button">Go Back</a>
    </div>
    
    <script>
        // Get domain from URL
        const urlParams = new URLSearchParams(window.location.search);
        const domain = urlParams.get('domain') || 'this website';
        document.getElementById('domain').textContent = domain;
        
        // Update timer
        function updateTimer() {
            chrome.storage.local.get(['focusEndsAt'], (result) => {
                if (result.focusEndsAt) {
                    const now = Date.now() / 1000;
                    const remaining = result.focusEndsAt - now;
                    
                    if (remaining > 0) {
                        const hours = Math.floor(remaining / 3600);
                        const minutes = Math.floor((remaining % 3600) / 60);
                        const seconds = Math.floor(remaining % 60);
                        
                        let timeStr = '';
                        if (hours > 0) timeStr += `${hours}h `;
                        timeStr += `${minutes}m ${seconds}s`;
                        
                        document.getElementById('timer').textContent = `Time remaining: ${timeStr}`;
                    } else {
                        document.getElementById('timer').textContent = 'Focus session ended';
                    }
                }
            });
        }
        
        updateTimer();
        setInterval(updateTimer, 1000);
    </script>
</body>
</html>
```

---

## Appendix C: Testing Checklist

### Functional Testing

- [ ] Add domain to block list
- [ ] Remove domain from block list
- [ ] Start focus session with web domains
- [ ] End focus session clears web domain blocks
- [ ] Restriction window with web domains activates on schedule
- [ ] Restriction window with web domains deactivates on schedule
- [ ] Override temporarily lifts web domain blocks
- [ ] Override expires and blocks resume
- [ ] Multiple restriction windows with different domains
- [ ] Midnight-crossing windows work correctly

### Browser Testing

- [ ] Safari: Domain blocked with shield overlay
- [ ] Safari: Blocked page shows for direct navigation
- [ ] Chrome: Domain blocked with redirect to blocked page
- [ ] Chrome: Extension popup shows correct status
- [ ] Both: Domain list syncs within 10 seconds
- [ ] Both: Override works in both browsers
- [ ] Both: Focus session end clears blocks in both

### Edge Cases

- [ ] Empty domain list
- [ ] Invalid domain format
- [ ] Domain with subdomain (e.g., m.facebook.com)
- [ ] Domain with path (e.g., facebook.com/messages)
- [ ] International domain names
- [ ] App restart preserves state
- [ ] Extension disabled/re-enabled
- [ ] Multiple browser windows open
- [ ] Incognito/private browsing

---

**Document Version**: 1.0
**Last Updated**: June 2026
**Author**: Technical Research & Planning