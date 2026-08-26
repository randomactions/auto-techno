@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows-build.ps1"
set "AUTO_TECHNO_EXIT=%ERRORLEVEL%"
pause
exit /b %AUTO_TECHNO_EXIT%
