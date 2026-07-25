#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\config.example.ahk
#Include ..\..\src\app_config.ahk
#Include ..\..\src\utils.ahk
#Include ..\..\src\visual_feedback.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_config_path_cache.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk
#Include ..\..\src\feature_model.ahk
#Include ..\..\src\viewer_tool_hotkeys.ahk

^!F9::RunMxNMViewerToolCommandField("arrow")
^!F10::RunMxNMViewerToolCommandField("length")
^!F11::RunMxNMViewerToolCommandField("suv3d")

RunMxNMViewerToolCommandField(commandName) {
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    foregroundBefore := WinExist("A")
    startedAt := A_TickCount
    result := MxNMViewerToolCommandProvider.Invoke(commandName)
    elapsedMs := A_TickCount - startedAt
    Sleep 80
    MouseGetPos &mouseAfterX, &mouseAfterY
    foregroundAfter := WinExist("A")

    outputPath := A_Temp "\MedExAHK\mxnm_viewer_tool_command_field.txt"
    SplitPath outputPath, , &outputDirectory
    if !DirExist(outputDirectory)
        DirCreate outputDirectory
    if FileExist(outputPath)
        FileDelete outputPath
    FileAppend(
        "Test=MxNMViewerToolCommandField`r`n"
        . "Command=" commandName "`r`n"
        . "State=" result.code "`r`n"
        . "CommandId=" result.commandId "`r`n"
        . "CommandRow=" result.commandRow "`r`n"
        . "CommandColumn=" result.commandColumn "`r`n"
        . "TargetScreenPoint="
            . MxNMViewerToolFieldPoint(result.screenPoint) "`r`n"
        . "ButtonHwnd=" result.buttonHwnd "`r`n"
        . "ButtonParentHwnd=" result.buttonParentHwnd "`r`n"
        . "ButtonRootHwnd=" result.buttonRootHwnd "`r`n"
        . "RuntimeControlId=" result.runtimeControlId "`r`n"
        . "DispatchElapsedMs=" elapsedMs "`r`n"
        . "ForegroundUnchanged="
            . MxNMViewerToolFieldBool(
                foregroundBefore = foregroundAfter
            ) "`r`n"
        . "MouseUnchanged="
            . MxNMViewerToolFieldBool(
                mouseBeforeX = mouseAfterX
                && mouseBeforeY = mouseAfterY
            ) "`r`n",
        outputPath,
        "UTF-8"
    )
    ToolTip(
        result.ok
            ? "Viewer 工具命令已投递：" commandName
                . "`n请核对按钮状态和结果文件"
            : "Viewer 工具命令失败：" result.code
    )
    SetTimer (() => ToolTip()), -2500
}

MxNMViewerToolFieldBool(value) {
    return value ? "true" : "false"
}

MxNMViewerToolFieldPoint(point) {
    if !IsObject(point)
        return ""
    return point.x "," point.y
}
