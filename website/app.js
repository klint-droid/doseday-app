/**
 * DoseDay Website Logic — Tarsi & GCash UI Edition
 * - Interactive Tarsi Mobile UI Replica (Quick Actions, Day/Week/Month Bento toggle, Doses Due check-off)
 * - "Talk to Tarsi • DoseDay" Natural Language Parser Demo
 * - Interactive Notification Action Simulator (Take / Snooze 10m / Skip + 44.1kHz Chime)
 * - Monday-to-Sunday 7-Day Week Simulator
 * - Light/Dark Theme Switcher & QR Code Renderer
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Theme Management (Default to Tarsi Crisp Light Sage Mode)
  const themeBtn = document.getElementById('theme-toggle');
  const savedTheme = localStorage.getItem('doseday_tarsi_theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcon(savedTheme);

  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'light';
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('doseday_tarsi_theme', next);
      updateThemeIcon(next);
    });
  }

  function updateThemeIcon(theme) {
    if (!themeBtn) return;
    themeBtn.innerHTML = theme === 'dark'
      ? `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`
      : `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`;
  }

  // 2. Audio Chime Playback
  const chimeAudio = new Audio('assets/reminder_sound.wav');
  function playChime() {
    chimeAudio.currentTime = 0;
    chimeAudio.play().catch(() => {});
  }

  document.querySelectorAll('.js-play-chime').forEach(btn => {
    btn.addEventListener('click', playChime);
  });

  // 3. Interactive Tarsi Mobile Phone Replica in Hero
  const assistantMsg = document.getElementById('phone-assistant-msg');
  document.querySelectorAll('.js-phone-quick').forEach(item => {
    item.addEventListener('click', () => {
      const msg = item.getAttribute('data-msg');
      if (assistantMsg && msg) {
        assistantMsg.textContent = msg;
      }
    });
  });

  // Period Toggle (Day / Week / Month) inside Phone Replica
  const periodPills = document.querySelectorAll('.period-pill');
  const periodTitle = document.getElementById('phone-period-title');
  const trendUp = document.getElementById('phone-trend-up');
  const trendDown = document.getElementById('phone-trend-down');

  periodPills.forEach(pill => {
    pill.addEventListener('click', () => {
      periodPills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      const p = pill.getAttribute('data-period');
      if (periodTitle) {
        periodTitle.textContent = p === 'Day' ? 'Today' : (p === 'Week' ? 'This Week' : 'This Month');
      }
      if (trendUp) trendUp.textContent = pill.getAttribute('data-up') || '';
      if (trendDown) trendDown.textContent = pill.getAttribute('data-down') || '';
    });
  });

  // Doses Due Row Check-off inside Phone Replica
  const phoneDoseRows = document.querySelectorAll('.js-phone-dose-row');
  const phoneDueCount = document.getElementById('phone-due-count');
  phoneDoseRows.forEach(row => {
    row.addEventListener('click', () => {
      const isTaken = row.classList.toggle('taken');
      const chip = row.querySelector('.due-chip');
      const tag = row.querySelector('.due-tag');
      if (isTaken) {
        if (chip) {
          chip.textContent = 'Completed ✓';
          chip.className = 'due-chip taken-chip';
        }
        if (tag) tag.textContent = 'TAKEN ✓';
        playChime();
      } else {
        if (chip) {
          chip.textContent = 'Scheduled';
          chip.className = 'due-chip';
        }
        if (tag) tag.textContent = '1 TAB • DUE';
      }
      const remaining = document.querySelectorAll('.js-phone-dose-row:not(.taken)').length;
      if (phoneDueCount) phoneDueCount.textContent = `${remaining} Left`;
      if (assistantMsg) {
        assistantMsg.textContent = remaining === 0
          ? '🎉 All doses completed for today! Your health streak is now 8 days!'
          : `Great job! You have ${remaining} medication dose(s) remaining today.`;
      }
    });
  });

  document.querySelectorAll('.js-trigger-phone-notif').forEach(btn => {
    btn.addEventListener('click', () => {
      playChime();
      if (assistantMsg) {
        assistantMsg.textContent = '🔔 Smart Exact Alarm tested! Audible 44.1kHz chime & Take/Snooze buttons active.';
      }
    });
  });

  // 4. "Talk to Tarsi • DoseDay" Natural Language Parser Demo
  const nlpInput = document.getElementById('nlp-demo-input');
  const nlpBtn = document.getElementById('nlp-parse-btn');
  const parsedName = document.getElementById('parsed-med-name');
  const parsedDose = document.getElementById('parsed-med-dose');
  const parsedTime = document.getElementById('parsed-med-time');

  function runNlpParse(raw) {
    if (!raw) return;
    let timeStr = '08:00 AM';
    const timeMatch = raw.match(/(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)/);
    if (timeMatch && (raw.toLowerCase().includes('am') || raw.toLowerCase().includes('pm') || raw.includes(':'))) {
      timeStr = timeMatch[1].toUpperCase();
    }

    let doseStr = '1 tablet';
    const doseMatch = raw.match(/(\d+\s*(?:mg|mL|IU|tab|tablet|cap|capsule)s?)/i);
    if (doseMatch) {
      doseStr = doseMatch[1];
    }

    let nameStr = raw
      .replace(/at\s+\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?/i, '')
      .replace(/\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?/i, '')
      .replace(/\d+\s*(?:mg|mL|IU|tab|tablet|cap|capsule)s?/i, '')
      .trim();
    if (!nameStr) nameStr = 'Daily Medication';

    if (parsedName) parsedName.textContent = nameStr;
    if (parsedDose) parsedDose.textContent = doseStr;
    if (parsedTime) parsedTime.textContent = timeStr;
  }

  if (nlpBtn && nlpInput) {
    nlpBtn.addEventListener('click', () => {
      runNlpParse(nlpInput.value);
      playChime();
    });
  }

  document.querySelectorAll('.nlp-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      const text = chip.getAttribute('data-text') || '';
      if (nlpInput) nlpInput.value = text;
      runNlpParse(text);
    });
  });

  // 5. Interactive Notification Action Simulator
  const notifFeedback = document.getElementById('sim-notif-feedback');
  document.querySelectorAll('.js-notif-sim-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.getAttribute('data-action');
      playChime();
      if (!notifFeedback) return;
      if (action === 'taken') {
        notifFeedback.textContent = '✓ Dose recorded as Taken in SQLite! Stock deducted (29 → 28 capsules).';
      } else if (action === 'snoozed') {
        notifFeedback.textContent = '⏰ Exact alarm snoozed! Will ring again in 10 minutes even if screen is locked.';
      } else {
        notifFeedback.textContent = '✕ Dose marked as Skipped for 08:00 AM. No stock deducted.';
      }
    });
  });

  // 6. Interactive Monday-to-Sunday Week Simulator
  let simWeekOffset = 0;
  let simSelectedDate = new Date();
  const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  function getMonday(d, offsetWeeks = 0) {
    const date = new Date(d);
    const day = date.getDay();
    const diff = date.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(date.setDate(diff));
    monday.setDate(monday.getDate() + offsetWeeks * 7);
    monday.setHours(0, 0, 0, 0);
    return monday;
  }

  function renderSimStrip() {
    const stripEl = document.getElementById('sim-week-strip');
    const rangeEl = document.getElementById('sim-week-range');
    if (!stripEl || !rangeEl) return;

    const monday = getMonday(new Date(), simWeekOffset);
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);

    rangeEl.textContent = `${monday.getDate()} ${monthsShort[monday.getMonth()]} – ${sunday.getDate()} ${monthsShort[sunday.getMonth()]}, ${sunday.getFullYear()}`;

    stripEl.innerHTML = '';
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    for (let i = 0; i < 7; i++) {
      const dayDate = new Date(monday);
      dayDate.setDate(monday.getDate() + i);

      const isSelected = dayDate.toDateString() === simSelectedDate.toDateString();
      const isToday = dayDate.toDateString() === today.toDateString();

      const card = document.createElement('div');
      card.className = `sim-day-card ${isSelected ? 'active' : ''}`;
      card.innerHTML = `
        <div class="sim-day-month">${monthsShort[dayDate.getMonth()]}</div>
        <div class="sim-day-num">${dayDate.getDate()}</div>
        <div class="sim-day-name">${daysShort[i]}</div>
        ${isToday && !isSelected ? '<div style="width:4px;height:4px;background:var(--primary);border-radius:50%;margin:2px auto 0;"></div>' : ''}
      `;

      card.addEventListener('click', () => {
        simSelectedDate = dayDate;
        renderSimStrip();
      });

      stripEl.appendChild(card);
    }
  }

  const prevWeekBtn = document.getElementById('sim-prev-week');
  const nextWeekBtn = document.getElementById('sim-next-week');
  const todayBtn = document.getElementById('sim-today-btn');

  if (prevWeekBtn) prevWeekBtn.addEventListener('click', () => { simWeekOffset--; renderSimStrip(); });
  if (nextWeekBtn) nextWeekBtn.addEventListener('click', () => { simWeekOffset++; renderSimStrip(); });
  if (todayBtn) todayBtn.addEventListener('click', () => { simWeekOffset = 0; simSelectedDate = new Date(); renderSimStrip(); });

  renderSimStrip();

  // 7. Simulator Dose Check-off Interaction
  document.querySelectorAll('.js-sim-check').forEach(btn => {
    btn.addEventListener('click', () => {
      const isTaken = btn.classList.toggle('taken');
      btn.textContent = isTaken ? '✓ Taken' : 'Take Dose';
      if (isTaken) playChime();
    });
  });

  // 8. FAQ Accordion
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const q = item.querySelector('.faq-question');
    if (q) {
      q.addEventListener('click', () => {
        const isOpen = item.classList.contains('open');
        faqItems.forEach(i => i.classList.remove('open'));
        if (!isOpen) item.classList.add('open');
      });
    }
  });

  // 9. QR Code Canvas Rendering
  const qrCanvas = document.getElementById('qr-canvas');
  if (qrCanvas) {
    const ctx = qrCanvas.getContext('2d');
    const size = 156;
    qrCanvas.width = size;
    qrCanvas.height = size;

    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, size, size);

    ctx.fillStyle = '#1B4332';
    const matrix = [
      [1,1,1,1,1,1,1,0,1,0,1,1,1,1,1,1,1],
      [1,0,0,0,0,0,1,0,0,1,1,0,0,0,0,0,1],
      [1,0,1,1,1,0,1,0,1,0,1,0,1,1,1,0,1],
      [1,0,1,1,1,0,1,0,0,1,1,0,1,1,1,0,1],
      [1,0,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1],
      [1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1],
      [1,1,1,1,1,1,1,0,1,0,1,1,1,1,1,1,1],
      [0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
      [1,1,0,1,0,1,1,1,0,1,0,1,0,1,1,0,1],
      [0,0,1,0,1,0,0,1,1,0,1,0,1,0,0,1,0],
      [1,1,1,1,1,1,1,0,1,1,1,0,1,1,0,1,1],
      [1,0,0,0,0,0,1,0,0,1,0,1,0,0,1,0,1],
      [1,0,1,1,1,0,1,0,1,0,1,0,1,1,0,1,0],
      [1,0,1,1,1,0,1,0,0,1,0,1,1,0,1,1,1],
      [1,0,1,1,1,0,1,0,1,1,1,0,0,1,0,0,1],
      [1,0,0,0,0,0,1,0,0,0,1,1,1,0,1,0,1],
      [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1]
    ];

    const cellSize = size / matrix.length;
    for (let r = 0; r < matrix.length; r++) {
      for (let c = 0; c < matrix[r].length; c++) {
        if (matrix[r][c] === 1) {
          ctx.beginPath();
          ctx.arc(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2, cellSize / 2.2, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }
  }
});
