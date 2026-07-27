@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0..\..\"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\build_viewer_checkpoint_exe.ps1"
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
pause
exit /b %BUILD_EXIT_CODE%
