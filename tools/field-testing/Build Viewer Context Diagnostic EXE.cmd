@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0..\..\"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\build_tool_exe.ps1" -Generator build_mxnm_context_menu_diagnostic.py -InputScriptName mxnm_context_menu_receiver_diagnostic_standalone.ahk -ToolName MxNM-Viewer-Context-Diagnostic -BuildSubdirectory viewer-context-diagnostic
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
pause
exit /b %BUILD_EXIT_CODE%
