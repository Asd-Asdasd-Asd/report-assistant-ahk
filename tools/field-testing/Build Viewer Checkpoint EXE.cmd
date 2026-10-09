@echo off
setlocal

set "REPOSITORY_ROOT=%~dp0..\..\"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%REPOSITORY_ROOT%scripts\build_tool_exe.ps1" -Generator build_mxnm_viewer_adaptive_checkpoint.py -InputScriptName mxnm_viewer_adaptive_checkpoint1_standalone.ahk -ToolName MxNM-Viewer-Checkpoint1 -BuildSubdirectory viewer-checkpoint
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
pause
exit /b %BUILD_EXIT_CODE%
