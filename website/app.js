/**
 * DoseDay Website Logic
 * - Interactive Monday-to-Sunday Week Simulator
 * - Live Chime Audio Preview
 * - Mockup Screen Switcher
 * - Dark/Light Theme Switcher
 * - QR Code Canvas Rendering
 * - FAQ Accordion
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Theme Management
  const themeBtn = document.getElementById('theme-toggle');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const savedTheme = localStorage.getItem('doseday_theme') || (prefersDark ? 'dark' : 'light');
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcon(savedTheme);

  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'dark';
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('doseday_theme', next);
      updateThemeIcon(next);
    });
  }

  function updateThemeIcon(theme) {
    if (!themeBtn) return;
    themeBtn.innerHTML = theme === 'dark'
      ? `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`
      : `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`;
  }

  // 2. Audio Chime Playback
  const chimeAudio = new Audio('assets/reminder_sound.wav');
  const playBtns = document.querySelectorAll('.js-play-chime');

  playBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      chimeAudio.currentTime = 0;
      chimeAudio.play().catch(e => console.log('Audio autoplay prevented:', e));
      btn.classList.add('playing');
      setTimeout(() => btn.classList.remove('playing'), 2000);
    });
  });

  // 3. Mockup Screen Switcher
  const screenImg = document.getElementById('phone-screen-img');
  const screenTabs = document.querySelectorAll('.screen-tab-btn');

  const screens = {
    adherence: 'assets/playstore/playstore_slide_one_1792822482509.jpg',
    planner: 'assets/playstore/playstore_slide_two_1792822515894.jpg',
    alarms: 'assets/playstore/playstore_slide_three_1792822533786.jpg',
    home: 'assets/playstore/playstore_slide_one_1792822482509.jpg',
    tasks: 'assets/playstore/playstore_slide_two_1792822515894.jpg',
    add: 'assets/playstore/playstore_slide_three_1792822533786.jpg'
  };

  screenTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.getAttribute('data-screen');
      if (!screens[target] || !screenImg) return;

      screenTabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      screenImg.style.opacity = '0.3';
      setTimeout(() => {
        screenImg.src = screens[target];
        screenImg.style.opacity = '1';
      }, 150);
    });
  });

  // 4. Interactive Monday-to-Sunday Week Simulator
  let simWeekOffset = 0;
  let simSelectedDate = new Date();
  const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  function getMonday(d, offsetWeeks = 0) {
    const date = new Date(d);
    const day = date.getDay(); // 0 is Sun, 1 is Mon...
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

  if (prevWeekBtn) {
    prevWeekBtn.addEventListener('click', () => {
      simWeekOffset--;
      renderSimStrip();
    });
  }
  if (nextWeekBtn) {
    nextWeekBtn.addEventListener('click', () => {
      simWeekOffset++;
      renderSimStrip();
    });
  }
  if (todayBtn) {
    todayBtn.addEventListener('click', () => {
      simWeekOffset = 0;
      simSelectedDate = new Date();
      renderSimStrip();
    });
  }

  renderSimStrip();

  // 5. Simulator Dose Check-off Interaction
  const doseCheckBtns = document.querySelectorAll('.js-sim-check');
  doseCheckBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const isTaken = btn.classList.contains('taken');
      if (!isTaken) {
        btn.classList.add('taken');
        btn.textContent = '✓ Taken';
        chimeAudio.currentTime = 0;
        chimeAudio.play().catch(() => {});
      } else {
        btn.classList.remove('taken');
        btn.textContent = 'Take Dose';
      }
    });
  });

  // 6. FAQ Accordion
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

  // 7. QR Code Canvas Rendering (Simple procedural QR pattern representation)
  const qrCanvas = document.getElementById('qr-canvas');
  if (qrCanvas) {
    const ctx = qrCanvas.getContext('2d');
    const size = 160;
    qrCanvas.width = size;
    qrCanvas.height = size;

    // Draw stylish stylized QR matrix
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, size, size);

    ctx.fillStyle = '#171520';
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

  // 7. Lightbox Modal Preview for Play Store Screenshots
  const lightboxModal = document.getElementById('lightbox-modal');
  const lightboxImg = document.getElementById('lightbox-img');
  const lightboxClose = document.getElementById('lightbox-close');
  const lightboxTriggers = document.querySelectorAll('.js-lightbox-trigger');

  if (lightboxModal && lightboxImg) {
    lightboxTriggers.forEach(card => {
      card.addEventListener('click', () => {
        const src = card.getAttribute('data-img');
        if (src) {
          lightboxImg.src = src;
          lightboxModal.classList.add('active');
        }
      });
    });

    const closeModal = () => lightboxModal.classList.remove('active');
    if (lightboxClose) lightboxClose.addEventListener('click', closeModal);
    lightboxModal.addEventListener('click', (e) => {
      if (e.target === lightboxModal) closeModal();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && lightboxModal.classList.contains('active')) closeModal();
    });
  }
});
