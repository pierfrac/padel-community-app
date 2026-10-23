@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0avvia-padel-deploy.ps1" %*
exit /b %ERRORLEVEL%
