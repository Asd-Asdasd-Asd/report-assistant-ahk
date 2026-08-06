#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\measurement_model.ahk
#Include ..\..\src\measurement_parser.ahk
#Include ..\..\src\measurement_clipboard.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk
#Include ..\..\src\mxnm_measurement_target_resolver.ahk
#Include ..\..\src\mxnm_context_target_session.ahk
#Include ..\..\src\mxnm_measurement_provider.ahk
#Include ..\..\src\context_measurement_provider.ahk

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

^!F10::PreviewMxNMMeasurementTarget()
^!F11::RunMxNMAutomaticTargetSuvMax()

PreviewMxNMMeasurementTarget() {
    foregroundBefore := WinExist("A")
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    targetStartedAt := A_TickCount
    target := MxNMMeasurementProvider.ResolveTarget()
    target.targetResolutionMs := A_TickCount - targetStartedAt
    foregroundAfter := WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY
    WriteMxNMMeasurementTargetFieldOutput(
        "TARGET_PREVIEW",
        target,
        0,
        foregroundBefore,
        foregroundAfter,
        mouseBeforeX,
        mouseBeforeY,
        mouseAfterX,
        mouseAfterY
    )
    if target.ok {
        ToolTip(
            "自动测量目标点",
            target.screenPoint.x,
            target.screenPoint.y,
            1
        )
        SetTimer (() => ToolTip(, , , 1)), -3500
    } else {
        ShowMxNMTargetFieldFeedback(
            "自动测量目标解析失败`n" target.code,
            3500
        )
    }
}

RunMxNMAutomaticTargetSuvMax() {
    ToolTip(, , , 1)
    foregroundBefore := WinExist("A")
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    targetStartedAt := A_TickCount
    target := MxNMMeasurementProvider.ResolveTarget()
    target.targetResolutionMs := A_TickCount - targetStartedAt
    if target.ok {
        result := ContextMeasurementProvider.ReadSuvMax(
            Map("imageScreenPoint", target.screenPoint)
        )
    } else {
        result := 0
    }
    foregroundAfter := WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY
    outputPath := WriteMxNMMeasurementTargetFieldOutput(
        "SUV_MAX_AUTO_TARGET",
        target,
        result,
        foregroundBefore,
        foregroundAfter,
        mouseBeforeX,
        mouseBeforeY,
        mouseAfterX,
        mouseAfterY
    )
    if !target.ok {
        ShowMxNMTargetFieldFeedback(
            "自动测量目标解析失败`n" target.code .
                "`n结果已写入：" outputPath,
            4000
        )
    } else if result.state = MeasurementState.AUTOMATION_FAILED {
        ShowMxNMTargetFieldFeedback(
            "自动 SUVMax 读取失败`n" result.failureReason .
                "`n结果已写入：" outputPath,
            4000
        )
    } else {
        ShowMxNMTargetFieldFeedback(
            "自动 SUVMax 测试完成`nState=" result.state .
                "`n结果已写入：" outputPath,
            3500
        )
    }
}

WriteMxNMMeasurementTargetFieldOutput(
    mode,
    target,
    measurementResult,
    foregroundBefore,
    foregroundAfter,
    mouseBeforeX,
    mouseBeforeY,
    mouseAfterX,
    mouseAfterY
) {
    outputPath :=
        A_Temp "\MedExAHK\mxnm_measurement_target_field.txt"
    SplitPath outputPath, , &outputDirectory
    if !DirExist(outputDirectory)
        DirCreate outputDirectory
    if FileExist(outputPath)
        FileDelete outputPath
    FileAppend(
        FormatMxNMMeasurementTargetFieldOutput(
            mode,
            target,
            measurementResult,
            foregroundBefore,
            foregroundAfter,
            mouseBeforeX,
            mouseBeforeY,
            mouseAfterX,
            mouseAfterY
        ),
        outputPath,
        "UTF-8"
    )
    return outputPath
}

FormatMxNMMeasurementTargetFieldOutput(
    mode,
    target,
    measurementResult,
    foregroundBefore,
    foregroundAfter,
    mouseBeforeX,
    mouseBeforeY,
    mouseAfterX,
    mouseAfterY
) {
    hasMeasurement := IsObject(measurementResult)
    context := hasMeasurement ? measurementResult.context : Map()
    lines := [
        "Test=MxNMMeasurementTargetField",
        "Mode=" mode,
        "TargetState=" target.code,
        "ConfigState=" target.configCode,
        "ConfigReady=" MxNMTargetFieldBoolean(target.configReady),
        "RuntimeFrameResolved=" .
            MxNMTargetFieldBoolean(target.runtimeFrameResolved),
        "RuntimeFrameCandidateCount=" .
            target.runtimeFrameCandidateCount,
        "RuntimeFrameOwnerFamilyCount=" .
            target.runtimeFrameOwnerFamilyCount,
        "RuntimeToolAnchorResolved=" .
            MxNMTargetFieldBoolean(
                target.runtimeToolAnchorResolved
            ),
        "RuntimeToolAnchorHwnd=" target.runtimeToolAnchorHwnd,
        "RuntimeToolAnchorUsed=" .
            MxNMTargetFieldBoolean(target.runtimeToolAnchorUsed),
        "RuntimeToolAnchorFallbackCode=" .
            target.runtimeToolAnchorFallbackCode,
        "RuntimeSurfaceSelectionCode=" .
            target.runtimeSurfaceSelectionCode,
        "RuntimePointSource=" target.runtimePointSource,
        "MappedImageRectResolved=" .
            MxNMTargetFieldBoolean(target.mappedImageRectResolved),
        "LayoutReady=" MxNMTargetFieldBoolean(target.layoutReady),
        "LayoutCode=" target.layoutCode,
        "LayoutModelCount=" target.layoutModelCount,
        "RuntimeSurfaceFallbackEligible=" .
            MxNMTargetFieldBoolean(
                target.runtimeSurfaceFallbackEligible
            ),
        "SessionCacheHit=" .
            MxNMTargetFieldBoolean(target.sessionCacheHit),
        "SessionGeneration=" target.sessionGeneration,
        "SessionRootHwnd=" target.sessionRootHwnd,
        "SessionSurfaceHwnd=" target.sessionSurfaceHwnd,
        "SessionCandidateCount=" target.sessionCandidateCount,
        "SessionPointProbeCount=" target.sessionPointProbeCount,
        "MinimumLogicalClearance=" target.minimumLogicalClearance,
        "MinimumRequiredClearance=" .
            target.minimumRequiredClearance,
        "LogicalPoint=" .
            MxNMTargetFieldPoint(target.logicalPoint),
        "ImageRect=" MxNMTargetFieldRect(target.imageRect),
        "ScreenPoint=" MxNMTargetFieldPoint(target.screenPoint),
        "ActionClientPoint=" .
            MxNMTargetFieldPoint(target.actionClientPoint),
        "TargetResolutionMs=" target.targetResolutionMs,
        "ActionWindowResolved=" .
            MxNMTargetFieldBoolean(target.actionHwnd != 0),
        "MeasurementInvoked=" .
            MxNMTargetFieldBoolean(hasMeasurement),
        "MeasurementState=" (
            hasMeasurement ? measurementResult.state : ""
        ),
        "FailureReason=" (
            hasMeasurement ? measurementResult.failureReason : ""
        ),
        "TargetActionMatchesProviderViewer=" .
            MxNMTargetFieldBoolean(
                hasMeasurement
                && MxNMTargetFieldContextValue(
                    context,
                    "viewerHwnd",
                    0
                ) = target.actionHwnd
            ),
        "ForegroundUnchanged=" .
            MxNMTargetFieldBoolean(
                foregroundBefore = foregroundAfter
            ),
        "MouseUnchanged=" .
            MxNMTargetFieldBoolean(
                mouseBeforeX = mouseAfterX
                && mouseBeforeY = mouseAfterY
            ),
        "ClipboardCaptureSucceeded=" .
            MxNMTargetFieldBoolean(
                MxNMTargetFieldContextValue(
                    context,
                    "clipboardCaptureSucceeded",
                    false
                )
            ),
        "ClipboardRestoreSucceeded=" .
            MxNMTargetFieldBoolean(
                MxNMTargetFieldContextValue(
                    context,
                    "clipboardRestoreSucceeded",
                    false
                )
            ),
        "PopupCreated=" .
            MxNMTargetFieldBoolean(
                MxNMTargetFieldContextValue(
                    context,
                    "popupHwnd",
                    0
                ) != 0
            ),
        "CommandRuntimeIdResolved=" .
            MxNMTargetFieldBoolean(
                MxNMTargetFieldContextValue(
                    context,
                    "commandRuntimeId",
                    0
                ) > 0
            )
    ]
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n"
}

MxNMTargetFieldPoint(point) {
    if !IsObject(point)
        return ""
    return point.x "," point.y
}

MxNMTargetFieldRect(rect) {
    if !IsObject(rect)
        return ""
    return rect.left "," rect.top ","
        . rect.right "," rect.bottom
}

MxNMTargetFieldContextValue(context, key, defaultValue := 0) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}

MxNMTargetFieldBoolean(value) {
    return value ? "true" : "false"
}

ShowMxNMTargetFieldFeedback(message, durationMs := 2500) {
    ToolTip message
    SetTimer (() => ToolTip()), -Max(250, durationMs)
}
