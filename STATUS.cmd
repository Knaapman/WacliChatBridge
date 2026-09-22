@echo off
set "ROOT=%LOCALAPPDATA%\WacliChatBridge"
if not exist "%ROOT%\status.ps1" (
  echo WacliChatBridge is not installed yet.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\status.ps1"
echo.
pause
