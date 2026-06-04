// background.js — Ambidash Website Blocker Service Worker
// Handles native messaging, blocking rules, and focus session management.

const NATIVE_HOST_NAME = 'ambidash.blocker';
const CHECK_ALARM_NAME = 'ambidash_checkDomains';
const SYNC_ALARM_NAME = 'ambidash_syncStatus';
const DEFAULT_CHECK_INTERVAL_SECONDS = 6;
const APP_GROUP_KEYS = {
  blockedDomains: 'applimits.ag.blockedWebDomains',
  isBlockingActive: 'applimits.ag.isWebBlockingActive',
  focusEndsAt: 'applimits.ag.focusEndsAt',
  overrideUntil: 'applimits.ag.overrideUntil'
};

// Track connection state
let nativePort = null;
let nativeHostAvailable = false;
let lastDomainsHash = '';

// ─── Initialization ───────────────────────────────────────────────────────────

chrome.runtime.onInstalled.addListener(async () => {
  console.log('[Ambidash] Extension installed');
  await initializeDefaults();
  setupAlarms();
  connectNativeHost();
});

chrome.runtime.onStartup.addListener(async () => {
  console.log('[Ambidash] Extension started');
  setupAlarms();
  connectNativeHost();
});

async function initializeDefaults() {
  const stored = await chrome.storage.local.get([
    'blockedDomains', 'isActive', 'focusEndsAt', 'syncInterval', 'useNativeHost'
  ]);
  const defaults = {};
  if (!stored.blockedDomains) defaults.blockedDomains = [];
  if (stored.isActive === undefined) defaults.isActive = false;
  if (!stored.focusEndsAt) defaults.focusEndsAt = 0;
  if (!stored.syncInterval) defaults.syncInterval = DEFAULT_CHECK_INTERVAL_SECONDS;
  if (stored.useNativeHost === undefined) defaults.useNativeHost = true;
  if (Object.keys(defaults).length > 0) {
    await chrome.storage.local.set(defaults);
  }
}

// ─── Alarms ───────────────────────────────────────────────────────────────────

function setupAlarms() {
  chrome.alarms.create(CHECK_ALARM_NAME, {
    delayInSeconds: 1,
    periodInSeconds: DEFAULT_CHECK_INTERVAL_SECONDS
  });
  chrome.alarms.create(SYNC_ALARM_NAME, {
    delayInSeconds: 1,
    periodInSeconds: 1
  });
}

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === CHECK_ALARM_NAME) {
    await checkForDomainUpdates();
  } else if (alarm.name === SYNC_ALARM_NAME) {
    await syncFocusTimer();
  }
});

// ─── Native Messaging ─────────────────────────────────────────────────────────

function connectNativeHost() {
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);

    nativePort.onMessage.addListener(async (message) => {
      console.log('[Ambidash] Native host message:', message);
      nativeHostAvailable = true;
      await handleNativeMessage(message);
    });

    nativePort.onDisconnect.addListener(() => {
      const error = chrome.runtime.lastError;
      console.log('[Ambidash] Native host disconnected:', error ? error.message : 'unknown');
      nativePort = null;
      nativeHostAvailable = false;
    });

    console.log('[Ambidash] Connected to native host');
  } catch (err) {
    console.log('[Ambidash] Native host not available:', err.message);
    nativePort = null;
    nativeHostAvailable = false;
  }
}

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

async function handleNativeMessage(message) {
  if (!message || typeof message !== 'object') return;

  if (message.type === 'updateDomains' || message.blockedDomains !== undefined) {
    const domains = message.blockedDomains || [];
    const isActive = message.isActive !== undefined ? message.isActive : true;
    const focusEndsAt = message.focusEndsAt || 0;

    await chrome.storage.local.set({
      blockedDomains: domains,
      isActive: isActive,
      focusEndsAt: focusEndsAt,
      lastUpdate: Date.now(),
      source: 'native'
    });

    await updateBlockingRules(domains, isActive);
  } else if (message.type === 'focusStarted') {
    await chrome.storage.local.set({
      isActive: true,
      focusEndsAt: message.focusEndsAt || 0,
      lastUpdate: Date.now()
    });
    await refreshRulesFromStorage();
  } else if (message.type === 'focusStopped') {
    await chrome.storage.local.set({
      isActive: false,
      focusEndsAt: 0,
      lastUpdate: Date.now()
    });
    await updateBlockingRules([], false);
  }
}

// ─── Domain Update Checking ───────────────────────────────────────────────────

async function checkForDomainUpdates() {
  const { useNativeHost } = await chrome.storage.local.get('useNativeHost');

  if (useNativeHost !== false) {
    try {
      const response = await sendNativeMessage({ type: 'getStatus' });
      if (response && response.blockedDomains) {
        nativeHostAvailable = true;
        await chrome.storage.local.set({
          blockedDomains: response.blockedDomains,
          isActive: response.isActive || false,
          focusEndsAt: response.focusEndsAt || 0,
          lastUpdate: Date.now(),
          source: 'native'
        });
        await updateBlockingRules(response.blockedDomains, response.isActive || false);
        return;
      }
    } catch (err) {
      nativeHostAvailable = false;
      console.log('[Ambidash] Native host unavailable, using cached data');
    }
  }

  // Fallback: use locally stored data
  await refreshRulesFromStorage();
}

async function refreshRulesFromStorage() {
  const stored = await chrome.storage.local.get(['blockedDomains', 'isActive', 'focusEndsAt']);

  // Check if focus session has expired
  if (stored.isActive && stored.focusEndsAt && stored.focusEndsAt > 0) {
    if (Date.now() > stored.focusEndsAt) {
      await chrome.storage.local.set({ isActive: false, focusEndsAt: 0 });
      await updateBlockingRules([], false);
      return;
    }
  }

  await updateBlockingRules(
    stored.blockedDomains || [],
    stored.isActive || false
  );
}

// ─── Declarative Net Request Rules ────────────────────────────────────────────

async function updateBlockingRules(domains, isActive) {
  const domainsHash = JSON.stringify({ domains: domains.sort(), isActive });

  // Skip if nothing changed
  if (domainsHash === lastDomainsHash) return;
  lastDomainsHash = domainsHash;

  const existingRules = await chrome.declarativeNetRequest.getDynamicRules();
  const existingIds = existingRules.map(r => r.id);

  if (!isActive || !domains || domains.length === 0) {
    if (existingIds.length > 0) {
      await chrome.declarativeNetRequest.updateDynamicRules({
        removeRuleIds: existingIds
      });
      console.log('[Ambidash] Cleared all blocking rules');
    }
    updateBadge(false, 0);
    return;
  }

  // Normalize domains: remove protocol, www prefix, trailing slashes
  const normalizedDomains = domains
    .map(d => d.toLowerCase().trim().replace(/^(https?:\/\/)?(www\.)?/, '').replace(/\/.*$/, ''))
    .filter(d => d.length > 0);

  // Build rules: one per domain, plus subdomain variants
  const newRules = [];
  let ruleId = 1;

  for (const domain of normalizedDomains) {
    // Rule for the domain itself and subdomains (||domain matches domain + *.domain)
    newRules.push({
      id: ruleId++,
      priority: 1,
      action: {
        type: 'redirect',
        redirect: {
          url: chrome.runtime.getURL('blocked.html') + '?domain=' + encodeURIComponent(domain)
        }
      },
      condition: {
        urlFilter: `||${domain}`,
        resourceTypes: ['main_frame']
      }
    });
  }

  if (newRules.length > 0) {
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: existingIds,
      addRules: newRules
    });
    console.log(`[Ambidash] Updated blocking rules for ${normalizedDomains.length} domains`);
  }

  updateBadge(isActive, normalizedDomains.length);
}

function updateBadge(isActive, count) {
  if (isActive && count > 0) {
    chrome.action.setBadgeText({ text: count.toString() });
    chrome.action.setBadgeBackgroundColor({ color: '#6B7FD7' });
  } else {
    chrome.action.setBadgeText({ text: '' });
  }
}

// ─── Focus Timer Sync ─────────────────────────────────────────────────────────

async function syncFocusTimer() {
  const stored = await chrome.storage.local.get(['isActive', 'focusEndsAt']);

  if (stored.isActive && stored.focusEndsAt && stored.focusEndsAt > 0) {
    if (Date.now() >= stored.focusEndsAt) {
      // Focus session ended
      await chrome.storage.local.set({ isActive: false, focusEndsAt: 0 });
      await updateBlockingRules([], false);
      console.log('[Ambidash] Focus session expired, blocking disabled');
    }
  }
}

// ─── Message Handling (from popup, options, blocked page) ─────────────────────

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const handler = async () => {
    switch (message.type) {
      case 'getStatus': {
        const stored = await chrome.storage.local.get([
          'blockedDomains', 'isActive', 'focusEndsAt', 'lastUpdate', 'source'
        ]);
        const remainingMs = (stored.focusEndsAt && stored.focusEndsAt > Date.now())
          ? stored.focusEndsAt - Date.now()
          : 0;
        return {
          blockedDomains: stored.blockedDomains || [],
          isActive: stored.isActive || false,
          focusEndsAt: stored.focusEndsAt || 0,
          remainingMs,
          lastUpdate: stored.lastUpdate || 0,
          source: stored.source || 'local',
          nativeHostAvailable
        };
      }

      case 'toggleBlocking': {
        const stored = await chrome.storage.local.get(['isActive', 'blockedDomains']);
        const newActive = !stored.isActive;
        await chrome.storage.local.set({ isActive: newActive });
        await updateBlockingRules(stored.blockedDomains || [], newActive);
        return { isActive: newActive };
      }

      case 'updateDomains': {
        const domains = message.domains || [];
        await chrome.storage.local.set({
          blockedDomains: domains,
          lastUpdate: Date.now(),
          source: 'manual'
        });
        const { isActive } = await chrome.storage.local.get('isActive');
        await updateBlockingRules(domains, isActive);
        return { success: true, count: domains.length };
      }

      case 'forceRefresh': {
        await checkForDomainUpdates();
        return { success: true };
      }

      case 'startFocus': {
        const endsAt = message.endsAt || (Date.now() + (message.durationMinutes || 25) * 60 * 1000);
        const domains = message.domains || [];
        await chrome.storage.local.set({
          isActive: true,
          focusEndsAt: endsAt,
          blockedDomains: domains,
          lastUpdate: Date.now()
        });
        await updateBlockingRules(domains, true);
        return { success: true, endsAt };
      }

      case 'stopFocus': {
        await chrome.storage.local.set({
          isActive: false,
          focusEndsAt: 0,
          lastUpdate: Date.now()
        });
        await updateBlockingRules([], false);
        return { success: true };
      }

      case 'getOptions': {
        return await chrome.storage.local.get([
          'syncInterval', 'useNativeHost', 'nativeHostPath', 'blockedDomains'
        ]);
      }

      case 'saveOptions': {
        const options = {};
        if (message.syncInterval !== undefined) options.syncInterval = message.syncInterval;
        if (message.useNativeHost !== undefined) options.useNativeHost = message.useNativeHost;
        if (message.nativeHostPath !== undefined) options.nativeHostPath = message.nativeHostPath;
        if (message.blockedDomains !== undefined) {
          options.blockedDomains = message.blockedDomains;
        }
        await chrome.storage.local.set(options);

        // Update alarm interval if changed
        if (message.syncInterval !== undefined) {
          chrome.alarms.create(CHECK_ALARM_NAME, {
            delayInSeconds: 1,
            periodInSeconds: message.syncInterval
          });
        }

        // If domains changed, update rules
        if (message.blockedDomains !== undefined) {
          const { isActive } = await chrome.storage.local.get('isActive');
          await updateBlockingRules(message.blockedDomains, isActive);
        }

        return { success: true };
      }

      default:
        return { error: 'Unknown message type' };
    }
  };

  handler().then(sendResponse).catch(err => {
    console.error('[Ambidash] Message handler error:', err);
    sendResponse({ error: err.message });
  });

  return true; // Keep channel open for async response
});

// ─── Tab Navigation Listener (for blocked page info) ──────────────────────────

chrome.webNavigation?.onBeforeNavigate?.addListener(async (details) => {
  // Only handle main frame navigations to our blocked page
  if (details.frameId !== 0) return;
  // blocked.html is handled by declarativeNetRequest redirect
});

console.log('[Ambidash] Service worker loaded');
