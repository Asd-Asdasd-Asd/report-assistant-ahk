#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\config.example.ahk
#Include ..\..\src\app_config.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_config_path_cache.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk

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
        . "ButtonPanelHwnd=" result.buttonPanelHwnd "`r`n"
        . "RuntimeControlId=" result.runtimeControlId "`r`n"
        . "RuntimeCandidateCount="
            . result.runtimeCandidateCount "`r`n"
        . "DispatchElapsedMs=" elapsedMs "`r`n"
        . "ForegroundUnchanged="
            . MxNMViewerToolFieldBool(
                foregroundBefore = foregroundAfter
            ) "`r`n"
        . "MouseUnchanged="
            . MxNMViewerToolFieldBool(
                mouseBeforeX = mouseAfterX
                && mouseBeforeY = mouseAfterY
            ) "`r`n"
        . BuildMxNMViewerToolResolverAudit(),
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

BuildMxNMViewerToolResolverAudit() {
    viewerExe := MxNMConfigGeometryDefaults.ViewerExe
    plan := MxNMViewerToolCommandProvider.ResolvePlan(viewerExe)
    output :=
        "ResolverPlanState=" plan.code "`r`n"
    if !plan.ok
        return output
    output .=
        "ResolverPlanPad=" plan.padX "," plan.padY "`r`n"
        . "ResolverPlanFrame="
            . plan.mainGeometry.frameWidth ","
            . plan.mainGeometry.frameHeight "`r`n"

    viewerWindows := CaptureMxNMViewerWindowGeometry(
        viewerExe,
        plan.viewerProcessPath
    )
    output .= "ResolverViewerWindowCount="
        . viewerWindows.Length "`r`n"
    processResult := ResolveMxNMViewerToolProcess(viewerWindows)
    output .= "ResolverProcessState=" processResult.code "`r`n"
    if !processResult.ok
        return output

    commandKeyById := Map()
    for commandKey, command in plan.commands
        commandKeyById[command.commandId] := commandKey
    candidates := EnumerateMxNMViewerToolControlCandidates(
        viewerWindows,
        processResult.pid,
        commandKeyById
    )
    output .= "ResolverCandidateCount=" candidates.Length "`r`n"
    groups := Map()
    for candidate in candidates {
        output .=
            "ResolverCandidate="
            . candidate.commandKey
            . "|id=" candidate.controlId
            . "|hwnd=" candidate.hwnd
            . "|parent=" candidate.parentHwnd
            . "|root=" candidate.rootHwnd
            . "|rect=" MxNMViewerToolFieldRect(candidate.rect)
            . "|parentRect="
                . MxNMViewerToolFieldRect(candidate.parentRect)
            . "`r`n"
        if !groups.Has(candidate.parentHwnd) {
            groups[candidate.parentHwnd] := {
                parentHwnd: candidate.parentHwnd,
                parentRect: candidate.parentRect,
                controls: Map()
            }
        }
        group := groups[candidate.parentHwnd]
        if !group.controls.Has(candidate.commandKey)
            group.controls[candidate.commandKey] := []
        group.controls[candidate.commandKey].Push(candidate)
    }

    for _, group in groups {
        controls := Map()
        complete := true
        counts := []
        for commandKey, _ in plan.commands {
            count := group.controls.Has(commandKey)
                ? group.controls[commandKey].Length
                : 0
            counts.Push(commandKey ":" count)
            if count != 1 {
                complete := false
                continue
            }
            controls[commandKey] := group.controls[commandKey][1]
        }
        layoutValid := complete
            && ValidateMxNMViewerToolControlLayout(
                plan.commands,
                controls,
                group.parentRect
            )
        frameHwnd := MxNMViewerToolGetRootOwnerHwnd(
            group.parentHwnd
        )
        runtimeFrame := FindMxNMViewerToolWindowGeometry(
            viewerWindows,
            frameHwnd
        )
        frameFound := IsObject(runtimeFrame)
        padOrigin := frameFound
            ? MapMxNMViewerToolPadOriginToRuntimeFrame(
                {x: plan.padX, y: plan.padY},
                plan.mainGeometry,
                runtimeFrame
            )
            : 0
        anchorValid := layoutValid
            && frameFound
            && MxNMViewerToolPanelMatchesPadOrigin(
                group.parentHwnd,
                group.parentRect,
                padOrigin,
                runtimeFrame,
                processResult.pid
            )
        output .=
            "ResolverGroup="
            . group.parentHwnd
            . "|counts=" MxNMViewerToolFieldJoin(counts, ",")
            . "|complete=" MxNMViewerToolFieldBool(complete)
            . "|layoutValid="
                . MxNMViewerToolFieldBool(layoutValid)
            . "|rootOwner=" frameHwnd
            . "|frameFound=" MxNMViewerToolFieldBool(frameFound)
            . "|panelRect="
                . MxNMViewerToolFieldRect(group.parentRect)
            . "|expectedPad="
                . MxNMViewerToolFieldPoint(padOrigin)
            . "|anchorValid="
                . MxNMViewerToolFieldBool(anchorValid)
            . "`r`n"
    }
    return output
}

MxNMViewerToolFieldRect(rect) {
    if !IsObject(rect)
        return ""
    return rect.left "," rect.top ","
        . rect.right "," rect.bottom
}

MxNMViewerToolFieldJoin(values, separator) {
    output := ""
    for index, value in values
        output .= (index = 1 ? "" : separator) value
    return output
}
