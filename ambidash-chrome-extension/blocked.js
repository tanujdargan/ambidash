// blocked.js — Logic for the Ambidash blocked page

(function () {
  'use strict';

  const MOTIVATIONAL_MESSAGES = [
    "You're doing great by honoring your boundaries. Keep going! 💪",
    "Focus is a muscle — every time you resist, it gets stronger. 🧠",
    "The version of you on the other side of this session will be grateful. 🌟",
    "Small moments of discipline lead to massive results. You've got this! ✨",
    "This distraction will still be here later. Your goals won't wait. 🎯",
    "Breathe in focus, breathe out distraction. You're in control. 🌿",
    "Every minute you stay focused is a minute invested in yourself. 📈",
    "The hardest part is already done — you showed up. Keep going! 🚀",
    "Your future self is cheering you on right now. Don't stop. 💫",
    "Distractions are temporary. Your progress is permanent. 🏔️"
  ];

  const BREATHE_PHASES = [
    { text: 'Breathe in...', duration: 4000 },
    { text: 'Hold...', duration: 4000 },
    { text: 'Breathe out...', duration: 6000 },
    { text: 'Rest...', duration: 2000 }
  ];

  let timerInterval = null;
  let breatheTimeout = null;

  // ─── Get blocked domain from URL ──────────────────────────────────────────

  function getBlockedDomain() {
    const params = new URLSearchParams(window.location.search);
    return params.get('domain') || '';
  }

  // ─── Display domain ──────────────────────────────────────────────────────

  function displayDomain(domain) {
    const el = document.getElementById('domain-display');
    if (domain) {
      el.textContent = domain;
      el.style.display = 'inline-block';
    }
  }

  // ─── Random motivational message ─────────────────────────────────────────

  function showMotivationalMessage() {
    const el = document.getElementById('motivational');
    const index = Math.floor(Math.random() * MOTIVATIONAL_MESSAGES.length);
    el.textContent = MOTIVATIONAL_MESSAGES[index];
  }

  // ─── Timer display ───────────────────────────────────────────────────────

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

  function startTimer(focusEndsAt) {
    const timerSection = document.getElementById('timer-section');
    const timerDisplay = document.getElementById('timer-display');
    const progressFill = document.getElementById('progress-fill');
    const progressLabel = document.getElementById('progress-label');

    if (!focusEndsAt || focusEndsAt <= 0) {
      timerSection.style.display = 'block';
      timerDisplay.textContent = 'Active';
      timerDisplay.classList.add('no-session');
      return;
    }

    timerSection.style.display = 'block';

    // We don't know the exact start time, but we can estimate
    // Just show remaining time and a simple countdown
    const update = () => {
      const remaining = focusEndsAt - Date.now();

      if (remaining <= 0) {
        timerDisplay.textContent = '0:00';
        progressFill.style.width = '100%';
        progressLabel.textContent = 'Session complete!';
        if (timerInterval) clearInterval(timerInterval);

        // After a moment, the blocking should auto-clear via background sync
        setTimeout(() => {
          progressLabel.textContent = 'Wrapping up...';
        }, 2000);
        return;
      }

      timerDisplay.textContent = formatTime(remaining);
    };

    update();
    timerInterval = setInterval(update, 1000);
  }

  // ─── Breathing exercise ──────────────────────────────────────────────────

  function initBreatheExercise() {
    const btn = document.getElementById('btn-breathe');
    const motivational = document.getElementById('motivational');
    let breathing = false;

    btn.addEventListener('click', () => {
      if (breathing) {
        stopBreathing();
        return;
      }

      breathing = true;
      btn.textContent = 'Stop ✋';
      runBreatheCycle(motivational, 0, () => {
        breathing = false;
        btn.textContent = 'Take a breath 🌿';
        showMotivationalMessage();
      });
    });
  }

  function runBreatheCycle(element, phaseIndex, onComplete) {
    if (phaseIndex >= BREATHE_PHASES.length) {
      onComplete();
      return;
    }

    const phase = BREATHE_PHASES[phaseIndex];
    element.textContent = phase.text;
    element.style.transition = 'transform 2s ease';
    element.style.transform = phaseIndex === 1 ? 'scale(1.05)' : 'scale(1)';

    breatheTimeout = setTimeout(() => {
      element.style.transform = 'scale(1)';
      runBreatheCycle(element, phaseIndex + 1, onComplete);
    }, phase.duration);
  }

  function stopBreathing() {
    if (breatheTimeout) {
      clearTimeout(breatheTimeout);
      breatheTimeout = null;
    }
  }

  // ─── Initialize ──────────────────────────────────────────────────────────

  async function init() {
    const domain = getBlockedDomain();
    displayDomain(domain);
    showMotivationalMessage();
    initBreatheExercise();

    // Get focus session info from background
    try {
      const response = await new Promise((resolve) => {
        chrome.runtime.sendMessage({ type: 'getStatus' }, (res) => {
          if (chrome.runtime.lastError) {
            resolve(null);
          } else {
            resolve(res);
          }
        });
      });

      if (response && response.focusEndsAt && response.focusEndsAt > 0) {
        startTimer(response.focusEndsAt);
      } else {
        const timerSection = document.getElementById('timer-section');
        timerSection.style.display = 'block';
        document.getElementById('timer-display').textContent = 'Active';
        document.getElementById('timer-display').classList.add('no-session');
      }
    } catch (err) {
      console.log('Could not get session info:', err);
      const timerSection = document.getElementById('timer-section');
      timerSection.style.display = 'block';
      document.getElementById('timer-display').textContent = 'Active';
      document.getElementById('timer-display').classList.add('no-session');
    }
  }

  // Cleanup on unload
  window.addEventListener('unload', () => {
    if (timerInterval) clearInterval(timerInterval);
    stopBreathing();
  });

  // Start
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
