@echo off
setlocal

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-opencode.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-opencode.ps1" %*
)

set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Installer failed with exit code %EXITCODE%.
)

exit /b %EXITCODE%
