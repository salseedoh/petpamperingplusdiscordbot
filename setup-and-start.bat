@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Install Node.js 22 or newer from https://nodejs.org/ then run this file again.
  pause
  exit /b 1
)

echo Installing the bot's packages...
if exist node_modules (
  echo Clearing the incomplete package folder from the earlier attempt...
  rmdir /s /q node_modules
)
call npm install
if errorlevel 1 goto :error

echo Registering slash commands in the test server...
call npm run deploy:commands
if errorlevel 1 goto :error

echo Starting the bot. Keep this window open while the bot should be online.
call npm run start
goto :end

:error
echo.
echo Setup could not finish. Copy the message above and send it to Codex for help.

:end
pause
