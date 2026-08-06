#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\measurement_model.ahk
#Include ..\..\src\measurement_parser.ahk
#Include ..\..\src\measurement_clipboard.ahk
#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk
#Include ..\..\src\context_measurement_provider.ahk
#Include ..\..\src\mxnm_measurement_target_resolver.ahk
#Include ..\..\src\mxnm_context_target_session.ahk
#Include ..\..\src\mxnm_measurement_provider.ahk
#Include ..\..\src\mxnm_annotation_cleaner.ahk

CoordMode "Mouse", "Screen"

MxNMMeasurementProvider.PrepareTargetPlan()

^!F11::RunMxNMLineAxesField(false)
^!F12::RunMxNMLineAxesField(true)

RunMxNMLineAxesField(runCleanup) {
    foregroundBefore := WinExist("A")
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    measurement := MxNMMeasurementProvider.ReadLineAxes()
    cleanup := 0
    if runCleanup && measurement.state = MeasurementState.FOUND {
        cleanup := MxNMAnnotationCleaner.DeleteAll(
            MxNMLineFieldContextValue(
                measurement.context, "targetActionHwnd", 0
            ),
            MxNMLineFieldContextValue(
                measurement.context, "targetActionPid", 0
            ),
            0,
            MeasurementType.LINE_AXES
        )
    }
    foregroundAfter := WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY
    outputPath := A_Temp "\MedExAHK\mxnm_line_axes_field.txt"
    SplitPath outputPath, , &outputDirectory
    DirCreate outputDirectory
    try FileDelete outputPath
    FileAppend(
        FormatMxNMLineAxesFieldOutput(
            measurement,
            cleanup,
            foregroundBefore = foregroundAfter,
            mouseBeforeX = mouseAfterX && mouseBeforeY = mouseAfterY
        ),
        outputPath,
        "UTF-8"
    )
    feedback := "LineAxes State=" measurement.state
    if measurement.state = MeasurementState.FOUND
        feedback .= "`n" measurement.formattedValue
    if IsObject(cleanup)
        feedback .= "`nCleanup=" cleanup.code
    ToolTip feedback
    SetTimer (() => ToolTip()), -3500
}

FormatMxNMLineAxesFieldOutput(
    measurement,
    cleanup,
    foregroundUnchanged,
    mouseUnchanged
) {
    context := measurement.context
    lines := [
        "Test=MxNMLineAxes",
        "MeasurementState=" measurement.state,
        "FailureReason=" measurement.failureReason,
        "ComponentCount=" measurement.components.Length,
        "TargetResolutionMs=" MxNMLineFieldContextValue(
            context, "targetResolutionMs", 0
        ),
        "MeasurementTotalMs=" MxNMLineFieldContextValue(
            context, "totalReadMs", 0
        ),
        "ClipboardCaptureSucceeded=" MxNMLineFieldBoolean(
            MxNMLineFieldContextValue(
                context, "clipboardCaptureSucceeded", false
            )
        ),
        "ClipboardRestoreSucceeded=" MxNMLineFieldBoolean(
            MxNMLineFieldContextValue(
                context, "clipboardRestoreSucceeded", false
            )
        ),
        "CleanupInvoked=" MxNMLineFieldBoolean(IsObject(cleanup)),
        "CleanupState=" (
            IsObject(cleanup) ? cleanup.code : "NOT_INVOKED"
        ),
        "VerificationState=" (
            IsObject(cleanup) ? cleanup.verificationState : ""
        ),
        "ForegroundUnchanged=" MxNMLineFieldBoolean(
            foregroundUnchanged
        ),
        "MouseUnchanged=" MxNMLineFieldBoolean(mouseUnchanged)
    ]
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n"
}

MxNMLineFieldContextValue(context, key, defaultValue := 0) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}

MxNMLineFieldBoolean(value) {
    return value ? "true" : "false"
}
