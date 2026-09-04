@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-windows.ps1"
set "AUTO_TECHNO_EXIT=%ERRORLEVEL%"
if not "%AUTO_TECHNO_EXIT%"=="0" pause
exit /b %AUTO_TECHNO_EXIT%
