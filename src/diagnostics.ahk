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
        "automationChainResult=" SafeDiagnosticValue(MedExContextValue(context, "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED")),
        "processName=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "provisionalProcessCandidateAccepted=" FormatDiagnosticBoolean(MedExContextValue(context, "provisionalProcessCandidateAccepted", false)),
        "processNameConfirmed=" FormatDiagnosticBoolean(MedExContextValue(context, "processNameConfirmed", false)),
        "windowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "uiaRootRect=" FormatDiagnosticRect(MedExContextValue(context, "uiaRootRect", 0)),
        "fontSizeAnchorRects=" FormatDiagnosticRectList(MedExContextValue(context, "fontSizeAnchorRects", 0)),
        "numberButtonAnchorRects=" FormatDiagnosticRectList(MedExContextValue(context, "numberButtonAnchorRects", 0)),
        "toolbarCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "toolbarCandidateCount", 0)),
        "toolbarCandidateSelected=" FormatDiagnosticBoolean(MedExContextValue(context, "toolbarCandidateSelected", false)),
        "selectedToolbarIndex=" SafeDiagnosticValue(MedExContextValue(context, "selectedToolbarIndex", 0)),
        "selectedFontSizeRect=" FormatDiagnosticRect(MedExContextValue(context, "selectedFontSizeRect", 0)),
        "selectedNumberButtonRect=" FormatDiagnosticRect(MedExContextValue(context, "selectedNumberButtonRect", 0)),
        "calculatedScreenPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedScreenPoint", 0)),
        "calculatedClientPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedClientPoint", 0)),
        "colorMenuClickSent=" FormatDiagnosticBoolean(MedExContextValue(context, "colorMenuClickSent", false)),
        "blackItemFound=" FormatDiagnosticBoolean(MedExContextValue(context, "blackItemFound", false)),
        "blackItemInvokeSucceeded=" FormatDiagnosticBoolean(MedExContextValue(context, "blackItemInvokeSucceeded", false)),
        "finalInsertionColorVisuallyValidated=" FormatDiagnosticBoolean(MedExContextValue(context, "finalInsertionColorVisuallyValidated", false)),
        "retryCount=" SafeDiagnosticValue(MedExContextValue(context, "retryCount", 0)),
        "lookupElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "lookupElapsedMs", "UNKNOWN")),
        "elapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN")),
        "exceptionType=" SafeDiagnosticValue(MedExContextValue(context, "exceptionType", "")),
        "exceptionMessage=" SafeDiagnosticValue(MedExContextValue(context, "exceptionMessage", "")),
        "ahkVersion=" SafeDiagnosticValue(A_AhkVersion),
        "uiaLibrary=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibrary", "UNKNOWN")),
        "uiaLibraryVersionPinned=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibraryVersionPinned", "UNKNOWN")),
        "uiaLibraryVersionRuntime=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibraryVersionRuntime", "UNKNOWN")),
        "uiaInterfaceVersion=" SafeDiagnosticValue(MedExContextValue(context, "uiaInterfaceVersion", "UNKNOWN"))
    ]
    return JoinDiagnosticFields(fields, " ")
}

FormatMedExFieldDebugResult(result) {
    context := result.context
    fields := [
        "Test=MedExColorReset",
        "ResultCode=" SafeDiagnosticValue(result.code),
        "AutomationChainResult=" SafeDiagnosticValue(MedExContextValue(context, "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED")),
        "FinalValidationState=" (MedExContextValue(context, "finalInsertionColorVisuallyValidated", false) ? "VISUALLY_VALIDATED" : "FINAL_COLOR_PENDING_VISUAL_VALIDATION"),
        "Process=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "ProvisionalProcessCandidateAccepted=" FormatDiagnosticBoolean(MedExContextValue(context, "provisionalProcessCandidateAccepted", false)),
        "ProcessNameConfirmed=" FormatDiagnosticBoolean(MedExContextValue(context, "processNameConfirmed", false)),
        "WindowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "Resolution=" SafeDiagnosticValue(MedExContextValue(context, "resolution", "UNKNOWN")),
        "Dpi=" SafeDiagnosticValue(MedExContextValue(context, "dpi", "UNKNOWN")),
        "DisplayScaling=" SafeDiagnosticValue(MedExContextValue(context, "displayScaling", "UNKNOWN")),
        "MedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "medExVersion", "UNKNOWN")),
        "UiaRootRect=" FormatDiagnosticRect(MedExContextValue(context, "uiaRootRect", 0)),
        "FontSizeAnchorRects=" FormatDiagnosticRectList(MedExContextValue(context, "fontSizeAnchorRects", 0)),
        "NumberButtonAnchorRects=" FormatDiagnosticRectList(MedExContextValue(context, "numberButtonAnchorRects", 0)),
        "ToolbarCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "toolbarCandidateCount", 0)),
        "ToolbarCandidateSelected=" FormatDiagnosticBoolean(MedExContextValue(context, "toolbarCandidateSelected", false)),
        "SelectedToolbarIndex=" SafeDiagnosticValue(MedExContextValue(context, "selectedToolbarIndex", 0)),
        "SelectedFontSizeRect=" FormatDiagnosticRect(MedExContextValue(context, "selectedFontSizeRect", 0)),
        "SelectedNumberButtonRect=" FormatDiagnosticRect(MedExContextValue(context, "selectedNumberButtonRect", 0)),
        "Ratio=" SafeDiagnosticValue(MedExContextValue(context, "ratio", "UNKNOWN")),
        "CalculatedScreenPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedScreenPoint", 0)),
        "CalculatedClientPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedClientPoint", 0)),
        "ColorMenuClickSent=" FormatDiagnosticBoolean(MedExContextValue(context, "colorMenuClickSent", false)),
        "BlackItemFound=" FormatDiagnosticBoolean(MedExContextValue(context, "blackItemFound", false)),
        "InvokeAvailable=" FormatDiagnosticBoolean(MedExContextValue(context, "invokeAvailable", false)),
        "BlackItemInvokeSucceeded=" FormatDiagnosticBoolean(MedExContextValue(context, "blackItemInvokeSucceeded", false)),
        "FinalInsertionColorVisuallyValidated=" FormatDiagnosticBoolean(MedExContextValue(context, "finalInsertionColorVisuallyValidated", false)),
        "RetryCount=" SafeDiagnosticValue(MedExContextValue(context, "retryCount", 0)),
        "LookupElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "lookupElapsedMs", "UNKNOWN")),
        "ElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN")),
        "AHKVersion=" SafeDiagnosticValue(A_AhkVersion),
        "UIALibrary=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibrary", "UNKNOWN")),
        "UIALibraryVersionPinned=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibraryVersionPinned", "UNKNOWN")),
        "UIALibraryVersionRuntime=" SafeDiagnosticValue(MedExContextValue(context, "uiaLibraryVersionRuntime", "UNKNOWN")),
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

FormatDiagnosticRectList(rectangles) {
    if Type(rectangles) != "Array"
        return "UNKNOWN"
    output := ""
    for index, rect in rectangles
        output .= (index = 1 ? "" : "|") FormatDiagnosticRect(rect)
    return output = "" ? "NONE" : output
}

SafeDiagnosticValue(value, maxLength := 240) {
    safeValue := String(value)
    safeValue := StrReplace(safeValue, "`r", " ")
    safeValue := StrReplace(safeValue, "`n", " ")
    safeValue := StrReplace(safeValue, "=", ":")
    if StrLen(safeValue) > maxLength
        safeValue := SubStr(safeValue, 1, maxLength) "..."
    return safeValue
}

FormatDiagnosticBoolean(value) {
    return value ? "true" : "false"
}

JoinDiagnosticFields(fields, delimiter) {
    output := ""
    for index, field in fields
        output .= (index = 1 ? "" : delimiter) field
    return output
}
