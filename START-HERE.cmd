@echo off
title WacliChatBridge - Setup
chcp 65001 >nul
cls
echo.
echo  ==========================================
echo       WacliChatBridge - eenvoudige setup
echo  ==========================================
echo.
echo  Hiermee koppel je je eigen WhatsApp veilig
echo  aan ChatGPT. Je hoeft niets technisch in
echo  te stellen: volg alleen de stappen.
echo.
echo  Druk op een toets om te starten...
pause >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" (
  echo  De installatie is niet afgerond.
  echo  Lees de melding hierboven of probeer START-HERE.cmd opnieuw.
)
echo.
pause
exit /b %EXITCODE%
