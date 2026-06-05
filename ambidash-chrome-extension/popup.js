// popup.js — Ambidash Website Blocker popup logic

(function () {
  'use strict';

  let timerInterval = null;
  let currentEndsAt = 0;

  // ─── DOM Elements ────────────────────────────────────────────────────────

  const loading = document.getElementById('loading');
  const content = document.getElementById('content');
  const statusBar = document.getElementById('status-bar');
  const statusDot = document.getElementById('status-dot');
  const statusText = document.getElementById('status-text');
  const sourceBadge = document.getElementById('source-badge');
  const timerValue = document.getElementById('timer-value');
  const timerLabel = document.getElementById('timer-label');
  const domainList = document.getElementById('domain-list');
  const toggleBlocking = document.getElementById('toggle-blocking');
  const btnRefresh = document.getElementById('btn-refresh');

  // ─── Helpers ─────────────────────────────────────────────────────────────

  function formatTime(ms) {
    const totalSeconds = Math.max(0, Math.floor(ms / 1000));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    if (hours > 0) {
      return `${hours}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  }

  // ─── Render ──────────────────────────────────────────────────────────────

  function render(status) {
    const { isActive, blockedDomains, remainingMs, focusEndsAt, source, nativeHostAvailable } = status;

    // Status bar
    if (isActive) {
      statusBar.className = 'status-bar active';
      statusDot.className = 'status-dot active';
      statusText.textContent = 'Focus session active';
    } else {
      statusBar.className = 'status-bar inactive';
      statusDot.className = 'status-dot inactive';
      statusText.textContent = 'No active focus session';
    }

    // Source badge
    if (nativeHostAvailable || source === 'native') {
      sourceBadge.className = 'source-badge native';
      sourceBadge.textContent = 'Connected';
    } else {
      sourceBadge.className = 'source-badge local';
      sourceBadge.textContent = 'Standalone';
    }

    // Timer
    currentEndsAt = focusEndsAt || 0;
    startTimer();

    // Domain list
    if (blockedDomains && blockedDomains.length > 0) {
      domainList.innerHTML = blockedDomains.map(d =>
        `<li>${escapeHtml(d)}</li>`
      ).join('');
    } else {
      domainList.innerHTML = '<li class="empty">No domains configured</li>';
    }

    // Toggle
    toggleBlocking.checked = isActive;

    // Show content
    loading.style.display = 'none';
    content.style.display = 'block';
  }

  function startTimer() {
    if (timerInterval) clearInterval(timerInterval);

    const update = () => {
      if (!currentEndsAt || currentEndsAt <= 0) {
        timerValue.textContent = '--:--';
        timerLabel.textContent = 'no active session';
        return;
      }

      const remaining = currentEndsAt - Date.now();
      if (remaining <= 0) {
        timerValue.textContent = '0:00';
        timerLabel.textContent = 'complete';
        clearInterval(timerInterval);
        return;
      }

      timerValue.textContent = formatTime(remaining);
      timerLabel.textContent = 'remaining';
    };

    update();
    timerInterval = setInterval(update, 1000);
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // ─── Load Status ─────────────────────────────────────────────────────────

  async function loadStatus() {
    try {
      const response = await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({ type: 'getStatus' }, (res) => {
          if (chrome.runtime.lastError) {
            reject(new Error(chrome.runtime.lastError.message));
          } else {
            resolve(res);
          }
        });
      });

      if (response && !response.error) {
        render(response);
      } else {
        showError('Could not load status');
      }
    } catch (err) {
      showError('Extension not ready');
    }
  }

  function showError(msg) {
    loading.textContent = msg;
    loading.style.color = '#e53e3e';
  }

  // ─── Event Handlers ──────────────────────────────────────────────────────

  toggleBlocking.addEventListener('change', async () => {
    toggleBlocking.disabled = true;
    try {
      await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({ type: 'toggleBlocking' }, (res) => {
          if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
          else resolve(res);
        });
      });
      await loadStatus();
    } catch (err) {
      console.error('Toggle failed:', err);
      toggleBlocking.checked = !toggleBlocking.checked;
    } finally {
      toggleBlocking.disabled = false;
    }
  });

  btnRefresh.addEventListener('click', async () => {
    btnRefresh.disabled = true;
    btnRefresh.textContent = '↻ ...';
    try {
      await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({ type: 'forceRefresh' }, (res) => {
          if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
          else resolve(res);
        });
      });
      await loadStatus();
    } catch (err) {
      console.error('Refresh failed:', err);
    } finally {
      btnRefresh.disabled = false;
      btnRefresh.textContent = '↻ Refresh';
    }
  });

  // Open Ambidash link
  document.getElementById('btn-app').addEventListener('click', (e) => {
    e.preventDefault();
    chrome.tabs.create({ url: 'https://ambidash.app' });
  });

  // ─── Cleanup ─────────────────────────────────────────────────────────────

  window.addEventListener('unload', () => {
    if (timerInterval) clearInterval(timerInterval);
  });

  // ─── Init ────────────────────────────────────────────────────────────────

  loadStatus();
})();
