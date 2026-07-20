#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; Candidate G2 controlled test build. Run this script by itself; do not run the
; generated release or another field-debug script at the same time.
#Include ..\src\app_metadata.ahk
#Include ..\src\config.example.ahk
#Include ..\src\window_guard.ahk
#Include ..\src\utils.ahk
#Include ..\src\Lib\UIA.ahk
#Include ..\src\clipboard_html.ahk
#Include ..\src\medex_color_reset_logic.ahk
#Include ..\src\medex_candidate_g_logic.ahk
#Include ..\src\diagnostics.ahk
#Include ..\src\adapters\medex_report_editor.ahk
#Include ..\src\report_editor.ahk

CANDIDATE_G2_TEST_LOG := A_Temp "\MedExAHK\candidate_g2_test.txt"

class Step4CaretSettleAbDefaults {
    static ControlSettleMs := 50
    static CandidateSettleMs := 0
}

:*?:;red::
{
    operation := InsertRedFigureTextAndRestoreState("（见图）", CandidateG2TestOptions())
    WriteCandidateG2TestOperation("red", operation)
}

:*?:;fzg::
{
    operation := RunFzgInsertion(CandidateG2TestOptions())
    WriteCandidateG2TestOperation("fzg", operation)
}

F12::
{
    result := ResetMedExInsertionColor(CandidateG2TestOptions())
    WriteCandidateG2TestReset("resetOnly", result)
}

; Step 5: exercise the production interaction chain with mismatched version
; metadata. Layout, signature, and foreground gates remain real.
^!F11::
{
    result := ResetMedExInsertionColor(CandidateG2TestOptions("9.9.9.9"))
    WriteCandidateG2TestReset("step5VersionMetadataMismatch", result)
}

; Caret A/B control: current Candidate G2 reset chain, then Left 4.
^!F8::
{
    operation := RunCandidateG2FzgWithColorResetDiagnostic()
    WriteCandidateG2TestOperation("fzgWithG2Reset", operation)
}

; Step 4 control: keep the legacy 50 ms settle before Left 4.
^!F9::RunCandidateG2FzgWithoutColorResetDiagnostic(
    "step4Control50Ms",
    Step4CaretSettleAbDefaults.ControlSettleMs
)

; Step 4 candidate: remove only the settle before Left 4.
^!F10::RunCandidateG2FzgWithoutColorResetDiagnostic(
    "step4Candidate0Ms",
    Step4CaretSettleAbDefaults.CandidateSettleMs
)

CandidateG2TestOptions(versionMetadataOverride := "") {
    options := Map(
        "colorResetStrategy", MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED,
        "diagnosticMode", "candidateG2"
    )
    if versionMetadataOverride != ""
        options["candidateGMedExVersionMetadataOverride"] := versionMetadataOverride
    return options
}

RunCandidateG2FzgWithColorResetDiagnostic() {
    SendText("放射性摄取增高，SUVmax约")
    operation := InsertRedFigureTextAndRestoreState("（见图）", CandidateG2TestOptions())
    if operation.ok {
        Sleep Step4CaretSettleAbDefaults.ControlSettleMs
        operation.reset.context["cursorRestoreRequestedCount"] := 4
        Send("{Left 4}")
        operation.reset.context["cursorRestoreCommandSent"] := true
    }
    return operation
}

RunCandidateG2FzgWithoutColorResetDiagnostic(testCase, settleDelayMs) {
    startedAt := A_TickCount
    SendText("放射性摄取增高，SUVmax约")
    pasteResult := PasteRedFigureTextDetailed("（见图）")
    cursorRestoreRequestedCount := 0
    cursorRestoreCommandSent := false
    if pasteResult.pasteDispatched && pasteResult.clipboardRestoreSucceeded {
        if settleDelayMs > 0
            Sleep settleDelayMs
        cursorRestoreRequestedCount := 4
        Send("{Left 4}")
        cursorRestoreCommandSent := true
    }
    WriteCandidateG2CaretAbResult(
        testCase,
        pasteResult,
        settleDelayMs,
        cursorRestoreRequestedCount,
        cursorRestoreCommandSent,
        A_TickCount - startedAt
    )
}

WriteCandidateG2TestOperation(testCase, operation) {
    if IsObject(operation.reset)
        WriteCandidateG2TestReset(testCase, operation.reset, operation.code)
    else
        WriteCandidateG2TestLine(testCase, operation.code, "UNKNOWN", Map())
}

WriteCandidateG2TestReset(testCase, resetResult, operationCode := "RESET_ONLY") {
    WriteCandidateG2TestLine(testCase, operationCode, resetResult.code, resetResult.context)
}

WriteCandidateG2TestLine(testCase, operationCode, resetCode, context) {
    global CANDIDATE_G2_TEST_LOG
    line := JoinDiagnosticFields([
        "Timestamp=" FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "Test=MedExCandidateG2ControlledProductionPath",
        "TestCase=" SafeDiagnosticValue(testCase),
        "OperationResult=" SafeDiagnosticValue(operationCode),
        "ColorResetResult=" SafeDiagnosticValue(resetCode),
        "ColorResetStrategy=" SafeDiagnosticValue(MedExContextValue(context, "colorResetStrategy", "UNKNOWN")),
        "MedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "medExVersion", "UNKNOWN")),
        "ProfileValidationMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "profileValidationMedExVersion", "UNKNOWN")),
        "CalibratedMedExVersion=" SafeDiagnosticValue(MedExContextValue(context, "calibratedMedExVersion", "UNKNOWN")),
        "MedExVersionMatchState=" SafeDiagnosticValue(MedExContextValue(context, "medExVersionMatchState", "UNKNOWN")),
        "MedExVersionMetadataOverrideApplied=" FormatDiagnosticBoolean(MedExContextValue(context, "medExVersionMetadataOverrideApplied", false)),
        "RegionAnchorRect=" FormatDiagnosticRect(MedExContextValue(context, "regionAnchorRect", 0)),
        "ArrowPoint=" FormatDiagnosticPoint(MedExContextValue(context, "arrowPoint", 0)),
        "BlackPoint=" FormatDiagnosticPoint(MedExContextValue(context, "blackPoint", 0)),
        "ArrowClickSent=" FormatDiagnosticBoolean(MedExContextValue(context, "arrowClickSent", false)),
        "PopupSignatureMatched=" FormatDiagnosticBoolean(MedExContextValue(context, "popupSignatureMatched", false)),
        "PopupSignatureSampleCount=" SafeDiagnosticValue(MedExContextValue(context, "popupSignatureSampleCount", 0)),
        "BlackClickSent=" FormatDiagnosticBoolean(MedExContextValue(context, "blackClickSent", false)),
        "MouseRestored=" FormatDiagnosticBoolean(MedExContextValue(context, "mouseRestored", false)),
        "CursorRestoreRequestedCount=" SafeDiagnosticValue(MedExContextValue(context, "cursorRestoreRequestedCount", "UNKNOWN")),
        "CursorRestoreCommandSent=" FormatDiagnosticBoolean(MedExContextValue(context, "cursorRestoreCommandSent", false)),
        "ElapsedMs=" SafeDiagnosticValue(MedExContextValue(context, "elapsedMs", "UNKNOWN"))
    ], " ") "`r`n"
    try {
        SplitPath CANDIDATE_G2_TEST_LOG, , &logDirectory
        if logDirectory != "" && !DirExist(logDirectory)
            DirCreate logDirectory
        FileAppend line, CANDIDATE_G2_TEST_LOG, "UTF-8"
    }
}

WriteCandidateG2CaretAbResult(testCase, pasteResult, settleDelayMs,
    requestedCount, commandSent, elapsedMs) {
    global CANDIDATE_G2_TEST_LOG
    line := JoinDiagnosticFields([
        "Timestamp=" FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "Test=MedExCandidateG2CaretOrderAB",
        "TestCase=" SafeDiagnosticValue(testCase),
        "PasteDispatched=" FormatDiagnosticBoolean(pasteResult.pasteDispatched),
        "ClipboardRestoreSucceeded=" FormatDiagnosticBoolean(pasteResult.clipboardRestoreSucceeded),
        "ColorResetStrategy=SKIPPED_FOR_LEGACY_ORDER_AB",
        "ColorResetResult=NOT_RUN",
        "SettleDelayMs=" SafeDiagnosticValue(settleDelayMs),
        "CursorRestoreRequestedCount=" SafeDiagnosticValue(requestedCount),
        "CursorRestoreCommandSent=" FormatDiagnosticBoolean(commandSent),
        "ElapsedMs=" SafeDiagnosticValue(elapsedMs)
    ], " ") "`r`n"
    try {
        SplitPath CANDIDATE_G2_TEST_LOG, , &logDirectory
        if logDirectory != "" && !DirExist(logDirectory)
            DirCreate logDirectory
        FileAppend line, CANDIDATE_G2_TEST_LOG, "UTF-8"
    }
}
