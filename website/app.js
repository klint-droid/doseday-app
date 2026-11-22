/**
 * DoseDay Website Logic
 * - Interactive Mobile UI Replica (Quick Actions, Day/Week/Month Bento toggle, Doses Due check-off)
 * - "Talk to DoseDay" Natural Language Parser Demo
 * - Interactive Notification Action Simulator (Take / Snooze 10m / Skip + 44.1kHz Chime)
 * - Monday-to-Sunday 7-Day Week Simulator
 * - Light/Dark Theme Switcher & QR Code Renderer
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Theme Management (Default to Crisp Light Sage Mode)
  const themeBtn = document.getElementById('theme-toggle');
  const savedTheme = localStorage.getItem('doseday_theme_v2') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcon(savedTheme);

  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'light';
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('doseday_theme_v2', next);
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

  // 3. Interactive Mobile Phone Replica in Hero
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

  // 4. "Talk to DoseDay" Natural Language Parser Demo
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

  // 9. Real Scannable ISO/IEC 18004 QR Code Rendering for APK Download
  const qrCanvas = document.getElementById('qr-canvas');
  if (qrCanvas) {
    const isLocal =
      window.location.protocol === 'file:' ||
      window.location.hostname === 'localhost' ||
      window.location.hostname === '127.0.0.1';

    // Use live domain APK URL when deployed, or public GitHub Release/Raw APK URL when previewing on localhost
    const apkDownloadUrl = isLocal
      ? 'https://github.com/klint-droid/doseday-app/raw/main/website/downloads/DoseDay.apk'
      : new URL('downloads/DoseDay.apk', window.location.href).href;

    const qrLink = document.getElementById('qr-download-link');
    if (qrLink) {
      qrLink.href = apkDownloadUrl;
    }

    const matrix = generateRealQrMatrix(apkDownloadUrl);
    renderQrMatrixToCanvas(qrCanvas, matrix, '#1B4332');
  }

  /**
   * Generates a real, scannable ISO/IEC 18004 QR Code matrix for `text`.
   * Uses `window.qrcode` if loaded, or falls back to the built-in offline ISO/IEC 18004 Byte-mode encoder.
   */
  function generateRealQrMatrix(text) {
    if (typeof window.qrcode === 'function') {
      try {
        const qr = window.qrcode(0, 'M');
        qr.addData(text);
        qr.make();
        const count = qr.getModuleCount();
        const mat = [];
        for (let r = 0; r < count; r++) {
          const row = [];
          for (let c = 0; c < count; c++) {
            row.push(qr.isDark(r, c) ? 1 : 0);
          }
          mat.push(row);
        }
        return mat;
      } catch (_) {}
    }
    return encodeIsoQrByteMode(text);
  }

  /**
   * Built-in 100% offline ISO/IEC 18004 QR Code encoder (Byte mode, ECC Level L, Versions 1-10)
   */
  function encodeIsoQrByteMode(str) {
    const utf8 = new TextEncoder().encode(str);
    // Version specs (ECC Level L): [totalDataBytes, ecBytesPerBlock, numBlocks, alignmentCenters]
    const VERSIONS = [
      null,
      [19, 7, 1, []],
      [34, 10, 1, [6, 18]],
      [55, 15, 1, [6, 22]],
      [80, 20, 1, [6, 26]],
      [108, 26, 1, [6, 30]],
      [136, 18, 2, [6, 34]],
      [156, 20, 2, [6, 22, 38]],
      [194, 24, 2, [6, 24, 42]],
      [232, 30, 2, [6, 26, 46]],
      [274, 18, 4, [6, 28, 50]]
    ];

    let ver = 1;
    while (ver <= 10) {
      const lenBits = ver <= 9 ? 8 : 16;
      const capBytes = VERSIONS[ver][0];
      if (4 + lenBits + utf8.length * 8 <= capBytes * 8) break;
      ver++;
    }
    if (ver > 10) ver = 10;

    const [totalData, ecPerBlock, numBlocks, alignPos] = VERSIONS[ver];
    const bits = [];
    const pushBits = (val, len) => {
      for (let i = len - 1; i >= 0; i--) bits.push((val >>> i) & 1);
    };

    // Byte mode indicator (0100) + character count
    pushBits(0b0100, 4);
    pushBits(utf8.length, ver <= 9 ? 8 : 16);
    for (let i = 0; i < utf8.length; i++) pushBits(utf8[i], 8);

    // Terminator & byte padding
    const maxBits = totalData * 8;
    pushBits(0, Math.min(4, maxBits - bits.length));
    while (bits.length % 8 !== 0) bits.push(0);

    const dataBytes = [];
    for (let i = 0; i < bits.length; i += 8) {
      let b = 0;
      for (let j = 0; j < 8; j++) b = (b << 1) | bits[i + j];
      dataBytes.push(b);
    }
    let padToggle = true;
    while (dataBytes.length < totalData) {
      dataBytes.push(padToggle ? 0xEC : 0x11);
      padToggle = !padToggle;
    }

    // GF(256) tables (primitive polynomial 0x11D)
    const EXP = new Uint8Array(512);
    const LOG = new Uint8Array(256);
    let x = 1;
    for (let i = 0; i < 255; i++) {
      EXP[i] = x;
      LOG[x] = i;
      x <<= 1;
      if (x & 0x100) x ^= 0x11D;
    }
    for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];

    const gfMul = (a, b) => (a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]]);
    const polyMul = (p, q) => {
      const r = new Uint8Array(p.length + q.length - 1);
      for (let i = 0; i < p.length; i++) {
        for (let j = 0; j < q.length; j++) {
          r[i + j] ^= gfMul(p[i], q[j]);
        }
      }
      return r;
    };

    let gen = new Uint8Array([1]);
    for (let i = 0; i < ecPerBlock; i++) {
      gen = polyMul(gen, new Uint8Array([1, EXP[i]]));
    }

    const rsEncode = (msg) => {
      const rem = new Uint8Array(msg.length + ecPerBlock);
      rem.set(msg, 0);
      for (let i = 0; i < msg.length; i++) {
        const coef = rem[i];
        if (coef !== 0) {
          for (let j = 1; j < gen.length; j++) {
            rem[i + j] ^= gfMul(gen[j], coef);
          }
        }
      }
      return rem.slice(msg.length);
    };

    // Split into blocks & compute Reed-Solomon EC
    const blockSize = Math.floor(totalData / numBlocks);
    const dataBlocks = [];
    const ecBlocks = [];
    let offset = 0;
    for (let b = 0; b < numBlocks; b++) {
      const blk = dataBytes.slice(offset, offset + blockSize);
      offset += blockSize;
      dataBlocks.push(blk);
      ecBlocks.push(rsEncode(blk));
    }

    const finalCodewords = [];
    for (let i = 0; i < blockSize; i++) {
      for (let b = 0; b < numBlocks; b++) finalCodewords.push(dataBlocks[b][i]);
    }
    for (let i = 0; i < ecPerBlock; i++) {
      for (let b = 0; b < numBlocks; b++) finalCodewords.push(ecBlocks[b][i]);
    }

    // Build QR Grid
    const size = ver * 4 + 17;
    const grid = Array.from({ length: size }, () => new Int8Array(size).fill(-1));
    const isFunc = Array.from({ length: size }, () => new Uint8Array(size));

    const setFunc = (r, c, val) => {
      if (r >= 0 && r < size && c >= 0 && c < size) {
        grid[r][c] = val ? 1 : 0;
        isFunc[r][c] = 1;
      }
    };

    const drawFinder = (r0, c0) => {
      for (let dr = -1; dr <= 7; dr++) {
        for (let dc = -1; dc <= 7; dc++) {
          const inOuter = dr >= 0 && dr <= 6 && dc >= 0 && dc <= 6;
          const onBorder = dr === 0 || dr === 6 || dc === 0 || dc === 6;
          const inInner = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4;
          setFunc(r0 + dr, c0 + dc, inOuter && (onBorder || inInner));
        }
      }
    };

    drawFinder(0, 0);
    drawFinder(0, size - 7);
    drawFinder(size - 7, 0);

    // Alignment patterns
    for (let i = 0; i < alignPos.length; i++) {
      for (let j = 0; j < alignPos.length; j++) {
        if ((i === 0 && j === 0) || (i === 0 && j === alignPos.length - 1) || (i === alignPos.length - 1 && j === 0)) {
          continue;
        }
        const r0 = alignPos[i];
        const c0 = alignPos[j];
        for (let dr = -2; dr <= 2; dr++) {
          for (let dc = -2; dc <= 2; dc++) {
            setFunc(r0 + dr, c0 + dc, Math.max(Math.abs(dr), Math.abs(dc)) !== 1);
          }
        }
      }
    }

    // Timing patterns
    for (let i = 8; i < size - 8; i++) {
      setFunc(6, i, i % 2 === 0);
      setFunc(i, 6, i % 2 === 0);
    }

    // Dark module & reserved format areas
    setFunc(size - 8, 8, true);
    for (let i = 0; i < 9; i++) {
      if (!isFunc[8][i]) setFunc(8, i, false);
      if (!isFunc[i][8]) setFunc(i, 8, false);
    }
    for (let i = 0; i < 8; i++) {
      if (!isFunc[8][size - 1 - i]) setFunc(8, size - 1 - i, false);
      if (!isFunc[size - 1 - i][8]) setFunc(size - 1 - i, 8, false);
    }

    // Place data bits in upward/downward 2-column zig-zag
    const stream = [];
    for (let i = 0; i < finalCodewords.length; i++) {
      for (let b = 7; b >= 0; b--) stream.push((finalCodewords[i] >>> b) & 1);
    }

    let bitIdx = 0;
    let upward = true;
    for (let right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (let vert = 0; vert < size; vert++) {
        const r = upward ? size - 1 - vert : vert;
        for (let j = 0; j < 2; j++) {
          const c = right - j;
          if (!isFunc[r][c]) {
            const bit = bitIdx < stream.length ? stream[bitIdx++] : 0;
            // Apply Mask 0: (r + c) % 2 === 0
            grid[r][c] = ((r + c) % 2 === 0) ? (bit ^ 1) : bit;
          }
        }
      }
      upward = !upward;
    }

    // Write Format Info for ECC Level L (01) + Mask 0 (000) -> 0x77C4
    const fmtBits = 0x77C4;
    for (let i = 0; i <= 5; i++) setFunc(8, i, ((fmtBits >>> i) & 1) === 1);
    setFunc(8, 7, ((fmtBits >>> 6) & 1) === 1);
    setFunc(8, 8, ((fmtBits >>> 7) & 1) === 1);
    setFunc(7, 8, ((fmtBits >>> 8) & 1) === 1);
    for (let i = 9; i < 15; i++) setFunc(14 - i, 8, ((fmtBits >>> i) & 1) === 1);

    for (let i = 0; i < 8; i++) setFunc(8, size - 1 - i, ((fmtBits >>> i) & 1) === 1);
    for (let i = 8; i < 15; i++) setFunc(size - 15 + i, 8, ((fmtBits >>> i) & 1) === 1);

    return grid.map(row => Array.from(row));
  }

  function renderQrMatrixToCanvas(canvas, matrix, darkColor) {
    const ctx = canvas.getContext('2d');
    const quietZone = 2;
    const count = matrix.length;
    const totalModules = count + quietZone * 2;
    const scale = 6;
    const pixelSize = totalModules * scale;

    canvas.width = pixelSize;
    canvas.height = pixelSize;
    canvas.style.width = '156px';
    canvas.style.height = '156px';

    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, pixelSize, pixelSize);

    ctx.fillStyle = darkColor || '#1B4332';
    for (let r = 0; r < count; r++) {
      for (let c = 0; c < count; c++) {
        if (matrix[r][c]) {
          ctx.fillRect((c + quietZone) * scale, (r + quietZone) * scale, scale, scale);
        }
      }
    }
  }
});
