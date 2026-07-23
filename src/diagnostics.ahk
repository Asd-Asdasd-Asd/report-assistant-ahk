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
        "preflightStage=" SafeDiagnosticValue(MedExContextValue(context, "preflightStage", "")),
        "readinessReason=" SafeDiagnosticValue(MedExContextValue(context, "readinessReason", "")),
        "uiaActivationAttempted=" FormatDiagnosticBoolean(MedExContextValue(context, "uiaActivationAttempted", false)),
        "uiaRootReacquireCount=" SafeDiagnosticValue(MedExContextValue(context, "uiaRootReacquireCount", 0)),
        "exactAnchorQueryCount=" SafeDiagnosticValue(MedExContextValue(context, "exactAnchorQueryCount", 0)),
        "exactAnchorCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "exactAnchorCandidateCount", 0)),
        "readinessElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "readinessElapsedMs", "UNKNOWN")),
        "processName=" SafeDiagnosticValue(MedExContextValue(context, "foregroundProcess", "UNKNOWN")),
        "windowHandle=" SafeDiagnosticValue(MedExContextValue(context, "foregroundWindowHandle", "UNKNOWN")),
        "medExVersion=" SafeDiagnosticValue(MedExContextValue(context, "medExVersion", "UNKNOWN")),
        "profileValidationMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "profileValidationMedExVersion", "UNKNOWN")),
        "calibratedMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "calibratedMedExVersion", "UNKNOWN")),
        "medExVersionMatchState=" SafeDiagnosticValue(MedExContextValue(context, "medExVersionMatchState", "UNKNOWN")),
        "candidateGProfileName=" SafeDiagnosticValue(MedExContextValue(context, "candidateGProfileName", "UNKNOWN")),
        "horizontalGeometryPolicy=" SafeDiagnosticValue(MedExContextValue(context, "horizontalGeometryPolicy", "UNKNOWN")),
        "regionAnchorScreenX=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorScreenX", "UNKNOWN")),
        "regionAnchorClientX=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorClientX", "UNKNOWN")),
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
        "medExVersion=" SafeDiagnosticValue(MedExContextValue(context, "medExVersion", "UNKNOWN")),
        "profileValidationMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "profileValidationMedExVersion", "UNKNOWN")),
        "calibratedMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "calibratedMedExVersion", "UNKNOWN")),
        "medExVersionMatchState=" SafeDiagnosticValue(MedExContextValue(context, "medExVersionMatchState", "UNKNOWN")),
        "medExVersionMetadataOverrideApplied=" FormatDiagnosticBoolean(MedExContextValue(context, "medExVersionMetadataOverrideApplied", false)),
        "uiaRootRect=" FormatDiagnosticRect(MedExContextValue(context, "uiaRootRect", 0)),
        "documentFound=" FormatDiagnosticBoolean(MedExContextValue(context, "documentFound", false)),
        "documentRect=" FormatDiagnosticRect(MedExContextValue(context, "documentRect", 0)),
        "windowRect=" FormatDiagnosticRect(MedExContextValue(context, "windowRect", 0)),
        "clientRectScreen=" FormatDiagnosticRect(MedExContextValue(context, "clientRectScreen", 0)),
        "candidateGProfileName=" SafeDiagnosticValue(MedExContextValue(context, "candidateGProfileName", "UNKNOWN")),
        "horizontalGeometryPolicy=" SafeDiagnosticValue(MedExContextValue(context, "horizontalGeometryPolicy", "UNKNOWN")),
        "regionAnchorScreenX=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorScreenX", "UNKNOWN")),
        "regionAnchorClientX=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorClientX", "UNKNOWN")),
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
        "ColorResetStrategy=" SafeDiagnosticValue(MedExContextValue(context, "colorResetStrategy", "UNKNOWN")),
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
        "ProfileValidationMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "profileValidationMedExVersion", "UNKNOWN")),
        "CalibratedMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "calibratedMedExVersion", "UNKNOWN")),
        "MedExVersionMatchState=" SafeDiagnosticValue(MedExContextValue(context, "medExVersionMatchState", "UNKNOWN")),
        "MedExVersionMetadataOverrideApplied=" FormatDiagnosticBoolean(MedExContextValue(context, "medExVersionMetadataOverrideApplied", false)),
        "UiaRootRect=" FormatDiagnosticRect(MedExContextValue(context, "uiaRootRect", 0)),
        "DocumentFound=" FormatDiagnosticBoolean(MedExContextValue(context, "documentFound", false)),
        "DocumentRect=" FormatDiagnosticRect(MedExContextValue(context, "documentRect", 0)),
        "DocumentLookupPath=" SafeDiagnosticValue(MedExContextValue(context, "documentLookupPath", "UNKNOWN")),
        "DocumentLookupDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "documentLookupDurationMs", "UNKNOWN")),
        "WindowRect=" FormatDiagnosticRect(MedExContextValue(context, "windowRect", 0)),
        "ClientRectScreen=" FormatDiagnosticRect(MedExContextValue(context, "clientRectScreen", 0)),
        "LayoutProfileName=" SafeDiagnosticValue(MedExContextValue(context, "layoutProfileName", "UNKNOWN")),
        "RegionAnchorName=" SafeDiagnosticValue(MedExContextValue(context, "regionAnchorName", "UNKNOWN")),
        "RegionAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "regionAnchorFound", false)),
        "RegionAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "regionAnchorRect", 0)),
        "RegionFilterDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "regionFilterDurationMs", "UNKNOWN")),
        "FontSizeAnchorPattern=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeAnchorPattern", "UNKNOWN")),
        "FontSizeCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeCandidateCount", 0)),
        "FontSizeAnchorMatchedName=" SafeDiagnosticValue(MedExContextValue(context, "fontSizeAnchorMatchedName", "UNKNOWN")),
        "FontSizeAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "fontSizeAnchorFound", false)),
        "FontSizeAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "fontSizeAnchorRect", 0)),
        "RawFontSizePatternMatchCount=" SafeDiagnosticValue(MedExContextValue(context, "rawFontSizePatternMatchCount", 0)),
        "RawFontSizeMatchedNames=" FormatDiagnosticList(MedExContextValue(context, "rawFontSizeMatchedNames", 0)),
        "ValidFontSizeRectCount=" SafeDiagnosticValue(MedExContextValue(context, "validFontSizeRectCount", 0)),
        "AlignedFontSizeCandidateCount=" SafeDiagnosticValue(MedExContextValue(context, "alignedFontSizeCandidateCount", 0)),
        "SelectedFontSizeAnchorFound=" FormatDiagnosticBoolean(MedExContextValue(context, "selectedFontSizeAnchorFound", false)),
        "IgnoredFontSizeAnchorCount=" SafeDiagnosticValue(MedExContextValue(context, "ignoredFontSizeAnchorCount", 0)),
        "IgnoredFontSizeReasons=" FormatDiagnosticList(MedExContextValue(context, "ignoredFontSizeReasons", 0)),
        "FontFilterDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "fontFilterDurationMs", "UNKNOWN")),
        "AnchorSnapshotScope=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotScope", "UNKNOWN")),
        "AnchorSnapshotMode=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotMode", "UNKNOWN")),
        "UseCachedAnchorSnapshot=" FormatDiagnosticBoolean(MedExContextValue(context, "useCachedAnchorSnapshot", false)),
        "AnchorSnapshotAttemptCount=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotAttemptCount", 0)),
        "AnchorSnapshotTextElementCount=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotTextElementCount", 0)),
        "AnchorSnapshotQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotQueryDurationMs", "UNKNOWN")),
        "AnchorSnapshotConversionDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotConversionDurationMs", "UNKNOWN")),
        "AnchorSnapshotPropertyReadFailureCount=" SafeDiagnosticValue(MedExContextValue(context, "anchorSnapshotPropertyReadFailureCount", 0)),
        "FontAnchorRetryEligible=" FormatDiagnosticBoolean(MedExContextValue(context, "fontAnchorRetryEligible", false)),
        "FontAnchorRetryEnabled=" FormatDiagnosticBoolean(MedExContextValue(context, "fontAnchorRetryEnabled", false)),
        "FontAnchorRetryUsed=" FormatDiagnosticBoolean(MedExContextValue(context, "fontAnchorRetryUsed", false)),
        "FontAnchorRetryDelayMs=" SafeDiagnosticValue(MedExContextValue(context, "fontAnchorRetryDelayMs", 0)),
        "FirstAnchorSnapshotQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "firstAnchorSnapshotQueryDurationMs", "UNKNOWN")),
        "FontAnchorRetryQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "fontAnchorRetryQueryDurationMs", "UNKNOWN")),
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
        "TriggerClickCount=" SafeDiagnosticValue(MedExContextValue(context, "triggerClickCount", 0)),
        "TriggerRetryCount=" SafeDiagnosticValue(MedExContextValue(context, "triggerRetryCount", 0)),
        "BlackItemFound=" FormatDiagnosticBoolean(MedExContextValue(context, "blackItemFound", false)),
        "InvokeAvailable=" FormatDiagnosticBoolean(MedExContextValue(context, "invokeAvailable", false)),
        "BlackItemInvokeSucceeded=" FormatDiagnosticBoolean(MedExContextValue(context, "blackItemInvokeSucceeded", false)),
        "FinalInsertionColorVisuallyValidated=" FormatDiagnosticBoolean(MedExContextValue(context, "finalInsertionColorVisuallyValidated", false)),
        "RetryCount=" SafeDiagnosticValue(MedExContextValue(context, "retryCount", 0)),
        "ImmediateLookupSucceeded=" FormatDiagnosticBoolean(MedExContextValue(context, "immediateLookupSucceeded", false)),
        "RetryUsed=" FormatDiagnosticBoolean(MedExContextValue(context, "retryUsed", false)),
        "BlackLookupAttemptCount=" SafeDiagnosticValue(MedExContextValue(context, "blackLookupAttemptCount", 0)),
        "BlackLookupScope=" SafeDiagnosticValue(MedExContextValue(context, "blackLookupScope", "UNKNOWN")),
        "MenuLookupStrategy=" SafeDiagnosticValue(MedExContextValue(context, "menuLookupStrategy", "UNKNOWN")),
        "MenuOpenTimeoutMs=" SafeDiagnosticValue(MedExContextValue(context, "menuOpenTimeoutMs", "UNKNOWN")),
        "MenuPollIntervalMs=" SafeDiagnosticValue(MedExContextValue(context, "menuPollIntervalMs", "UNKNOWN")),
        "MenuPreLookupSettleMs=" SafeDiagnosticValue(MedExContextValue(context, "menuPreLookupSettleMs", 0)),
        "BlackLookupFirstRootDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "blackLookupFirstRootDurationMs", "UNKNOWN")),
        "BlackLookupFirstQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "blackLookupFirstQueryDurationMs", "UNKNOWN")),
        "BlackLookupRetryRootDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "blackLookupRetryRootDurationMs", "UNKNOWN")),
        "BlackLookupRetryQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(context, "blackLookupRetryQueryDurationMs", "UNKNOWN")),
        "BeforeMenuClickFocusedElementControlType=" SafeDiagnosticValue(MedExContextValue(context, "beforeMenuClickFocusedElementControlType", "UNKNOWN")),
        "AfterBlackInvokeFocusedElementControlType=" SafeDiagnosticValue(MedExContextValue(context, "afterBlackInvokeFocusedElementControlType", "UNKNOWN")),
        "BeforeCursorRestoreFocusedElementControlType=" SafeDiagnosticValue(MedExContextValue(context, "beforeCursorRestoreFocusedElementControlType", "UNKNOWN")),
        "FocusedElementBeforeCursorRestore=" FormatFocusedElementSummary(context, "beforeCursorRestore"),
        "CursorRestoreRequestedCount=" SafeDiagnosticValue(MedExContextValue(context, "cursorRestoreRequestedCount", "UNKNOWN")),
        "CursorRestoreCommandSent=" FormatDiagnosticBoolean(MedExContextValue(context, "cursorRestoreCommandSent", false)),
        "ForegroundHwndBeforeCursorRestore=" SafeDiagnosticValue(MedExContextValue(context, "foregroundHwndBeforeCursorRestore", "UNKNOWN")),
        "CursorRestoreTargetHwnd=" SafeDiagnosticValue(MedExContextValue(context, "cursorRestoreTargetHwnd", "UNKNOWN")),
        "MenuDetectionElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "menuDetectionElapsedMs", "UNKNOWN")),
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

FormatMedExPerformanceTimingResult(operation, performanceContext) {
    resetContext := Map()
    if IsObject(operation) && operation.HasOwnProp("reset")
        && IsObject(operation.reset) && operation.reset.HasOwnProp("context")
        && Type(operation.reset.context) = "Map" {
        resetContext := operation.reset.context
    }

    fields := [
        "Test=MedExProductionInsertionTiming",
        "AppVersion=" AppMetadata.Version,
        "OperationResult=" SafeDiagnosticValue(IsObject(operation) && operation.HasOwnProp("code") ? operation.code : "UNKNOWN"),
        "ColorResetResult=" SafeDiagnosticValue(IsObject(operation) && operation.HasOwnProp("reset") && IsObject(operation.reset) ? operation.reset.code : "UNKNOWN"),
        "ColorResetStrategy=" SafeDiagnosticValue(MedExContextValue(resetContext, "colorResetStrategy", "UNKNOWN")),
        "ClipboardRestoreSucceeded=" FormatDiagnosticBoolean(IsObject(operation) && operation.HasOwnProp("clipboardRestoreSucceeded") ? operation.clipboardRestoreSucceeded : false),
        "ImmediateLookupSucceeded=" FormatDiagnosticBoolean(MedExContextValue(resetContext, "immediateLookupSucceeded", false)),
        "RetryUsed=" FormatDiagnosticBoolean(MedExContextValue(resetContext, "retryUsed", false)),
        "RegionQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(resetContext, "anchorSnapshotQueryDurationMs", "UNKNOWN")),
        "AnchorSnapshotMode=" SafeDiagnosticValue(MedExContextValue(resetContext, "anchorSnapshotMode", "UNKNOWN")),
        "UseCachedAnchorSnapshot=" FormatDiagnosticBoolean(MedExContextValue(resetContext, "useCachedAnchorSnapshot", false)),
        "FontQueryDurationMs=SHARED_SNAPSHOT",
        "FontFilterDurationMs=" SafeDiagnosticValue(MedExContextValue(resetContext, "fontFilterDurationMs", "UNKNOWN")),
        "RawFontSizePatternMatchCount=" SafeDiagnosticValue(MedExContextValue(resetContext, "rawFontSizePatternMatchCount", 0)),
        "FontAnchorRetryUsed=" FormatDiagnosticBoolean(MedExContextValue(resetContext, "fontAnchorRetryUsed", false)),
        "FontAnchorRetryEnabled=" FormatDiagnosticBoolean(MedExContextValue(resetContext, "fontAnchorRetryEnabled", false)),
        "MenuLookupStrategy=" SafeDiagnosticValue(MedExContextValue(resetContext, "menuLookupStrategy", "UNKNOWN")),
        "MenuOpenTimeoutMs=" SafeDiagnosticValue(MedExContextValue(resetContext, "menuOpenTimeoutMs", "UNKNOWN")),
        "MenuPollIntervalMs=" SafeDiagnosticValue(MedExContextValue(resetContext, "menuPollIntervalMs", "UNKNOWN")),
        "TriggerClickCount=" SafeDiagnosticValue(MedExContextValue(resetContext, "triggerClickCount", 0)),
        "BlackLookupAttemptCount=" SafeDiagnosticValue(MedExContextValue(resetContext, "blackLookupAttemptCount", 0)),
        "BlackLookupScope=" SafeDiagnosticValue(MedExContextValue(resetContext, "blackLookupScope", "UNKNOWN")),
        "BlackLookupFirstQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(resetContext, "blackLookupFirstQueryDurationMs", "UNKNOWN")),
        "BlackLookupRetryQueryDurationMs=" SafeDiagnosticValue(MedExContextValue(resetContext, "blackLookupRetryQueryDurationMs", "UNKNOWN")),
        "FocusedElementBeforeCursorRestore=" FormatFocusedElementSummary(resetContext, "beforeCursorRestore"),
        "FocusedElementAfterBlackInvoke=" FormatFocusedElementSummary(resetContext, "afterBlackInvoke"),
        "CursorRestoreRequestedCount=" SafeDiagnosticValue(MedExContextValue(resetContext, "cursorRestoreRequestedCount", "UNKNOWN")),
        "CursorRestoreCommandSent=" FormatDiagnosticBoolean(MedExContextValue(resetContext, "cursorRestoreCommandSent", false)),
        "ForegroundHwndBeforeCursorRestore=" SafeDiagnosticValue(MedExContextValue(resetContext, "foregroundHwndBeforeCursorRestore", "UNKNOWN")),
        "CursorRestoreTargetHwnd=" SafeDiagnosticValue(MedExContextValue(resetContext, "cursorRestoreTargetHwnd", "UNKNOWN")),
        "FinalInsertionColorVisuallyValidated=MANUAL_REQUIRED",
        "CursorPositionVisuallyValidated=MANUAL_REQUIRED",
        "ImmediateContinuedTypingRemainedBlack=MANUAL_REQUIRED",
        "HotstringTriggeredMs=" PerformanceTimestampValue(performanceContext, "HotstringTriggeredMs"),
        "PasteCommandSentMs=" PerformanceTimestampValue(performanceContext, "PasteCommandSentMs"),
        "ColorResetStartedMs=" PerformanceTimestampValue(performanceContext, "ColorResetStartedMs"),
        "ArrowClickSentMs=" PerformanceTimestampValue(performanceContext, "ArrowClickSentMs"),
        "BlackClickSentMs=" PerformanceTimestampValue(performanceContext, "BlackClickSentMs"),
        "FunctionReturnedMs=" PerformanceTimestampValue(performanceContext, "FunctionReturnedMs"),
        "HotstringStartMs=" PerformanceTimestampValue(performanceContext, "HotstringStartMs"),
        "PasteSentMs=" PerformanceTimestampValue(performanceContext, "PasteSentMs"),
        "PasteDispatchSettleCompletedMs=" PerformanceTimestampValue(performanceContext, "PasteDispatchSettleCompletedMs"),
        "ClipboardRestoreStartedMs=" PerformanceTimestampValue(performanceContext, "ClipboardRestoreStartedMs"),
        "ClipboardRestoreCompletedMs=" PerformanceTimestampValue(performanceContext, "ClipboardRestoreCompletedMs"),
        "SafeMinPasteToRestoreMs=" ClipboardTransactionDefaults.SafeMinPasteToRestoreMs,
        "ClipboardRestoreSafetyWaitMs=" PerformanceTimestampValue(performanceContext, "ClipboardRestoreSafetyWaitMs"),
        "ColorResetStartMs=" PerformanceTimestampValue(performanceContext, "ColorResetStartMs"),
        "ColorResetReturnedMs=" PerformanceTimestampValue(performanceContext, "ColorResetReturnedMs"),
        "FailureFeedbackStartedMs=" PerformanceTimestampValue(performanceContext, "FailureFeedbackStartedMs"),
        "FailureFeedbackCompletedMs=" PerformanceTimestampValue(performanceContext, "FailureFeedbackCompletedMs"),
        "AnchorResolutionCompletedMs=" PerformanceTimestampValue(performanceContext, "AnchorResolutionCompletedMs"),
        "MenuClickSentMs=" PerformanceTimestampValue(performanceContext, "MenuClickSentMs"),
        "ImmediateBlackLookupCompletedMs=" PerformanceTimestampValue(performanceContext, "ImmediateBlackLookupCompletedMs"),
        "RetryLookupCompletedMs=" PerformanceTimestampValue(performanceContext, "RetryLookupCompletedMs"),
        "BlackInvokeCompletedMs=" PerformanceTimestampValue(performanceContext, "BlackInvokeCompletedMs"),
        "CursorRestoreSentMs=" PerformanceTimestampValue(performanceContext, "CursorRestoreSentMs"),
        "HotstringReturnMs=" PerformanceTimestampValue(performanceContext, "HotstringReturnMs"),
        "PasteStageMs=" PerformanceDuration(performanceContext, "HotstringStartMs", "PasteSentMs"),
        "ClipboardRestoreMs=" PerformanceDuration(performanceContext, "PasteSentMs", "ClipboardRestoreCompletedMs"),
        "AnchorResolutionMs=" PerformanceDuration(performanceContext, "ColorResetStartMs", "AnchorResolutionCompletedMs"),
        "ColorResetCoreMs=" PerformanceDuration(performanceContext, "ColorResetStartMs", "ColorResetReturnedMs"),
        "FailureFeedbackMs=" PerformanceDuration(performanceContext, "FailureFeedbackStartedMs", "FailureFeedbackCompletedMs"),
        "ClickToLookupMs=" PerformanceDuration(performanceContext, "MenuClickSentMs", "ImmediateBlackLookupCompletedMs"),
        "BlackLookupMs=" PerformanceDurationToFirstAvailable(performanceContext, "MenuClickSentMs", ["RetryLookupCompletedMs", "ImmediateBlackLookupCompletedMs"]),
        "InvokeMs=" PerformanceDurationFromFirstAvailable(performanceContext, ["RetryLookupCompletedMs", "ImmediateBlackLookupCompletedMs"], "BlackInvokeCompletedMs"),
        "PostInvokeToCursorMs=" PerformanceDuration(performanceContext, "BlackInvokeCompletedMs", "CursorRestoreSentMs"),
        "TotalHotstringMs=" PerformanceDuration(performanceContext, "HotstringStartMs", "HotstringReturnMs"),
        "TotalHotstringDurationMs=" PerformanceDuration(performanceContext, "HotstringStartMs", "HotstringReturnMs"),
        "TriggerToBlackClickMs=" PerformanceDuration(performanceContext, "HotstringTriggeredMs", "BlackClickSentMs"),
        "PasteToClipboardRestoreMs=" PerformanceDuration(performanceContext, "PasteCommandSentMs", "ClipboardRestoreStartedMs"),
        "BlackClickToClipboardRestoreMs=" PerformanceDuration(performanceContext, "BlackClickSentMs", "ClipboardRestoreStartedMs")
    ]
    return JoinDiagnosticFields(fields, "`r`n") "`r`n"
}

PerformanceTimestampValue(context, key) {
    return Type(context) = "Map" && context.Has(key) ? context[key] : "UNKNOWN"
}

PerformanceDuration(context, startKey, endKey) {
    if Type(context) != "Map" || !context.Has(startKey) || !context.Has(endKey)
        return "UNKNOWN"
    return context[endKey] - context[startKey]
}

PerformanceDurationToFirstAvailable(context, startKey, endKeys) {
    if Type(context) != "Map" || !context.Has(startKey)
        return "UNKNOWN"
    for key in endKeys {
        if context.Has(key)
            return context[key] - context[startKey]
    }
    return "UNKNOWN"
}

PerformanceDurationFromFirstAvailable(context, startKeys, endKey) {
    if Type(context) != "Map" || !context.Has(endKey)
        return "UNKNOWN"
    for key in startKeys {
        if context.Has(key)
            return context[endKey] - context[key]
    }
    return "UNKNOWN"
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

FormatDiagnosticList(values) {
    if Type(values) != "Array"
        return "UNKNOWN"
    output := ""
    for index, value in values
        output .= (index = 1 ? "" : "|") SafeDiagnosticValue(value, 80)
    return output = "" ? "NONE" : output
}

FormatFocusedElementSummary(context, prefix) {
    if !MedExContextValue(context, prefix "FocusedElementCaptured", false)
        return "UNKNOWN"
    return "ControlType:" SafeDiagnosticValue(
        MedExContextValue(context, prefix "FocusedElementControlType", "UNKNOWN"), 40
    ) ",ClassName:" SafeDiagnosticValue(
        MedExContextValue(context, prefix "FocusedElementClassName", "UNKNOWN"), 80
    ) ",AutomationId:" SafeDiagnosticValue(
        MedExContextValue(context, prefix "FocusedElementAutomationId", "UNKNOWN"), 80
    ) ",Hwnd:" SafeDiagnosticValue(
        MedExContextValue(context, prefix "FocusedElementNativeWindowHandle", "UNKNOWN"), 40
    )
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
