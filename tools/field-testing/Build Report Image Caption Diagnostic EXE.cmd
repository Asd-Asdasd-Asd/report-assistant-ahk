@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0..\..\"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\build_report_image_caption_diagnostic_exe.ps1"
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
pause
exit /b %BUILD_EXIT_CODE%
