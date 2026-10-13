@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0..\..\"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\build_tool_exe.ps1" -Generator build_report_image_caption_diagnostic.py -InputScriptName report_image_caption_migration_diagnostic_standalone.ahk -ToolName MedEx-Report-Image-Caption-Diagnostic -BuildSubdirectory report-image-caption-diagnostic
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
pause
exit /b %BUILD_EXIT_CODE%
