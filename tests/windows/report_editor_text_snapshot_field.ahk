#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk

CoordMode "Mouse", "Screen"

global ReportTextSnapshotRunCount := 0
global ReportTextSnapshotOutputPath :=
    A_Temp "\MedExAHK\report_editor_text_snapshot_field.txt"

SplitPath ReportTextSnapshotOutputPath, , &reportSnapshotOutputDirectory
DirCreate reportSnapshotOutputDirectory
try FileDelete ReportTextSnapshotOutputPath

^!F7::RunReportEditorTextSnapshotField()

RunReportEditorTextSnapshotField() {
    global ReportTextSnapshotRunCount
    global ReportTextSnapshotOutputPath

    ReportTextSnapshotRunCount += 1
    foregroundBefore := WinExist("A")
    MouseGetPos &mouseBeforeX, &mouseBeforeY
    try result := CaptureReportEditorTextSnapshot()
    catch as snapshotError {
        result := NewReportEditorTextSnapshotResult()
        result["state"] := "UNEXPECTED_ERROR"
        result["unexpectedExceptionType"] := Type(snapshotError)
    }
    foregroundAfter := WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY
    result["foregroundUnchanged"] := foregroundBefore = foregroundAfter
    result["mouseUnchanged"] :=
        mouseBeforeX = mouseAfterX && mouseBeforeY = mouseAfterY

    FileAppend(
        FormatReportEditorTextSnapshotField(
            ReportTextSnapshotRunCount,
            result
        ),
        ReportTextSnapshotOutputPath,
        "UTF-8"
    )
    feedback := "Report snapshot " ReportTextSnapshotRunCount
        . ": " result["state"]
    if result["caretOffsetResolved"]
        feedback .= "`nCaretOffset=" result["caretOffset"]
    ToolTip feedback
    SetTimer (() => ToolTip()), -2500
}

CaptureReportEditorTextSnapshot() {
    startedAt := A_TickCount
    result := NewReportEditorTextSnapshotResult()
    foregroundHwnd := WinExist("A")
    if !foregroundHwnd {
        result["state"] := "FOREGROUND_NOT_FOUND"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }
    try foregroundProcess := WinGetProcessName(
        "ahk_id " foregroundHwnd
    )
    catch {
        result["state"] := "FOREGROUND_PROCESS_UNAVAILABLE"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }
    result["foregroundProcessApproved"] :=
        IsReportSnapshotApprovedProcess(foregroundProcess)
    if !result["foregroundProcessApproved"] {
        result["state"] := "WRONG_PROCESS"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }
    try foregroundPid := WinGetPID("ahk_id " foregroundHwnd)
    catch {
        result["state"] := "FOREGROUND_PROCESS_UNAVAILABLE"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }

    try focusedElement := UIA.GetFocusedElement()
    catch {
        result["state"] := "FOCUSED_ELEMENT_UNAVAILABLE"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }
    result["focusedElementCaptured"] := true
    try result["focusedControlType"] := focusedElement.ControlType
    catch
        result["focusedControlType"] := "UNKNOWN"

    documentResult := ResolveFocusedReportDocument(
        focusedElement,
        foregroundPid
    )
    result["documentAncestorDepth"] := documentResult.depth
    if !documentResult.ok {
        result["state"] := documentResult.state
        return FinishReportEditorTextSnapshot(result, startedAt)
    }
    documentElement := documentResult.element
    result["documentResolved"] := true
    try result["documentHasKeyboardFocus"] :=
        documentElement.HasKeyboardFocus = true
    catch
        result["documentHasKeyboardFocus"] := false
    try result["documentIsKeyboardFocusable"] :=
        documentElement.IsKeyboardFocusable = true
    catch
        result["documentIsKeyboardFocusable"] := false
    try result["textPatternAvailable"] :=
        documentElement.IsTextPatternAvailable = true
    catch
        result["textPatternAvailable"] := false
    try result["textPattern2Available"] :=
        documentElement.IsTextPattern2Available = true
    catch
        result["textPattern2Available"] := false
    try result["valuePatternAvailable"] :=
        documentElement.IsValuePatternAvailable = true
    catch
        result["valuePatternAvailable"] := false
    try result["textEditPatternAvailable"] :=
        documentElement.IsTextEditPatternAvailable = true
    catch
        result["textEditPatternAvailable"] := false
    try result["legacyAccessiblePatternAvailable"] :=
        documentElement.IsLegacyIAccessiblePatternAvailable = true
    catch
        result["legacyAccessiblePatternAvailable"] := false
    if !result["textPatternAvailable"] {
        result["state"] := "TEXT_PATTERN_UNAVAILABLE"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }

    try {
        textPattern := documentElement.TextPattern
        documentRange := textPattern.DocumentRange
        documentText := documentRange.GetText(-1)
        result["textLength"] := StrLen(documentText)
        result["textReadSucceeded"] := true
        if result["valuePatternAvailable"] {
            try {
                valueText := documentElement.ValuePattern.Value
                result["valueLength"] := StrLen(valueText)
                result["textValueEqual"] := documentText = valueText
                result["valueReadSucceeded"] := true
                valueText := ""
            }
        }
        documentText := ""
        try result["supportedTextSelection"] :=
            textPattern.SupportedTextSelection
        catch
            result["supportedTextSelection"] := "UNKNOWN"

        selectionRanges := textPattern.GetSelection()
        result["selectionReadSucceeded"] := true
        result["selectionRangeCount"] := selectionRanges.Length
        if selectionRanges.Length = 1 {
            selectionRange := selectionRanges[1]
            selectedText := selectionRange.GetText(-1)
            result["selectionLength"] := StrLen(selectedText)
            selectedText := ""
            result["selectionStart"] := ReportTextRangeOffset(
                documentRange,
                selectionRange,
                UIA.TextPatternRangeEndpoint.Start
            )
            result["selectionEnd"] := ReportTextRangeOffset(
                documentRange,
                selectionRange,
                UIA.TextPatternRangeEndpoint.End
            )
            try result["selectionActiveEnd"] :=
                selectionRange.GetAttributeValue(
                    UIA.TextAttribute.SelectionActiveEnd
                )
        }

        if result["textPattern2Available"] {
            try {
                caretRange := textPattern.GetCaretRange(&caretIsActive)
                result["caretActive"] := caretIsActive = true
                result["caretCandidateOffset"] := ReportTextRangeOffset(
                    documentRange,
                    caretRange,
                    UIA.TextPatternRangeEndpoint.Start
                )
                if result["caretActive"] {
                    result["caretOffset"] :=
                        result["caretCandidateOffset"]
                    result["caretOffsetResolved"] := true
                    result["caretSource"] := "TEXT_PATTERN_2_ACTIVE"
                } else {
                    result["caretSource"] :=
                        "TEXT_PATTERN_2_INACTIVE"
                }
            }
        }
        if !result["caretOffsetResolved"]
            && !result["textPattern2Available"]
            && result["documentHasKeyboardFocus"]
            && result["selectionRangeCount"] = 1
            && result["selectionLength"] = 0 {
            result["caretOffset"] := result["selectionStart"]
            result["caretOffsetResolved"] := true
            result["caretActive"] := true
            result["caretSource"] := "DEGENERATE_SELECTION"
        }
    } catch {
        result["state"] := "TEXT_RANGE_READ_FAILED"
        return FinishReportEditorTextSnapshot(result, startedAt)
    }

    result["state"] := result["caretOffsetResolved"]
        ? "READY_FOR_CARET_VALIDATION"
        : "TEXT_READY_CARET_UNRESOLVED"
    return FinishReportEditorTextSnapshot(result, startedAt)
}

ResolveFocusedReportDocument(focusedElement, foregroundPid) {
    currentElement := focusedElement
    loop 12 {
        try currentPid := currentElement.ProcessId
        catch
            return {
                ok: false,
                state: "FOCUSED_ELEMENT_PROCESS_UNAVAILABLE",
                depth: A_Index - 1,
                element: 0
            }
        if currentPid != foregroundPid {
            return {
                ok: false,
                state: "FOCUSED_ELEMENT_WRONG_PROCESS",
                depth: A_Index - 1,
                element: 0
            }
        }
        try {
            if currentElement.ControlType = UIA.ControlType.Document {
                return {
                    ok: true,
                    state: "OK",
                    depth: A_Index - 1,
                    element: currentElement
                }
            }
        }
        parentElement := UIA.RawViewWalker.TryGetParentElement(
            currentElement
        )
        if !IsObject(parentElement)
            break
        currentElement := parentElement
    }
    return {
        ok: false,
        state: "FOCUSED_DOCUMENT_NOT_FOUND",
        depth: 12,
        element: 0
    }
}

ReportTextRangeOffset(documentRange, targetRange, targetEndpoint) {
    prefixRange := documentRange.Clone()
    prefixRange.MoveEndpointByRange(
        UIA.TextPatternRangeEndpoint.End,
        targetRange,
        targetEndpoint
    )
    prefixText := prefixRange.GetText(-1)
    offset := StrLen(prefixText)
    prefixText := ""
    return offset
}

NewReportEditorTextSnapshotResult() {
    return Map(
        "state", "UNEXPECTED_ERROR",
        "foregroundProcessApproved", false,
        "focusedElementCaptured", false,
        "focusedControlType", "UNKNOWN",
        "documentResolved", false,
        "documentAncestorDepth", 0,
        "documentHasKeyboardFocus", false,
        "documentIsKeyboardFocusable", false,
        "textPatternAvailable", false,
        "textPattern2Available", false,
        "valuePatternAvailable", false,
        "textEditPatternAvailable", false,
        "legacyAccessiblePatternAvailable", false,
        "textReadSucceeded", false,
        "textLength", 0,
        "valueReadSucceeded", false,
        "valueLength", 0,
        "textValueEqual", false,
        "supportedTextSelection", "UNKNOWN",
        "selectionReadSucceeded", false,
        "selectionRangeCount", 0,
        "selectionLength", 0,
        "selectionStart", -1,
        "selectionEnd", -1,
        "selectionActiveEnd", "UNKNOWN",
        "caretOffsetResolved", false,
        "caretOffset", -1,
        "caretCandidateOffset", -1,
        "caretActive", false,
        "caretSource", "UNRESOLVED",
        "unexpectedExceptionType", "",
        "foregroundUnchanged", false,
        "mouseUnchanged", false,
        "elapsedMs", 0
    )
}

FinishReportEditorTextSnapshot(result, startedAt) {
    result["elapsedMs"] := A_TickCount - startedAt
    return result
}

IsReportSnapshotApprovedProcess(processName) {
    normalized := StrLower(String(processName))
    return normalized = "medexworkstation.exe"
        || normalized = "medexworkstations.exe"
}

FormatReportEditorTextSnapshotField(runNumber, result) {
    lines := [
        "Test=ReportEditorTextSnapshot",
        "Run=" runNumber,
        "State=" result["state"],
        "ForegroundProcessApproved=" ReportSnapshotBoolean(
            result["foregroundProcessApproved"]
        ),
        "FocusedElementCaptured=" ReportSnapshotBoolean(
            result["focusedElementCaptured"]
        ),
        "FocusedControlType=" ReportSnapshotSafeScalar(
            result["focusedControlType"]
        ),
        "DocumentResolved=" ReportSnapshotBoolean(
            result["documentResolved"]
        ),
        "DocumentAncestorDepth=" result["documentAncestorDepth"],
        "DocumentHasKeyboardFocus=" ReportSnapshotBoolean(
            result["documentHasKeyboardFocus"]
        ),
        "DocumentIsKeyboardFocusable=" ReportSnapshotBoolean(
            result["documentIsKeyboardFocusable"]
        ),
        "TextPatternAvailable=" ReportSnapshotBoolean(
            result["textPatternAvailable"]
        ),
        "TextPattern2Available=" ReportSnapshotBoolean(
            result["textPattern2Available"]
        ),
        "ValuePatternAvailable=" ReportSnapshotBoolean(
            result["valuePatternAvailable"]
        ),
        "TextEditPatternAvailable=" ReportSnapshotBoolean(
            result["textEditPatternAvailable"]
        ),
        "LegacyAccessiblePatternAvailable=" ReportSnapshotBoolean(
            result["legacyAccessiblePatternAvailable"]
        ),
        "TextReadSucceeded=" ReportSnapshotBoolean(
            result["textReadSucceeded"]
        ),
        "TextLength=" result["textLength"],
        "ValueReadSucceeded=" ReportSnapshotBoolean(
            result["valueReadSucceeded"]
        ),
        "ValueLength=" result["valueLength"],
        "TextValueEqual=" ReportSnapshotBoolean(
            result["textValueEqual"]
        ),
        "SupportedTextSelection=" ReportSnapshotSafeScalar(
            result["supportedTextSelection"]
        ),
        "SelectionReadSucceeded=" ReportSnapshotBoolean(
            result["selectionReadSucceeded"]
        ),
        "SelectionRangeCount=" result["selectionRangeCount"],
        "SelectionLength=" result["selectionLength"],
        "SelectionStart=" result["selectionStart"],
        "SelectionEnd=" result["selectionEnd"],
        "SelectionActiveEnd=" ReportSnapshotSafeScalar(
            result["selectionActiveEnd"]
        ),
        "CaretOffsetResolved=" ReportSnapshotBoolean(
            result["caretOffsetResolved"]
        ),
        "CaretOffset=" result["caretOffset"],
        "CaretCandidateOffset=" result["caretCandidateOffset"],
        "CaretActive=" ReportSnapshotBoolean(result["caretActive"]),
        "CaretSource=" result["caretSource"],
        "UnexpectedExceptionType=" result["unexpectedExceptionType"],
        "ForegroundUnchanged=" ReportSnapshotBoolean(
            result["foregroundUnchanged"]
        ),
        "MouseUnchanged=" ReportSnapshotBoolean(
            result["mouseUnchanged"]
        ),
        "ElapsedMs=" result["elapsedMs"]
    ]
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output "`r`n`r`n"
}

ReportSnapshotBoolean(value) {
    return value ? "true" : "false"
}

ReportSnapshotSafeScalar(value) {
    valueType := Type(value)
    if valueType = "String"
        || valueType = "Integer"
        || valueType = "Float"
        return value
    return "UNAVAILABLE"
}
