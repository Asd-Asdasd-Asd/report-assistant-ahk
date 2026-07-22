@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\build_exe.ps1"
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
if "%BUILD_EXIT_CODE%"=="0" goto build_succeeded

echo Build failed with exit code %BUILD_EXIT_CODE%.
goto build_finished

:build_succeeded
echo Build succeeded.

:build_finished
echo.
pause
exit /b %BUILD_EXIT_CODE%
