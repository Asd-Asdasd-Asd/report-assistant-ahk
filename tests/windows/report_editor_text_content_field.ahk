#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk

^!F8::CopyReportEditorTextContentField()

CopyReportEditorTextContentField() {
    result := CaptureReportEditorTextContent()
    report := FormatReportEditorTextContent(result)

    A_Clipboard := report
    copied := ClipWait(2)
    feedback := copied
        ? "Report text content copied to clipboard.`n" result["state"]
        : "Report text content clipboard copy failed."
    ToolTip feedback
    SetTimer (() => ToolTip()), -3000
}

CaptureReportEditorTextContent() {
    startedAt := A_TickCount
    result := NewReportEditorTextContentResult()
    foregroundHwnd := WinExist("A")
    if !foregroundHwnd {
        result["state"] := "FOREGROUND_NOT_FOUND"
        return FinishReportEditorTextContent(result, startedAt)
    }
    try foregroundProcess := WinGetProcessName(
        "ahk_id " foregroundHwnd
    )
    catch {
        result["state"] := "FOREGROUND_PROCESS_UNAVAILABLE"
        return FinishReportEditorTextContent(result, startedAt)
    }
    result["foregroundProcess"] := foregroundProcess
    result["foregroundProcessApproved"] :=
        IsReportTextContentApprovedProcess(foregroundProcess)
    if !result["foregroundProcessApproved"] {
        result["state"] := "WRONG_PROCESS"
        return FinishReportEditorTextContent(result, startedAt)
    }
    try foregroundPid := WinGetPID("ahk_id " foregroundHwnd)
    catch {
        result["state"] := "FOREGROUND_PROCESS_UNAVAILABLE"
        return FinishReportEditorTextContent(result, startedAt)
    }

    try focusedElement := UIA.GetFocusedElement()
    catch as focusedError {
        result["state"] := "FOCUSED_ELEMENT_UNAVAILABLE"
        result["exceptionType"] := Type(focusedError)
        return FinishReportEditorTextContent(result, startedAt)
    }
    try result["focusedControlType"] := focusedElement.ControlType
    catch
        result["focusedControlType"] := "UNKNOWN"

    documentResult := ResolveReportTextContentDocument(
        focusedElement,
        foregroundPid
    )
    result["documentAncestorDepth"] := documentResult.depth
    if !documentResult.ok {
        result["state"] := documentResult.state
        return FinishReportEditorTextContent(result, startedAt)
    }
    documentElement := documentResult.element
    result["documentResolved"] := true

    try result["textPatternAvailable"] :=
        documentElement.IsTextPatternAvailable = true
    catch
        result["textPatternAvailable"] := false
    try result["valuePatternAvailable"] :=
        documentElement.IsValuePatternAvailable = true
    catch
        result["valuePatternAvailable"] := false

    if result["textPatternAvailable"] {
        try {
            result["textPatternText"] :=
                documentElement.TextPattern.DocumentRange.GetText(-1)
            result["textPatternReadSucceeded"] := true
        } catch as textPatternError {
            result["textPatternExceptionType"] := Type(textPatternError)
        }
    }
    if result["valuePatternAvailable"] {
        try {
            result["valuePatternText"] :=
                documentElement.ValuePattern.Value
            result["valuePatternReadSucceeded"] := true
        } catch as valuePatternError {
            result["valuePatternExceptionType"] := Type(valuePatternError)
        }
    }

    if result["textPatternReadSucceeded"]
        && result["valuePatternReadSucceeded"] {
        result["state"] := "TEXT_AND_VALUE_CAPTURED"
        result["textValueEqual"] :=
            result["textPatternText"] = result["valuePatternText"]
    } else if result["textPatternReadSucceeded"] {
        result["state"] := "TEXT_PATTERN_CAPTURED"
    } else if result["valuePatternReadSucceeded"] {
        result["state"] := "VALUE_PATTERN_CAPTURED"
    } else {
        result["state"] := "CONTENT_READ_FAILED"
    }
    return FinishReportEditorTextContent(result, startedAt)
}

ResolveReportTextContentDocument(focusedElement, foregroundPid) {
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

NewReportEditorTextContentResult() {
    return Map(
        "state", "UNEXPECTED_ERROR",
        "foregroundProcess", "UNKNOWN",
        "foregroundProcessApproved", false,
        "focusedControlType", "UNKNOWN",
        "documentResolved", false,
        "documentAncestorDepth", 0,
        "textPatternAvailable", false,
        "valuePatternAvailable", false,
        "textPatternReadSucceeded", false,
        "valuePatternReadSucceeded", false,
        "textPatternText", "",
        "valuePatternText", "",
        "textValueEqual", false,
        "textPatternExceptionType", "",
        "valuePatternExceptionType", "",
        "exceptionType", "",
        "elapsedMs", 0
    )
}

FinishReportEditorTextContent(result, startedAt) {
    result["elapsedMs"] := A_TickCount - startedAt
    return result
}

FormatReportEditorTextContent(result) {
    textPatternText := result["textPatternText"]
    valuePatternText := result["valuePatternText"]
    header := [
        "Test=ReportEditorTextContent",
        "Warning=CONTAINS_REPORT_TEXT",
        "State=" result["state"],
        "ForegroundProcess=" result["foregroundProcess"],
        "ForegroundProcessApproved="
            ReportTextContentBoolean(
                result["foregroundProcessApproved"]
            ),
        "FocusedControlType=" result["focusedControlType"],
        "DocumentResolved="
            ReportTextContentBoolean(result["documentResolved"]),
        "DocumentAncestorDepth=" result["documentAncestorDepth"],
        "TextPatternAvailable="
            ReportTextContentBoolean(result["textPatternAvailable"]),
        "ValuePatternAvailable="
            ReportTextContentBoolean(result["valuePatternAvailable"]),
        "TextPatternReadSucceeded="
            ReportTextContentBoolean(
                result["textPatternReadSucceeded"]
            ),
        "ValuePatternReadSucceeded="
            ReportTextContentBoolean(
                result["valuePatternReadSucceeded"]
            ),
        "TextPatternLength=" StrLen(textPatternText),
        "ValuePatternLength=" StrLen(valuePatternText),
        "TextValueEqual="
            ReportTextContentBoolean(result["textValueEqual"]),
        "TextPatternExceptionType="
            result["textPatternExceptionType"],
        "ValuePatternExceptionType="
            result["valuePatternExceptionType"],
        "ExceptionType=" result["exceptionType"],
        "ElapsedMs=" result["elapsedMs"]
    ]
    report := ""
    for index, line in header
        report .= (index = 1 ? "" : "`r`n") line
    report .= "`r`n`r`n"
        . "===== TextPattern.DocumentRange BEGIN =====`r`n"
        . textPatternText
        . "`r`n===== TextPattern.DocumentRange END =====`r`n`r`n"
        . "===== ValuePattern.Value BEGIN =====`r`n"
        . valuePatternText
        . "`r`n===== ValuePattern.Value END =====`r`n"
    return report
}

ReportTextContentBoolean(value) {
    return value ? "true" : "false"
}

IsReportTextContentApprovedProcess(processName) {
    normalized := StrLower(String(processName))
    return normalized = "medexworkstation.exe"
        || normalized = "medexworkstations.exe"
}
