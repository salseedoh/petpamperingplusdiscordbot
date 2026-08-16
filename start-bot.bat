@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Install Node.js 22 or newer from https://nodejs.org/ then run this file again.
  pause
  exit /b 1
)

echo Starting the bot. Keep this window open while the bot should be online.
call npm run start
pause
