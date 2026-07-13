DefaultMedExColorResetLogPath() {
    return A_Temp "\MedExAHK\medex-color-reset-development.log"
}

WriteMedExColorResetDiagnostic(result, logPath := "") {
    if logPath = ""
        logPath := DefaultMedExColorResetLogPath()

    SplitPath logPath, , &logDirectory
    if logDirectory != "" && !DirExist(logDirectory)
        DirCreate logDirectory

    FileAppend FormatMedExColorResetLogLine(result) "`r`n", logPath, "UTF-8"
    return logPath
}

FormatMedExColorResetLogLine(result) {
    context := result.context
    fields := [
        "timestamp=" SafeDiagnosticValue(MedExContextValue(context, "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"))),
        "action=MedExColorReset",
        "resultCode=" SafeDiagnosticValue(result.code),
        "processName=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "windowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "documentRect=" FormatDiagnosticRect(MedExContextValue(context, "documentRect", 0)),
        "fontSizeRect=" FormatDiagnosticRect(MedExContextValue(context, "fontSizeRect", 0)),
        "numberButtonRect=" FormatDiagnosticRect(MedExContextValue(context, "numberButtonRect", 0)),
        "calculatedScreenPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedScreenPoint", 0)),
        "calculatedClientPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedClientPoint", 0)),
        "retryCount=" SafeDiagnosticValue(MedExContextValue(context, "retryCount", 0)),
        "lookupElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "lookupElapsedMs", "UNKNOWN")),
        "elapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN")),
        "exceptionType=" SafeDiagnosticValue(MedExContextValue(context, "exceptionType", "")),
        "exceptionMessage=" SafeDiagnosticValue(MedExContextValue(context, "exceptionMessage", "")),
        "ahkVersion=" SafeDiagnosticValue(A_AhkVersion),
        "uiaLibrary=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibrary", "UNKNOWN")),
        "uiaLibraryVersion=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibraryVersion", "UNKNOWN")),
        "uiaInterfaceVersion=" SafeDiagnosticValue(MedExContextValue(context, "uiaInterfaceVersion", "UNKNOWN"))
    ]
    return JoinDiagnosticFields(fields, " ")
}

FormatMedExFieldDebugResult(result) {
    context := result.context
    fields := [
        "Test=MedExColorReset",
        "Result=" SafeDiagnosticValue(result.code),
        "Process=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "ProcessNameConfirmed=" SafeDiagnosticValue(MedExContextValue(context, "processNameConfirmed", false)),
        "WindowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "Resolution=" SafeDiagnosticValue(MedExContextValue(context, "resolution", "UNKNOWN")),
        "Dpi=" SafeDiagnosticValue(MedExContextValue(context, "dpi", "UNKNOWN")),
        "DisplayScaling=" SafeDiagnosticValue(MedExContextValue(context, "displayScaling", "UNKNOWN")),
        "MedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "medExVersion", "UNKNOWN")),
        "DocumentRect=" FormatDiagnosticRect(MedExContextValue(context, "documentRect", 0)),
        "FontSizeRect=" FormatDiagnosticRect(MedExContextValue(context, "fontSizeRect", 0)),
        "NumberButtonRect=" FormatDiagnosticRect(MedExContextValue(context, "numberButtonRect", 0)),
        "Ratio=" SafeDiagnosticValue(MedExContextValue(context, "ratio", "UNKNOWN")),
        "CalculatedScreenPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedScreenPoint", 0)),
        "CalculatedClientPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedClientPoint", 0)),
        "BlackColorFound=" SafeDiagnosticValue(MedExContextValue(context, "blackColorFound", false)),
        "InvokeAvailable=" SafeDiagnosticValue(MedExContextValue(context, "invokeAvailable", false)),
        "InvokeSucceeded=" SafeDiagnosticValue(MedExContextValue(context, "invokeSucceeded", false)),
        "RetryCount=" SafeDiagnosticValue(MedExContextValue(context, "retryCount", 0)),
        "LookupElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "lookupElapsedMs", "UNKNOWN")),
        "ElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN")),
        "AHKVersion=" SafeDiagnosticValue(A_AhkVersion),
        "UIALibrary=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibrary", "UNKNOWN")),
        "UIALibraryVersion=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibraryVersion", "UNKNOWN")),
        "UIAInterfaceVersion=" SafeDiagnosticValue(MedExContextValue(context, "uiaInterfaceVersion", "UNKNOWN")),
        "ExceptionType=" SafeDiagnosticValue(MedExContextValue(context, "exceptionType", "")),
        "ExceptionMessage=" SafeDiagnosticValue(MedExContextValue(context, "exceptionMessage", ""))
    ]
    return JoinDiagnosticFields(fields, "`r`n") "`r`n"
}

MedExContextValue(context, key, defaultValue) {
    if Type(context) = "Map" && context.Has(key)
        return context[key]
    return defaultValue
}

FormatDiagnosticRect(rect) {
    if Type(rect) != "Map"
        return "UNKNOWN"
    for key in ["l", "t", "r", "b"] {
        if !rect.Has(key)
            return "UNKNOWN"
    }
    return rect["l"] "," rect["t"] "," rect["r"] "," rect["b"]
}

FormatDiagnosticPoint(point) {
    if Type(point) != "Map" || !point.Has("x") || !point.Has("y")
        return "UNKNOWN"
    return point["x"] "," point["y"]
}

SafeDiagnosticValue(value, maxLength := 240) {
    if value = true
        return "true"
    if value = false
        return "false"

    safeValue := String(value)
    safeValue := StrReplace(safeValue, "`r", " ")
    safeValue := StrReplace(safeValue, "`n", " ")
    safeValue := StrReplace(safeValue, "=", ":")
    if StrLen(safeValue) > maxLength
        safeValue := SubStr(safeValue, 1, maxLength) "..."
    return safeValue
}

JoinDiagnosticFields(fields, delimiter) {
    output := ""
    for index, field in fields
        output .= (index = 1 ? "" : delimiter) field
    return output
}
