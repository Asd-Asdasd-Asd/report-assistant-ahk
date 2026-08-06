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

^!F12::RunMxNMAnnotationCleanupField()

RunMxNMAnnotationCleanupField() {
    foregroundBefore := WinExist("A")
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    measurement := MxNMMeasurementProvider.ReadSuvMax()
    cleanup := 0
    if measurement.state = MeasurementState.FOUND {
        cleanup := MxNMAnnotationCleaner.DeleteAll(
            MxNMCleanupFieldContextValue(
                measurement.context, "targetActionHwnd", 0
            ),
            MxNMCleanupFieldContextValue(
                measurement.context, "targetActionPid", 0
            )
        )
    }
    foregroundAfter := WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY
    outputPath := A_Temp "\MedExAHK\mxnm_annotation_cleanup_field.txt"
    SplitPath outputPath, , &outputDirectory
    DirCreate outputDirectory
    try FileDelete outputPath
    FileAppend(
        FormatMxNMAnnotationCleanupFieldOutput(
            measurement,
            cleanup,
            foregroundBefore = foregroundAfter,
            mouseBeforeX = mouseAfterX && mouseBeforeY = mouseAfterY
        ),
        outputPath,
        "UTF-8"
    )
    ToolTip(
        IsObject(cleanup) && cleanup.ok
            ? "SUV 标注清除测试通过"
            : "SUV 标注清除未通过`n请检查结果文件"
    )
    SetTimer (() => ToolTip()), -3500
}

FormatMxNMAnnotationCleanupFieldOutput(
    measurement,
    cleanup,
    foregroundUnchanged,
    mouseUnchanged
) {
    lines := [
        "Test=MxNMAnnotationCleanup",
        "InitialMeasurementState=" measurement.state,
        "InitialTargetResolutionMs=" MxNMCleanupFieldContextValue(
            measurement.context, "targetResolutionMs", 0
        ),
        "InitialMeasurementTotalMs=" MxNMCleanupFieldContextValue(
            measurement.context, "totalReadMs", 0
        ),
        "CleanupInvoked=" MxNMCleanupFieldBoolean(IsObject(cleanup)),
        "CleanupState=" (
            IsObject(cleanup) ? cleanup.code : "NOT_INVOKED"
        ),
        "CommandInvoked=" MxNMCleanupFieldBoolean(
            IsObject(cleanup) && cleanup.commandInvoked
        ),
        "ConfirmationDetected=" MxNMCleanupFieldBoolean(
            IsObject(cleanup) && cleanup.confirmationDetected
        ),
        "VerificationState=" (
            IsObject(cleanup) ? cleanup.verificationState : ""
        ),
        "ForegroundUnchanged=" MxNMCleanupFieldBoolean(
            foregroundUnchanged
        ),
        "MouseUnchanged=" MxNMCleanupFieldBoolean(mouseUnchanged)
    ]
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n"
}

MxNMCleanupFieldContextValue(context, key, defaultValue := 0) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}

MxNMCleanupFieldBoolean(value) {
    return value ? "true" : "false"
}
