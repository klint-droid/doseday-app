@echo off
title DoseDay Website Server
echo ============================================================
echo   DoseDay - Medication Reminder Landing Page & APK Download
echo ============================================================
echo.
echo Starting local web server on port 8085...
echo Opening http://localhost:8085 in your default browser...
start http://localhost:8085
python -m http.server 8085
pause
