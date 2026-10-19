@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0windows\panel.ps1"
  exit /b
)
title PADEL Community
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\flutter-launcher.ps1" -Action %*
echo.
pause
