DefaultMedExColorResetLogPath() {
    return A_Temp "\MedExAHK\field\medex-color-reset-field.log"
}

DefaultMedExColorResetFailureLogPath() {
    return A_Temp "\MedExAHK\logs\medex-color-reset-failures.log"
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

WriteMedExColorResetFailureDiagnostic(result, logPath := "") {
    if logPath = ""
        logPath := DefaultMedExColorResetFailureLogPath()

    SplitPath logPath, , &logDirectory
    if logDirectory != "" && !DirExist(logDirectory)
        DirCreate logDirectory

    FileAppend FormatMedExColorResetFailureLogLine(result) "`r`n", logPath, "UTF-8"
    return logPath
}

FormatMedExColorResetFailureLogLine(result) {
    context := result.context
    fields := [
        "timestamp=" SafeDiagnosticValue(MedExContextValue(context, "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"))),
        "appVersion=" SafeDiagnosticValue(MedExContextValue(context, "appVersion", "UNKNOWN")),
        "action=MedExColorReset",
        "resultCode=" SafeDiagnosticValue(result.code),
        "processName=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "windowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "processReason=" SafeDiagnosticValue(MedExContextValue(context, "processReason", "")),
        "anchorSelectionReason=" SafeDiagnosticValue(MedExContextValue(context, "anchorSelectionReason", "")),
        "geometryReason=" SafeDiagnosticValue(MedExContextValue(context, "geometryReason", "")),
        "coordinateSpaceReason=" SafeDiagnosticValue(MedExContextValue(context, "coordinateSpaceReason", "")),
        "foregroundGuardReason=" SafeDiagnosticValue(MedExContextValue(context, "foregroundGuardReason", "")),
        "elapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN"))
    ]
    return JoinDiagnosticFields(fields, " ")
}

FormatMedExColorResetLogLine(result) {
    context := result.context
    fields := [
        "timestamp=" SafeDiagnosticValue(MedExContextValue(context, "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"))),
        "appVersion=" SafeDiagnosticValue(MedExContextValue(context, "appVersion", "UNKNOWN")),
        "action=MedExColorReset",
        "resultCode=" SafeDiagnosticValue(result.code),
        "automationChainResult=" SafeDiagnosticValue(MedExContextValue(context, "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED")),
        "processName=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "provisionalProcessCandidateAccepted=" FormatDiagnosticBoolean(MedExContextValue(context, "provisionalProcessCandidateAccepted", false)),
        "processNameConfirmed=" FormatDiagnosticBoolean(MedExContextValue(context, "processNameConfirmed", false)),
        "windowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "uiaRootRect=" FormatDiagnosticRect(MedExContextValue(context, "uiaRootRect", 0)),
        "documentFound=" FormatDiagnosticBoolean(MedExContextValue(context, "documentFound", false)),
        "documentRect=" FormatDiagnosticRect(MedExContextValue(context, "documentRect", 0)),
        "windowRect=" FormatDiagnosticRect(MedExContextValue(context, "windowRect", 0)),
        "clientRectScreen=" FormatDiagnosticRect(MedExContextValue(context, "clientRectScreen", 0)),
        "layoutProfileName=" SafeDiagnosticValue(MedExContextValue(context, "layoutProfileName", "UNKNOWN")),
        "regionAnchorName=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorName", "UNKNOWN")),
        "regionAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "regionAnchorFound", false)),
        "regionAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "regionAnchorRect", 0)),
        "fontSizeAnchorPattern=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeAnchorPattern", "UNKNOWN")),
        "fontSizeCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeCandidateCount", 0)),
        "fontSizeAnchorMatchedName=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeAnchorMatchedName", "UNKNOWN")),
        "fontSizeAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "fontSizeAnchorFound", false)),
        "fontSizeAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "fontSizeAnchorRect", 0)),
        "optionalRightAnchorName=" SafeDiagnosticValue(MedExContextValue(context, "optionalRightAnchorName", "")),
        "optionalRightAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "optionalRightAnchorFound", false)),
        "optionalRightAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "optionalRightAnchorRect", 0)),
        "colorArrowOffsetX=" SafeDiagnosticValue(MedExContextValue(context, "colorArrowOffsetX", "UNKNOWN")),
        "colorArrowOffsetY=" SafeDiagnosticValue(MedExContextValue(context, "colorArrowOffsetY", "UNKNOWN")),
        "calculatedScreenPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedScreenPoint", 0)),
        "calculatedClientPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedClientPoint", 0)),
        "anchorSelectionReason=" SafeDiagnosticValue(MedExContextValue(context, "anchorSelectionReason", "")),
        "geometryReason=" SafeDiagnosticValue(MedExContextValue(context, "geometryReason", "")),
        "coordinateSpaceReason=" SafeDiagnosticValue(MedExContextValue(context, "coordinateSpaceReason", "")),
        "foregroundGuardReason=" SafeDiagnosticValue(MedExContextValue(context, "foregroundGuardReason", "")),
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
        "AppVersion=" SafeDiagnosticValue(MedExContextValue(context, "appVersion", "UNKNOWN")),
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
        "DocumentFound=" FormatDiagnosticBoolean(MedExContextValue(context, "documentFound", false)),
        "DocumentRect=" FormatDiagnosticRect(MedExContextValue(context, "documentRect", 0)),
        "WindowRect=" FormatDiagnosticRect(MedExContextValue(context, "windowRect", 0)),
        "ClientRectScreen=" FormatDiagnosticRect(MedExContextValue(context, "clientRectScreen", 0)),
        "LayoutProfileName=" SafeDiagnosticValue(MedExContextValue(context, "layoutProfileName", "UNKNOWN")),
        "RegionAnchorName=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorName", "UNKNOWN")),
        "RegionAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "regionAnchorFound", false)),
        "RegionAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "regionAnchorRect", 0)),
        "FontSizeAnchorPattern=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeAnchorPattern", "UNKNOWN")),
        "FontSizeCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeCandidateCount", 0)),
        "FontSizeAnchorMatchedName=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeAnchorMatchedName", "UNKNOWN")),
        "FontSizeAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "fontSizeAnchorFound", false)),
        "FontSizeAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "fontSizeAnchorRect", 0)),
        "OptionalRightAnchorName=" SafeDiagnosticValue(MedExContextValue(context, "optionalRightAnchorName", "")),
        "OptionalRightAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "optionalRightAnchorFound", false)),
        "OptionalRightAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "optionalRightAnchorRect", 0)),
        "ColorArrowOffsetX=" SafeDiagnosticValue(MedExContextValue(context, "colorArrowOffsetX", "UNKNOWN")),
        "ColorArrowOffsetY=" SafeDiagnosticValue(MedExContextValue(context, "colorArrowOffsetY", "UNKNOWN")),
        "CalculatedScreenPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedScreenPoint", 0)),
        "CalculatedClientPoint=" FormatDiagnosticPoint(MedExContextValue(context, "calculatedClientPoint", 0)),
        "VerticalOverlapRatio=" SafeDiagnosticValue(MedExContextValue(context, "verticalOverlapRatio", "UNKNOWN")),
        "RegionToFontDistance=" SafeDiagnosticValue(MedExContextValue(context, "regionToFontDistance", "UNKNOWN")),
        "FontToOptionalRightDistance=" SafeDiagnosticValue(MedExContextValue(context, "fontToOptionalRightDistance", "UNKNOWN")),
        "AnchorSelectionReason=" SafeDiagnosticValue(MedExContextValue(context, "anchorSelectionReason", "")),
        "GeometryReason=" SafeDiagnosticValue(MedExContextValue(context, "geometryReason", "")),
        "CoordinateSpaceReason=" SafeDiagnosticValue(MedExContextValue(context, "coordinateSpaceReason", "")),
        "ForegroundGuardReason=" SafeDiagnosticValue(MedExContextValue(context, "foregroundGuardReason", "")),
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
