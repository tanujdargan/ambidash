// options.js — Ambidash Website Blocker options page logic

(function () {
  'use strict';

  let currentDomains = [];

  // ─── DOM Elements ────────────────────────────────────────────────────────

  const domainInput = document.getElementById('domain-input');
  const btnAdd = document.getElementById('btn-add');
  const domainList = document.getElementById('domain-list');
  const domainError = document.getElementById('domain-error');
  const importExportText = document.getElementById('import-export-text');
  const btnImport = document.getElementById('btn-import');
  const btnExport = document.getElementById('btn-export');
  const btnClearAll = document.getElementById('btn-clear-all');
  const toggleNative = document.getElementById('toggle-native');
  const hostPath = document.getElementById('host-path');
  const syncInterval = document.getElementById('sync-interval');
  const btnSave = document.getElementById('btn-save');
  const toast = document.getElementById('toast');

  // ─── Helpers ─────────────────────────────────────────────────────────────

  function normalizeDomain(input) {
    let domain = input.toLowerCase().trim();
    // Remove protocol
    domain = domain.replace(/^https?:\/\//, '');
    // Remove www.
    domain = domain.replace(/^www\./, '');
    // Remove trailing slash and path
    domain = domain.replace(/\/.*$/, '');
    // Remove port
    domain = domain.replace(/:\d+$/, '');
    return domain;
  }

  function isValidDomain(domain) {
    // Basic domain validation
    if (!domain || domain.length === 0) return false;
    if (domain.length > 253) return false;
    // Must contain at least one dot, and valid characters
    const domainRegex = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$/;
    return domainRegex.test(domain);
  }

  function showToast(message, duration = 2500) {
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), duration);
  }

  function showError(message) {
    domainError.textContent = message;
    domainError.style.display = 'block';
    setTimeout(() => { domainError.style.display = 'none'; }, 4000);
  }

  // ─── Domain List Rendering ───────────────────────────────────────────────

  function renderDomainList() {
    if (currentDomains.length === 0) {
      domainList.innerHTML = '<li class="empty">No domains configured yet</li>';
      return;
    }

    const sorted = [...currentDomains].sort();
    domainList.innerHTML = sorted.map(domain => `
      <li>
        <span class="domain-name">${escapeHtml(domain)}</span>
        <button class="btn-remove" data-domain="${escapeHtml(domain)}" title="Remove" type="button">&times;</button>
      </li>
    `).join('');

    // Attach remove handlers
    domainList.querySelectorAll('.btn-remove').forEach(btn => {
      btn.addEventListener('click', () => {
        const domain = btn.getAttribute('data-domain');
        removeDomain(domain);
      });
    });
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // ─── Domain Operations ───────────────────────────────────────────────────

  function addDomain(raw) {
    const domain = normalizeDomain(raw);

    if (!domain) {
      showError('Please enter a domain');
      return false;
    }

    if (!isValidDomain(domain)) {
      showError('Invalid domain format. Use "example.com"');
      return false;
    }

    if (currentDomains.includes(domain)) {
      showError('Domain already in list');
      return false;
    }

    currentDomains.push(domain);
    currentDomains.sort();
    renderDomainList();
    domainInput.value = '';
    domainError.style.display = 'none';
    return true;
  }

  function removeDomain(domain) {
    currentDomains = currentDomains.filter(d => d !== domain);
    renderDomainList();
  }

  // ─── Load Settings ───────────────────────────────────────────────────────

  async function loadSettings() {
    try {
      const data = await new Promise((resolve) => {
        chrome.runtime.sendMessage({ type: 'getOptions' }, (res) => {
          if (chrome.runtime.lastError) {
            resolve({});
          } else {
            resolve(res || {});
          }
        });
      });

      currentDomains = data.blockedDomains || [];
      toggleNative.checked = data.useNativeHost !== false;
      hostPath.value = data.nativeHostPath || '';
      syncInterval.value = data.syncInterval || 6;

      renderDomainList();
    } catch (err) {
      console.error('Failed to load settings:', err);
      // Try reading directly from storage
      try {
        const data = await chrome.storage.local.get([
          'blockedDomains', 'useNativeHost', 'nativeHostPath', 'syncInterval'
        ]);
        currentDomains = data.blockedDomains || [];
        toggleNative.checked = data.useNativeHost !== false;
        hostPath.value = data.nativeHostPath || '';
        syncInterval.value = data.syncInterval || 6;
        renderDomainList();
      } catch (err2) {
        console.error('Direct storage access also failed:', err2);
      }
    }
  }

  // ─── Save Settings ───────────────────────────────────────────────────────

  async function saveSettings() {
    const interval = Math.max(2, Math.min(60, parseInt(syncInterval.value, 10) || 6));

    try {
      await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({
          type: 'saveOptions',
          blockedDomains: currentDomains,
          useNativeHost: toggleNative.checked,
          nativeHostPath: hostPath.value.trim(),
          syncInterval: interval
        }, (res) => {
          if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
          else resolve(res);
        });
      });

      syncInterval.value = interval;
      showToast('Settings saved ✓');
    } catch (err) {
      console.error('Failed to save settings:', err);
      showToast('Failed to save settings');
    }
  }

  // ─── Import / Export ─────────────────────────────────────────────────────

  function importDomains() {
    const text = importExportText.value.trim();
    if (!text) {
      showToast('Paste domains into the text area first');
      return;
    }

    const lines = text.split(/[\n,;]+/).map(l => l.trim()).filter(l => l.length > 0);
    let added = 0;
    let skipped = 0;
    let invalid = 0;

    for (const line of lines) {
      const domain = normalizeDomain(line);
      if (!isValidDomain(domain)) {
        invalid++;
        continue;
      }
      if (currentDomains.includes(domain)) {
        skipped++;
        continue;
      }
      currentDomains.push(domain);
      added++;
    }

    currentDomains.sort();
    renderDomainList();

    const parts = [];
    if (added > 0) parts.push(`${added} added`);
    if (skipped > 0) parts.push(`${skipped} already existed`);
    if (invalid > 0) parts.push(`${invalid} invalid`);

    showToast(parts.length > 0 ? parts.join(', ') : 'No valid domains found');
    if (added > 0) importExportText.value = '';
  }

  function exportDomains() {
    if (currentDomains.length === 0) {
      importExportText.value = '';
      showToast('No domains to export');
      return;
    }

    importExportText.value = currentDomains.sort().join('\n');
    importExportText.select();
    showToast(`${currentDomains.length} domains exported`);
  }

  function clearAllDomains() {
    if (currentDomains.length === 0) return;
    if (!confirm(`Remove all ${currentDomains.length} domains?`)) return;

    currentDomains = [];
    renderDomainList();
    showToast('All domains cleared');
  }

  // ─── Event Handlers ──────────────────────────────────────────────────────

  btnAdd.addEventListener('click', () => {
    addDomain(domainInput.value);
  });

  domainInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addDomain(domainInput.value);
    }
  });

  // Clear error on input
  domainInput.addEventListener('input', () => {
    domainError.style.display = 'none';
  });

  btnImport.addEventListener('click', importDomains);
  btnExport.addEventListener('click', exportDomains);
  btnClearAll.addEventListener('click', clearAllDomains);
  btnSave.addEventListener('click', saveSettings);

  // ─── Init ────────────────────────────────────────────────────────────────

  loadSettings();
})();
