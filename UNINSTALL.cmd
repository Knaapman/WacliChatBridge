@echo off
set "ROOT=%LOCALAPPDATA%\WacliChatBridge"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Unregister-ScheduledTask -TaskName 'WacliChatBridge' -Confirm:$false -ErrorAction SilentlyContinue; Get-CimInstance Win32_Process ^| Where-Object { $_.CommandLine -like '*WacliChatBridge*' -and $_.ProcessId -ne $PID } ^| ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; if (Test-Path '%ROOT%') { $backup = Join-Path $env:LOCALAPPDATA ('WacliChatBridge-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')); Move-Item '%ROOT%' $backup; Write-Host ('Removed. WhatsApp/runtime data preserved at ' + $backup) }"
echo.
pause
