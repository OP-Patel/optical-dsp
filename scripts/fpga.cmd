@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0fpga.ps1" %*
exit /b %ERRORLEVEL%
