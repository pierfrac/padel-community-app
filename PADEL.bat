@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" set "ACTION=web"
if not "%~1"=="" set "ACTION=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\flutter-launcher.ps1" -Action %ACTION%
if errorlevel 1 (
  echo.
  echo Operazione non riuscita. Vedi logs\flutter-setup.log
)
if /I "%ACTION%"=="web" pause
