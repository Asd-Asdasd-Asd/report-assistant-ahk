#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\measurement_model.ahk
#Include ..\..\src\measurement_parser.ahk
#Include ..\..\src\measurement_clipboard.ahk
#Include ..\..\src\context_measurement_provider.ahk

CoordMode "Mouse", "Screen"

global ContextMeasurementFieldPoint := 0

^!F8::CaptureContextMeasurementFieldPoint()
^!F9::RunContextMeasurementProviderFieldRead()

CaptureContextMeasurementFieldPoint() {
    global ContextMeasurementFieldPoint
    MouseGetPos &screenX, &screenY
    ContextMeasurementFieldPoint := {
        x: screenX,
        y: screenY
    }
    ShowContextMeasurementFieldFeedback(
        "测量点已记录`n返回报告编辑器后按 Ctrl+Alt+F9",
        1800
    )
}

RunContextMeasurementProviderFieldRead() {
    global ContextMeasurementFieldPoint
    if !IsObject(ContextMeasurementFieldPoint) {
        ShowContextMeasurementFieldFeedback(
            "尚未记录测量点`n请在 viewer 图像内按 Ctrl+Alt+F8",
            2200
        )
        return false
    }

    foregroundBefore := WinExist("A")
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    result := ContextMeasurementProvider.ReadSuvMax(
        Map("imageScreenPoint", ContextMeasurementFieldPoint)
    )
    foregroundAfter := WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY

    outputPath := A_Temp "\MedExAHK\context_measurement_provider_field.txt"
    SplitPath outputPath, , &outputDirectory
    if !DirExist(outputDirectory)
        DirCreate outputDirectory
    if FileExist(outputPath)
        FileDelete outputPath
    FileAppend(
        BuildContextMeasurementProviderFieldOutput(
            result,
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
    if result.state = MeasurementState.AUTOMATION_FAILED {
        ShowContextMeasurementFieldFeedback(
            "SUVMax 读取失败`n" result.failureReason
            "`n结果已写入：" outputPath,
            3500
        )
    } else {
        ShowContextMeasurementFieldFeedback(
            "SUVMax provider 测试完成`nState=" result.state
            "`n结果已写入：" outputPath,
            3000
        )
    }
    return result.state != MeasurementState.AUTOMATION_FAILED
}

ShowContextMeasurementFieldFeedback(message, durationMs := 2000) {
    ToolTip message
    SetTimer HideContextMeasurementFieldFeedback, -Max(250, durationMs)
}

HideContextMeasurementFieldFeedback() {
    ToolTip
}

BuildContextMeasurementProviderFieldOutput(result, foregroundBefore,
    foregroundAfter, mouseBeforeX, mouseBeforeY, mouseAfterX, mouseAfterY) {
    context := result.context
    lines := [
        "Test=ContextMeasurementProvider",
        "State=" result.state,
        "FailureReason=" result.failureReason,
        "MeasurementType=" result.measurementType,
        "Source=" result.source,
        "ForegroundUnchanged=" (
            foregroundBefore = foregroundAfter ? "true" : "false"
        ),
        "MouseUnchanged=" (
            mouseBeforeX = mouseAfterX && mouseBeforeY = mouseAfterY
                ? "true"
                : "false"
        ),
        "ClipboardCaptureSucceeded=" MeasurementFieldBoolean(
            MeasurementFieldContextValue(
                context,
                "clipboardCaptureSucceeded",
                false
            )
        ),
        "ClipboardRestoreSucceeded=" MeasurementFieldBoolean(
            MeasurementFieldContextValue(
                context,
                "clipboardRestoreSucceeded",
                false
            )
        ),
        "PopupCreated=" MeasurementFieldBoolean(
            MeasurementFieldContextValue(context, "popupHwnd", 0) != 0
        ),
        "CommandRuntimeIdResolved=" MeasurementFieldBoolean(
            MeasurementFieldContextValue(context, "commandRuntimeId", 0) > 0
        )
    ]
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n"
}

MeasurementFieldContextValue(context, key, defaultValue := 0) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}

MeasurementFieldBoolean(value) {
    return value ? "true" : "false"
}
