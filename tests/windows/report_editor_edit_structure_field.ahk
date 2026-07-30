#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk

CoordMode "Mouse", "Screen"

^!F8::CopyReportEditorEditStructureField()

CopyReportEditorEditStructureField() {
    foregroundBefore := WinExist("A")
    MouseGetPos &mouseX, &mouseY
    result := CaptureReportEditorEditStructure(mouseX, mouseY)
    result["foregroundUnchanged"] := foregroundBefore = WinExist("A")
    MouseGetPos &mouseAfterX, &mouseAfterY
    result["mouseUnchanged"] :=
        mouseX = mouseAfterX && mouseY = mouseAfterY
    report := FormatReportEditorEditStructure(result)

    A_Clipboard := report
    copied := ClipWait(2)
    feedback := copied
        ? "Report editor structure copied.`n" result["state"]
        : "Report editor structure clipboard copy failed."
    ToolTip feedback
    SetTimer (() => ToolTip()), -3000
}

CaptureReportEditorEditStructure(mouseX, mouseY) {
    startedAt := A_TickCount
    result := NewReportEditorEditStructureResult()
    result["mouseX"] := mouseX
    result["mouseY"] := mouseY
    foregroundHwnd := WinExist("A")
    if !foregroundHwnd {
        result["state"] := "FOREGROUND_NOT_FOUND"
        return FinishReportEditorEditStructure(result, startedAt)
    }
    try foregroundProcess := WinGetProcessName(
        "ahk_id " foregroundHwnd
    )
    catch {
        result["state"] := "FOREGROUND_PROCESS_UNAVAILABLE"
        return FinishReportEditorEditStructure(result, startedAt)
    }
    result["foregroundProcess"] := foregroundProcess
    result["foregroundProcessApproved"] :=
        IsReportEditStructureApprovedProcess(foregroundProcess)
    if !result["foregroundProcessApproved"] {
        result["state"] := "WRONG_PROCESS"
        return FinishReportEditorEditStructure(result, startedAt)
    }
    try foregroundPid := WinGetPID("ahk_id " foregroundHwnd)
    catch {
        result["state"] := "FOREGROUND_PROCESS_UNAVAILABLE"
        return FinishReportEditorEditStructure(result, startedAt)
    }

    try focusedElement := UIA.GetFocusedElement()
    catch as focusedError {
        result["state"] := "FOCUSED_ELEMENT_UNAVAILABLE"
        result["exceptionType"] := Type(focusedError)
        return FinishReportEditorEditStructure(result, startedAt)
    }
    result["focusedElement"] :=
        SnapshotReportEditStructureElement(focusedElement)

    documentResult := ResolveReportEditStructureDocument(
        focusedElement,
        foregroundPid
    )
    result["documentAncestorDepth"] := documentResult.depth
    if !documentResult.ok {
        result["state"] := documentResult.state
        return FinishReportEditorEditStructure(result, startedAt)
    }
    documentElement := documentResult.element
    result["documentResolved"] := true
    result["documentElement"] :=
        SnapshotReportEditStructureElement(documentElement)

    try {
        pointElement := UIA.ElementFromPoint(mouseX, mouseY)
        result["pointElement"] :=
            SnapshotReportEditStructureElement(pointElement)
        result["pointElementCaptured"] := true
        result["pointElementProcessMatches"] :=
            pointElement.ProcessId = foregroundPid
    } catch as pointError {
        result["pointElementExceptionType"] := Type(pointError)
    }

    try {
        smallestPointElement := UIA.SmallestElementFromPoint(
            mouseX,
            mouseY,
            documentElement
        )
        result["smallestPointElementCaptured"] := true
        result["smallestPointElement"] :=
            SnapshotReportEditStructureElement(smallestPointElement)
        result["smallestPointElementProcessMatches"] :=
            smallestPointElement.ProcessId = foregroundPid
        result["smallestPointChain"] :=
            CollectReportEditStructureParentChain(
                smallestPointElement,
                documentElement,
                foregroundPid
            )
    } catch as smallestPointError {
        result["smallestPointElementExceptionType"] :=
            Type(smallestPointError)
    }

    CollectReportEditStructureCandidates(
        documentElement,
        foregroundPid,
        result
    )
    result["state"] := "STRUCTURE_CAPTURED"
    return FinishReportEditorEditStructure(result, startedAt)
}

CollectReportEditStructureCandidates(
    documentElement,
    foregroundPid,
    result
) {
    querySpecs := [
        {
            label: "CONTROL_TYPE_EDIT",
            condition: {Type: "Edit"}
        },
        {
            label: "CONTROL_TYPE_DOCUMENT",
            condition: {Type: "Document"}
        },
        {
            label: "TEXT_PATTERN",
            condition: {IsTextPatternAvailable: true}
        },
        {
            label: "TEXT_EDIT_PATTERN",
            condition: {IsTextEditPatternAvailable: true}
        },
        {
            label: "FOCUSABLE_VALUE_PATTERN",
            condition: {
                IsKeyboardFocusable: true,
                IsValuePatternAvailable: true
            }
        }
    ]
    for querySpec in querySpecs {
        queryResult := {
            label: querySpec.label,
            succeeded: false,
            rawCount: 0,
            exceptionType: ""
        }
        try {
            elements := documentElement.FindElements(
                querySpec.condition
            )
            queryResult.succeeded := true
            queryResult.rawCount := elements.Length
            AddUniqueReportEditStructureCandidates(
                result["candidates"],
                elements,
                querySpec.label,
                documentElement,
                foregroundPid
            )
        } catch as queryError {
            queryResult.exceptionType := Type(queryError)
        }
        result["queries"].Push(queryResult)
    }
}

AddUniqueReportEditStructureCandidates(
    candidates,
    elements,
    source,
    documentElement,
    foregroundPid
) {
    global UIA
    for element in elements {
        existingCandidate := 0
        for candidate in candidates {
            try {
                if UIA.CompareElementsEx(candidate.element, element) {
                    existingCandidate := candidate
                    break
                }
            }
        }
        if IsObject(existingCandidate) {
            if !InStr(
                "|" existingCandidate.sources "|",
                "|" source "|"
            )
                existingCandidate.sources .= "|" source
            continue
        }
        if candidates.Length >= 100
            return
        snapshot := SnapshotReportEditStructureElement(element)
        try snapshot["processMatches"] :=
            element.ProcessId = foregroundPid
        catch
            snapshot["processMatches"] := false
        snapshot["depth"] := ReportEditStructureDepth(
            element,
            documentElement
        )
        candidates.Push({
            element: element,
            sources: source,
            snapshot: snapshot
        })
    }
}

CollectReportEditStructureParentChain(
    element,
    documentElement,
    foregroundPid
) {
    global UIA
    chain := []
    currentElement := element
    loop 20 {
        snapshot := SnapshotReportEditStructureElement(currentElement)
        try snapshot["processMatches"] :=
            currentElement.ProcessId = foregroundPid
        catch
            snapshot["processMatches"] := false
        chain.Push(snapshot)
        try {
            if UIA.CompareElementsEx(currentElement, documentElement)
                break
        }
        currentElement :=
            UIA.RawViewWalker.TryGetParentElement(currentElement)
        if !IsObject(currentElement)
            break
    }
    return chain
}

ReportEditStructureDepth(element, documentElement) {
    global UIA
    currentElement := element
    loop 32 {
        try {
            if UIA.CompareElementsEx(currentElement, documentElement)
                return A_Index - 1
        }
        currentElement :=
            UIA.RawViewWalker.TryGetParentElement(currentElement)
        if !IsObject(currentElement)
            break
    }
    return -1
}

ResolveReportEditStructureDocument(focusedElement, foregroundPid) {
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

SnapshotReportEditStructureElement(element) {
    snapshot := Map(
        "controlType", "UNKNOWN",
        "controlTypeName", "UNKNOWN",
        "rect", "UNKNOWN",
        "hasKeyboardFocus", false,
        "isKeyboardFocusable", false,
        "isEnabled", false,
        "isOffscreen", false,
        "isControlElement", false,
        "isContentElement", false,
        "isPassword", false,
        "textPatternAvailable", false,
        "textPattern2Available", false,
        "textEditPatternAvailable", false,
        "valuePatternAvailable", false,
        "legacyPatternAvailable", false,
        "selectionPatternAvailable", false,
        "scrollPatternAvailable", false,
        "processMatches", false,
        "depth", -1
    )
    try {
        snapshot["controlType"] := element.ControlType
        try snapshot["controlTypeName"] :=
            UIA.ControlType[snapshot["controlType"]]
    }
    try snapshot["rect"] :=
        FormatReportEditStructureRect(element.BoundingRectangle)
    try snapshot["hasKeyboardFocus"] :=
        element.HasKeyboardFocus = true
    try snapshot["isKeyboardFocusable"] :=
        element.IsKeyboardFocusable = true
    try snapshot["isEnabled"] := element.IsEnabled = true
    try snapshot["isOffscreen"] := element.IsOffscreen = true
    try snapshot["isControlElement"] :=
        element.IsControlElement = true
    try snapshot["isContentElement"] :=
        element.IsContentElement = true
    try snapshot["isPassword"] := element.IsPassword = true
    try snapshot["textPatternAvailable"] :=
        element.IsTextPatternAvailable = true
    try snapshot["textPattern2Available"] :=
        element.IsTextPattern2Available = true
    try snapshot["textEditPatternAvailable"] :=
        element.IsTextEditPatternAvailable = true
    try snapshot["valuePatternAvailable"] :=
        element.IsValuePatternAvailable = true
    try snapshot["legacyPatternAvailable"] :=
        element.IsLegacyIAccessiblePatternAvailable = true
    try snapshot["selectionPatternAvailable"] :=
        element.IsSelectionPatternAvailable = true
    try snapshot["scrollPatternAvailable"] :=
        element.IsScrollPatternAvailable = true
    return snapshot
}

NewReportEditorEditStructureResult() {
    return Map(
        "state", "UNEXPECTED_ERROR",
        "foregroundProcess", "UNKNOWN",
        "foregroundProcessApproved", false,
        "focusedElement", 0,
        "documentResolved", false,
        "documentAncestorDepth", 0,
        "documentElement", 0,
        "pointElementCaptured", false,
        "pointElementProcessMatches", false,
        "pointElement", 0,
        "pointElementExceptionType", "",
        "smallestPointElementCaptured", false,
        "smallestPointElementProcessMatches", false,
        "smallestPointElement", 0,
        "smallestPointElementExceptionType", "",
        "smallestPointChain", [],
        "queries", [],
        "candidates", [],
        "mouseX", 0,
        "mouseY", 0,
        "foregroundUnchanged", false,
        "mouseUnchanged", false,
        "exceptionType", "",
        "elapsedMs", 0
    )
}

FinishReportEditorEditStructure(result, startedAt) {
    result["elapsedMs"] := A_TickCount - startedAt
    return result
}

FormatReportEditorEditStructure(result) {
    lines := [
        "Test=ReportEditorEditStructure",
        "Privacy=NO_NAME_VALUE_OR_TEXT_READ",
        "State=" result["state"],
        "ForegroundProcess=" result["foregroundProcess"],
        "ForegroundProcessApproved="
            ReportEditStructureBoolean(
                result["foregroundProcessApproved"]
            ),
        "DocumentResolved="
            ReportEditStructureBoolean(result["documentResolved"]),
        "DocumentAncestorDepth=" result["documentAncestorDepth"],
        "MousePoint=" result["mouseX"] "," result["mouseY"],
        "PointElementCaptured="
            ReportEditStructureBoolean(
                result["pointElementCaptured"]
            ),
        "PointElementProcessMatches="
            ReportEditStructureBoolean(
                result["pointElementProcessMatches"]
            ),
        "PointElementExceptionType="
            result["pointElementExceptionType"],
        "SmallestPointElementCaptured="
            ReportEditStructureBoolean(
                result["smallestPointElementCaptured"]
            ),
        "SmallestPointElementProcessMatches="
            ReportEditStructureBoolean(
                result["smallestPointElementProcessMatches"]
            ),
        "SmallestPointElementExceptionType="
            result["smallestPointElementExceptionType"],
        "CandidateCount=" result["candidates"].Length,
        "CandidateLimit=100",
        "ForegroundUnchanged="
            ReportEditStructureBoolean(
                result["foregroundUnchanged"]
            ),
        "MouseUnchanged="
            ReportEditStructureBoolean(result["mouseUnchanged"]),
        "ExceptionType=" result["exceptionType"],
        "ElapsedMs=" result["elapsedMs"]
    ]
    report := JoinReportEditStructureLines(lines)
    if IsObject(result["focusedElement"])
        report .= "`r`n`r`n[FocusedElement]`r`n"
            . FormatReportEditStructureElement(
                result["focusedElement"]
            )
    if IsObject(result["documentElement"])
        report .= "`r`n`r`n[DocumentElement]`r`n"
            . FormatReportEditStructureElement(
                result["documentElement"]
            )
    if IsObject(result["pointElement"])
        report .= "`r`n`r`n[PointElement]`r`n"
            . FormatReportEditStructureElement(
                result["pointElement"]
            )
    if IsObject(result["smallestPointElement"])
        report .= "`r`n`r`n[SmallestPointElement]`r`n"
            . FormatReportEditStructureElement(
                result["smallestPointElement"]
            )

    report .= "`r`n`r`n[Queries]"
    for query in result["queries"] {
        report .= "`r`n"
            . "Query=" query.label
            . " Succeeded="
            . ReportEditStructureBoolean(query.succeeded)
            . " RawCount=" query.rawCount
            . " ExceptionType=" query.exceptionType
    }

    report .= "`r`n`r`n[SmallestPointParentChain]"
    for index, snapshot in result["smallestPointChain"] {
        report .= "`r`n`r`nChain=" index "`r`n"
            . FormatReportEditStructureElement(snapshot)
    }

    report .= "`r`n`r`n[Candidates]"
    for index, candidate in result["candidates"] {
        report .= "`r`n`r`nCandidate=" index
            . "`r`nSources=" candidate.sources
            . "`r`n"
            . FormatReportEditStructureElement(
                candidate.snapshot
            )
    }
    return report "`r`n"
}

FormatReportEditStructureElement(snapshot) {
    return JoinReportEditStructureLines([
        "ControlType=" snapshot["controlType"],
        "ControlTypeName=" snapshot["controlTypeName"],
        "Rect=" snapshot["rect"],
        "Depth=" snapshot["depth"],
        "ProcessMatches="
            ReportEditStructureBoolean(snapshot["processMatches"]),
        "HasKeyboardFocus="
            ReportEditStructureBoolean(
                snapshot["hasKeyboardFocus"]
            ),
        "IsKeyboardFocusable="
            ReportEditStructureBoolean(
                snapshot["isKeyboardFocusable"]
            ),
        "IsEnabled="
            ReportEditStructureBoolean(snapshot["isEnabled"]),
        "IsOffscreen="
            ReportEditStructureBoolean(snapshot["isOffscreen"]),
        "IsControlElement="
            ReportEditStructureBoolean(
                snapshot["isControlElement"]
            ),
        "IsContentElement="
            ReportEditStructureBoolean(
                snapshot["isContentElement"]
            ),
        "IsPassword="
            ReportEditStructureBoolean(snapshot["isPassword"]),
        "TextPatternAvailable="
            ReportEditStructureBoolean(
                snapshot["textPatternAvailable"]
            ),
        "TextPattern2Available="
            ReportEditStructureBoolean(
                snapshot["textPattern2Available"]
            ),
        "TextEditPatternAvailable="
            ReportEditStructureBoolean(
                snapshot["textEditPatternAvailable"]
            ),
        "ValuePatternAvailable="
            ReportEditStructureBoolean(
                snapshot["valuePatternAvailable"]
            ),
        "LegacyPatternAvailable="
            ReportEditStructureBoolean(
                snapshot["legacyPatternAvailable"]
            ),
        "SelectionPatternAvailable="
            ReportEditStructureBoolean(
                snapshot["selectionPatternAvailable"]
            ),
        "ScrollPatternAvailable="
            ReportEditStructureBoolean(
                snapshot["scrollPatternAvailable"]
            )
    ])
}

JoinReportEditStructureLines(lines) {
    output := ""
    for index, line in lines
        output .= (index = 1 ? "" : "`r`n") line
    return output
}

FormatReportEditStructureRect(rectangle) {
    return rectangle.l "," rectangle.t ","
        . rectangle.r "," rectangle.b
}

ReportEditStructureBoolean(value) {
    return value ? "true" : "false"
}

IsReportEditStructureApprovedProcess(processName) {
    normalized := StrLower(String(processName))
    return normalized = "medexworkstation.exe"
        || normalized = "medexworkstations.exe"
}
