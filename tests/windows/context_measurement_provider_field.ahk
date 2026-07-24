#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\measurement_model.ahk
#Include ..\..\src\measurement_parser.ahk
#Include ..\..\src\measurement_clipboard.ahk
#Include ..\..\src\context_measurement_provider.ahk

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
    SoundBeep 800, 100
}

RunContextMeasurementProviderFieldRead() {
    global ContextMeasurementFieldPoint
    if !IsObject(ContextMeasurementFieldPoint) {
        SoundBeep 500, 180
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
    feedbackFrequency := result.state = MeasurementState.AUTOMATION_FAILED ? 500 : 900
    SoundBeep feedbackFrequency, 120
    return result.state != MeasurementState.AUTOMATION_FAILED
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
