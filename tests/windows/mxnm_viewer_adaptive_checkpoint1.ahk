#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\config.example.ahk
#Include ..\..\src\app_config.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_config_path_cache.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk
#Include ..\..\src\mxnm_measurement_target_resolver.ahk
#Include ..\..\src\mxnm_viewer_runtime_probe.ahk

global MXNM_ADAPTIVE_AUDIT_SESSION := 0
global MXNM_ADAPTIVE_CHECKPOINT_VERSION := "1.1"

^!F6::BeginMxNMAdaptiveCheckpoint1()
^!F7::CaptureMxNMAdaptiveManualPoint()
#HotIf MxNMAdaptiveCheckpoint1Active()
Esc::CancelMxNMAdaptiveCheckpoint1()
#HotIf

MxNMAdaptiveCheckpoint1Active() {
    global MXNM_ADAPTIVE_AUDIT_SESSION
    return Type(MXNM_ADAPTIVE_AUDIT_SESSION) = "Map"
}

BeginMxNMAdaptiveCheckpoint1() {
    global MXNM_ADAPTIVE_AUDIT_SESSION
    viewerExe := MxNMConfigGeometryDefaults.ViewerExe
    outputPath :=
        A_Temp "\MedExAHK\mxnm_viewer_adaptive_checkpoint1.txt"
    SplitPath outputPath, , &outputDirectory
    if !DirExist(outputDirectory)
        DirCreate outputDirectory
    if FileExist(outputPath)
        FileDelete outputPath

    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    foregroundBefore := WinExist("A")
    profileAudit := MxNMViewerRuntimeProbe.AuditVendorProfiles(
        viewerExe
    )
    output := FormatMxNMAdaptiveProfileAudit(profileAudit)

    expectedPid := 0
    expectedProcessPath := profileAudit.viewerProcessPath
    viewerWindows := expectedProcessPath != ""
        ? CaptureMxNMViewerWindowGeometry(
            viewerExe,
            expectedProcessPath
        )
        : []
    if viewerWindows.Length > 0 {
        try expectedPid := WinGetPID(
            "ahk_id " viewerWindows[1].hwnd
        )
        catch
            expectedPid := 0
    }

    toolPlan := BuildMxNMViewerToolCommandPlan(
        viewerExe,
        profileAudit.ok
            ? ResolveMxNMConfigPathsFromProcessPath(
                viewerExe,
                profileAudit.viewerProcessPath
            )
            : 0
    )
    output .= FormatMxNMAdaptiveToolAudit(
        toolPlan,
        viewerWindows,
        expectedPid
    )

    measurementPlan := BuildMxNMMeasurementTargetPlan(
        viewerExe,
        profileAudit.ok
            ? ResolveMxNMConfigPathsFromProcessPath(
                viewerExe,
                profileAudit.viewerProcessPath
            )
            : 0
    )
    measurementTarget := MxNMMeasurementTargetResolver.Resolve(
        measurementPlan,
        viewerExe
    )
    output .= FormatMxNMAdaptiveMeasurementAudit(
        measurementPlan,
        measurementTarget,
        expectedPid
    )

    commandMatches :=
        MxNMViewerRuntimeProbe.FindCommandControls(
            viewerExe,
            expectedProcessPath,
            [
                MxNMViewerToolCommand.Arrow,
                MxNMViewerToolCommand.Length,
                MxNMViewerToolCommand.Suv3D
            ]
        )
    output .= FormatMxNMAdaptiveCommandMatches(commandMatches)

    MouseGetPos &mouseAfterX, &mouseAfterY
    foregroundAfter := WinExist("A")
    output .=
        "AutomaticForegroundUnchanged=" .
        MxNMAdaptiveBool(
            foregroundBefore = foregroundAfter
        ) "`r`n" .
        "AutomaticMouseUnchanged=" .
        MxNMAdaptiveBool(
            mouseBeforeX = mouseAfterX
            && mouseBeforeY = mouseAfterY
        ) "`r`n"
    FileAppend output, outputPath, "UTF-8"

    MXNM_ADAPTIVE_AUDIT_SESSION := Map(
        "outputPath", outputPath,
        "expectedPid", expectedPid,
        "stage", 1,
        "labels", ["arrow", "length", "suv3d", "image"]
    )
    ToolTip(
        "Checkpoint 1 自动审计完成。" .
        "`n请把鼠标移到箭头按钮中心，按 Ctrl+Alt+F7。" .
        "`nEsc 可取消。"
    )
}

CaptureMxNMAdaptiveManualPoint() {
    global MXNM_ADAPTIVE_AUDIT_SESSION
    if Type(MXNM_ADAPTIVE_AUDIT_SESSION) != "Map" {
        ToolTip("请先按 Ctrl+Alt+F6 开始 Checkpoint 1。")
        SetTimer (() => ToolTip()), -2500
        return
    }
    session := MXNM_ADAPTIVE_AUDIT_SESSION
    stage := session["stage"]
    labels := session["labels"]
    if stage < 1 || stage > labels.Length {
        CancelMxNMAdaptiveCheckpoint1()
        return
    }

    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseX, &mouseY
    label := labels[stage]
    point := {x: mouseX, y: mouseY}
    chain := MxNMViewerRuntimeProbe.CapturePoint(
        point,
        session["expectedPid"]
    )
    FileAppend(
        FormatMxNMAdaptivePointChain(
            "manual-" label,
            chain
        ),
        session["outputPath"],
        "UTF-8"
    )

    session["stage"] := stage + 1
    if session["stage"] > labels.Length {
        FileAppend(
            "ManualCaptureComplete=true`r`n",
            session["outputPath"],
            "UTF-8"
        )
        MXNM_ADAPTIVE_AUDIT_SESSION := 0
        ToolTip(
            "Checkpoint 1 采集完成。" .
            "`n结果：" session["outputPath"] .
            "`n请回传该文本文件。"
        )
        SetTimer (() => ToolTip()), -5000
        return
    }
    nextLabel := labels[session["stage"]]
    nextText := Map(
        "length", "长度测量按钮中心",
        "suv3d", "3D SUV按钮中心",
        "image", "任意有效图像内部"
    )[nextLabel]
    ToolTip(
        "已记录 " label "。" .
        "`n请把鼠标移到" nextText .
        "，按 Ctrl+Alt+F7。"
    )
}

CancelMxNMAdaptiveCheckpoint1() {
    global MXNM_ADAPTIVE_AUDIT_SESSION
    if Type(MXNM_ADAPTIVE_AUDIT_SESSION) != "Map"
        return
    MXNM_ADAPTIVE_AUDIT_SESSION := 0
    ToolTip("Checkpoint 1 已取消；已写入的数据保留。")
    SetTimer (() => ToolTip()), -2500
}

FormatMxNMAdaptiveProfileAudit(audit) {
    global MXNM_ADAPTIVE_CHECKPOINT_VERSION
    output :=
        "Test=MxNMViewerAdaptiveCheckpoint1`r`n" .
        "CheckpointVersion=" .
        MXNM_ADAPTIVE_CHECKPOINT_VERSION "`r`n" .
        "InteractionMode=READ_ONLY`r`n" .
        "ProfileAuditState=" audit.code "`r`n" .
        "ProfileRootExists=" .
        MxNMAdaptiveBool(audit.profileRootExists) "`r`n" .
        "ProfileCandidateCount=" audit.candidates.Length "`r`n"
    for hint in audit.rootDisplayHints
        output .= FormatMxNMAdaptiveDisplayHint(hint)
    for candidate in audit.candidates {
        geometry := candidate.geometry
        output .=
            "ProfileCandidate=" candidate.id .
            "|productionDefault=" .
            MxNMAdaptiveBool(candidate.productionDefault) .
            "|configOk=" MxNMAdaptiveBool(candidate.configOk) .
            "|configCode=" candidate.configCode .
            "|mainHash=" candidate.mainConfigSha256 .
            "|layoutHash=" candidate.layoutConfigSha256 .
            "|frame=" .
            MxNMAdaptiveGeometrySize(
                geometry,
                "frameWidth",
                "frameHeight"
            ) .
            "|image=" .
            MxNMAdaptiveGeometrySize(
                geometry,
                "imageWidth",
                "imageHeight"
            ) .
            "|commandsOk=" .
            MxNMAdaptiveBool(candidate.commandsOk) .
            "|rowCount=" candidate.rowCount .
            "|pad=" candidate.padX "," candidate.padY .
            "`r`n"
        for command in candidate.commands {
            output .=
                "ProfileCommand=" candidate.id .
                "|row=" command.row .
                "|column=" command.column .
                "|id=" command.commandId "`r`n"
        }
        for hint in candidate.displayHints
            output .= FormatMxNMAdaptiveDisplayHint(hint)
    }
    return output
}

FormatMxNMAdaptiveDisplayHint(hint) {
    return "DisplayHint=" hint.source .
        "|" hint.section .
        "|" hint.key .
        "|" hint.value "`r`n"
}

FormatMxNMAdaptiveToolAudit(
    plan,
    viewerWindows,
    expectedPid
) {
    output :=
        "ToolPlanState=" plan.code "`r`n" .
        "ViewerWindowCount=" viewerWindows.Length "`r`n"
    runtimeFrame := ResolveMxNMRuntimeFrame(viewerWindows)
    output .=
        "RuntimeFrameState=" runtimeFrame.code "`r`n" .
        "RuntimeFrameCandidateCount=" .
        runtimeFrame.candidateCount "`r`n"
    if !plan.ok || !runtimeFrame.ok
        return output

    for commandName, command in plan.commands {
        buttonOffset := {
            x: MxNMViewerToolCommand.ButtonCenterX,
            y: (
                MxNMViewerToolCommand.BuiltInRowCount
                + command.row - 1
            ) * MxNMViewerToolCommand.ButtonPitch
                + MxNMViewerToolCommand.ButtonCenterY
        }
        point := MapMxNMViewerToolPointToRuntimeFrame(
            {x: plan.padX, y: plan.padY},
            buttonOffset,
            plan.mainGeometry,
            runtimeFrame.frame
        )
        output .=
            "PredictedToolPoint=" commandName .
            "|" point.x "," point.y .
            "|commandId=" command.commandId "`r`n"
        output .= FormatMxNMAdaptivePointChain(
            "predicted-" commandName,
            MxNMViewerRuntimeProbe.CapturePoint(
                point,
                expectedPid
            )
        )
    }
    return output
}

FormatMxNMAdaptiveMeasurementAudit(
    plan,
    target,
    expectedPid
) {
    output :=
        "MeasurementPlanState=" plan.code "`r`n" .
        "MeasurementTargetState=" target.code "`r`n"
    if IsObject(target.screenPoint) {
        output .=
            "PredictedMeasurementPoint=" .
            target.screenPoint.x "," target.screenPoint.y "`r`n"
        output .= FormatMxNMAdaptivePointChain(
            "predicted-measurement",
            MxNMViewerRuntimeProbe.CapturePoint(
                target.screenPoint,
                expectedPid
            )
        )
    }
    return output
}

FormatMxNMAdaptiveCommandMatches(matches) {
    output := "CommandControlMatchCount=" matches.Length "`r`n"
    for match in matches {
        output .=
            "CommandControlMatch=" .
            FormatMxNMAdaptiveWindowInfo(match) "`r`n"
    }
    return output
}

FormatMxNMAdaptivePointChain(label, result) {
    output :=
        "PointProbe=" label .
        "|ok=" MxNMAdaptiveBool(result.ok) .
        "|point=" result.point.x "," result.point.y .
        "|pointHwnd=" result.pointHwnd .
        "|rootHwnd=" result.rootHwnd .
        "|rootOwnerHwnd=" result.rootOwnerHwnd .
        "|depth=" result.chain.Length "`r`n"
    for node in result.chain {
        output .=
            "PointNode=" label .
            "|depth=" node.depth .
            "|" FormatMxNMAdaptiveWindowInfo(node) "`r`n"
    }
    return output
}

FormatMxNMAdaptiveWindowInfo(info) {
    return "hwnd=" info.hwnd .
        "|parent=" info.parentHwnd .
        "|pid=" info.pid .
        "|samePid=" MxNMAdaptiveBool(info.samePid) .
        "|class=" info.className .
        "|controlId=" info.controlId .
        "|visible=" MxNMAdaptiveBool(info.visible) .
        "|enabled=" MxNMAdaptiveBool(info.enabled) .
        "|rect=" MxNMAdaptiveRect(info.rect)
}

MxNMAdaptiveRect(rect) {
    if !IsObject(rect)
        return ""
    return rect.left "," rect.top "," rect.right "," rect.bottom
}

MxNMAdaptiveGeometrySize(geometry, widthKey, heightKey) {
    if !IsObject(geometry)
        return ""
    return geometry.%widthKey% "," geometry.%heightKey%
}

MxNMAdaptiveBool(value) {
    return value ? "true" : "false"
}
