@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\package_release.ps1"
set "PACKAGE_EXIT_CODE=%ERRORLEVEL%"

echo.
if "%PACKAGE_EXIT_CODE%"=="0" goto package_succeeded

echo Packaging failed with exit code %PACKAGE_EXIT_CODE%.
goto package_finished

:package_succeeded
echo Packaging succeeded.

:package_finished
echo.
pause
exit /b %PACKAGE_EXIT_CODE%
