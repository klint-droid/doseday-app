# DoseDay Official Website & APK Download Portal

This folder contains the complete, standalone landing page and direct APK download portal for **DoseDay — Smart Medication Reminder & Pill Tracker**.

## Folder Contents

- **`index.html`**: The main responsive landing page (Figma-inspired Royal Purple `#5F33E1` theme, dark/light mode toggle, interactive features).
- **`styles.css`**: Vanilla CSS with glassmorphism, responsive CSS grid, floating animations, and mobile chassis styling.
- **`app.js`**: Interactive logic (Monday–Sunday week simulator, reminder chime audio preview, screen switcher, QR code generator).
- **`downloads/`**:
  - `DoseDay.apk`: The production release APK (~58.7 MB, built with Flutter for Android 8.0 through Android 15).
  - `DoseDay-release-v1.0.apk`: Version 1.0.0 release mirror.
- **`assets/`**:
  - `images/`: High-resolution Figma UI screenshots, app logo, and avatars.
  - `videos/`: Splash screen animation video.
  - `reminder_sound.wav`: The custom 44.1kHz notification chime.
- **`start_website.bat`**: One-click double-clickable script to launch the site locally on `http://localhost:8085`.

## How to Run Locally

Double-click `start_website.bat`, or run from terminal:
```bash
python -m http.server 8085 --directory "c:\flutter\medication_reminder\website"
```
Then visit `http://localhost:8085` in any web browser.

## Features Showcase on the Website
1. **Direct APK Download**: One-click download button and QR code for camera scanning.
2. **Interactive Monday–Sunday Simulator**: Working 7-day strip where visitors can test week navigation and check off sample doses.
3. **Live Audio Chime Demo**: Test the exact reminder sound right from the browser.
4. **Interactive Phone Mockup**: Switch between Home, Schedule, Add Medicine, and Onboarding screens.
5. **Step-by-Step Installation Guide**: Easy instructions for Android users.
