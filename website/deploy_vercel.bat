@echo off
title Deploy DoseDay to Vercel
echo ============================================================
echo   Deploying DoseDay Landing Page & APK Portal to Vercel
echo ============================================================
echo.
cd /d "%~dp0"
echo Running Vercel CLI...
echo If this is your first time, Vercel will ask you to log in via browser.
echo.
npx vercel
pause
