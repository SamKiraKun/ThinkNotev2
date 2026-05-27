@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0smoke_install_release.ps1" %*
exit /b %ERRORLEVEL%