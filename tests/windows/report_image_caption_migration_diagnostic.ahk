#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

global ReportCaptionDiagnosticSession := 0

^!+F8::AdvanceReportCaptionDiagnostic()
^!+F7::ResetReportCaptionDiagnostic()

AdvanceReportCaptionDiagnostic() {
    global ReportCaptionDiagnosticSession

    if !IsObject(ReportCaptionDiagnosticSession) {
        StartReportCaptionDiagnostic()
        return
    }
    if ReportCaptionDiagnosticSession["stage"] = 1 {
        CaptureReportCaptionInputPoint()
        return
    }
    if ReportCaptionDiagnosticSession["stage"] = 2 {
        CaptureReportCaptionImagePoint()
        return
    }
    ResetReportCaptionDiagnostic()
}

StartReportCaptionDiagnostic() {
    global ReportCaptionDiagnosticSession

    foregroundHwnd := WinExist("A")
    if !foregroundHwnd {
        ShowReportCaptionDiagnosticTip("未找到前台窗口。")
        return
    }
    try foregroundPid := WinGetPID("ahk_id " foregroundHwnd)
    catch {
        ShowReportCaptionDiagnosticTip("无法读取前台窗口进程。")
        return
    }

    session := Map(
        "stage", 0,
        "startedAt", A_TickCount,
        "windowHwnd", foregroundHwnd,
        "windowPid", foregroundPid,
        "window", SnapshotReportCaptionWindow(foregroundHwnd),
        "monitors", SnapshotReportCaptionMonitors(foregroundHwnd),
        "source", SnapshotReportCaptionSource(
            foregroundHwnd,
            foregroundPid
        ),
        "captionPoint", 0,
        "imagePoint", 0
    )
    if !session["source"]["selectionCopyProbe"]["completed"] {
        CopyReportCaptionDiagnosticFailure(
            "SOURCE_COPY_PROBE_NOT_COMPLETED",
            session
        )
        return
    }

    session["stage"] := 1
    ReportCaptionDiagnosticSession := session
    ShowReportCaptionDiagnosticTip(
        "阶段 1/3 已完成。`n"
        . "把鼠标停在图像描述输入框中央，`n"
        . "按 Ctrl+Alt+Shift+F8。"
    )
}

CaptureReportCaptionInputPoint() {
    global ReportCaptionDiagnosticSession

    if !ReportCaptionDiagnosticWindowStillActive(
        ReportCaptionDiagnosticSession
    ) {
        CopyReportCaptionDiagnosticFailure(
            "TARGET_WINDOW_CHANGED_AT_CAPTION_POINT",
            ReportCaptionDiagnosticSession
        )
        return
    }
    MouseGetPos &mouseX, &mouseY
    ReportCaptionDiagnosticSession["captionPoint"] :=
        SnapshotReportCaptionPoint(
            "CAPTION_INPUT",
            mouseX,
            mouseY,
            ReportCaptionDiagnosticSession["windowHwnd"],
            ReportCaptionDiagnosticSession["windowPid"],
            true
        )
    ReportCaptionDiagnosticSession["stage"] := 2
    ShowReportCaptionDiagnosticTip(
        "阶段 2/3 已完成。`n"
        . "把鼠标停在上方图像翻页区域中央，`n"
        . "按 Ctrl+Alt+Shift+F8。"
    )
}

CaptureReportCaptionImagePoint() {
    global ReportCaptionDiagnosticSession

    if !ReportCaptionDiagnosticWindowStillActive(
        ReportCaptionDiagnosticSession
    ) {
        CopyReportCaptionDiagnosticFailure(
            "TARGET_WINDOW_CHANGED_AT_IMAGE_POINT",
            ReportCaptionDiagnosticSession
        )
        return
    }
    MouseGetPos &mouseX, &mouseY
    ReportCaptionDiagnosticSession["imagePoint"] :=
        SnapshotReportCaptionPoint(
            "IMAGE_WHEEL",
            mouseX,
            mouseY,
            ReportCaptionDiagnosticSession["windowHwnd"],
            ReportCaptionDiagnosticSession["windowPid"],
            false
        )
    report := FormatReportCaptionDiagnostic(
        ReportCaptionDiagnosticSession,
        "COMPLETE"
    )
    A_Clipboard := report
    copied := ClipWait(2)
    ReportCaptionDiagnosticSession := 0
    ShowReportCaptionDiagnosticTip(
        copied
            ? "诊断完成，安全结构结果已复制到剪贴板。"
            : "诊断完成，但剪贴板写入未确认。"
    )
}

ResetReportCaptionDiagnostic() {
    global ReportCaptionDiagnosticSession
    ReportCaptionDiagnosticSession := 0
    ShowReportCaptionDiagnosticTip(
        "诊断已重置。`n"
        . "选中一段非临床测试文字后，`n"
        . "按 Ctrl+Alt+Shift+F8 开始。"
    )
}

SnapshotReportCaptionSource(expectedHwnd, expectedPid) {
    result := Map(
        "foregroundBefore", WinExist("A"),
        "focusedElementCaptured", false,
        "focusedElement", 0,
        "focusedParentChain", [],
        "selectionCopyProbe", NewReportCaptionSelectionCopyProbe(),
        "foregroundAfter", 0,
        "foregroundUnchanged", false,
        "mouseUnchanged", false
    )
    MouseGetPos &mouseBeforeX, &mouseBeforeY

    try {
        focusedElement := UIA.GetFocusedElement()
        result["focusedElementCaptured"] := true
        result["focusedElement"] :=
            SnapshotReportCaptionUiaElement(
                focusedElement,
                expectedPid
            )
        result["focusedParentChain"] :=
            CollectReportCaptionUiaParentChain(
                focusedElement,
                expectedPid
            )
    }

    result["selectionCopyProbe"] :=
        ProbeReportCaptionSelectionCopy(expectedHwnd)
    result["foregroundAfter"] := WinExist("A")
    result["foregroundUnchanged"] :=
        result["foregroundBefore"] = result["foregroundAfter"]
    MouseGetPos &mouseAfterX, &mouseAfterY
    result["mouseUnchanged"] :=
        mouseBeforeX = mouseAfterX && mouseBeforeY = mouseAfterY
    return result
}

ProbeReportCaptionSelectionCopy(expectedHwnd) {
    result := NewReportCaptionSelectionCopyProbe()
    modifiersReleased :=
        KeyWait("Ctrl", "T1")
        && KeyWait("Alt", "T1")
        && KeyWait("Shift", "T1")
    result["modifiersReleased"] := modifiersReleased = true
    if !result["modifiersReleased"] {
        result["state"] := "MODIFIER_RELEASE_TIMEOUT"
        result["completed"] := true
        return result
    }
    if WinExist("A") != expectedHwnd {
        result["state"] := "FOREGROUND_CHANGED_BEFORE_COPY"
        result["completed"] := true
        return result
    }

    savedClipboard := ClipboardAll()
    result["originalClipboardCaptured"] := true
    try {
        A_Clipboard := ""
        SendInput("^c")
        result["copySent"] := true
        result["clipboardUpdated"] := ClipWait(1)
        if result["clipboardUpdated"] {
            copiedText := A_Clipboard
            result["copiedTextLength"] := StrLen(copiedText)
            result["copiedTextNonWhitespace"] :=
                Trim(copiedText, " `t`r`n") != ""
            result["copiedLineBreakCount"] :=
                StrLen(copiedText)
                - StrLen(StrReplace(copiedText, "`n"))
            copiedText := ""
            result["state"] := "COPY_CAPTURED"
        } else {
            result["state"] := "CLIPBOARD_NOT_UPDATED"
        }
    } catch as copyError {
        result["state"] := "COPY_PROBE_FAILED"
        result["exceptionType"] := Type(copyError)
    } finally {
        A_Clipboard := savedClipboard
        savedClipboard := ""
        result["clipboardRestoreAssigned"] := true
    }
    result["foregroundUnchanged"] := WinExist("A") = expectedHwnd
    result["completed"] := true
    return result
}

NewReportCaptionSelectionCopyProbe() {
    return Map(
        "completed", false,
        "state", "NOT_RUN",
        "modifiersReleased", false,
        "originalClipboardCaptured", false,
        "copySent", false,
        "clipboardUpdated", false,
        "copiedTextLength", 0,
        "copiedTextNonWhitespace", false,
        "copiedLineBreakCount", 0,
        "clipboardRestoreAssigned", false,
        "foregroundUnchanged", false,
        "exceptionType", ""
    )
}

SnapshotReportCaptionPoint(
    label,
    mouseX,
    mouseY,
    expectedHwnd,
    expectedPid,
    collectCandidates
) {
    result := Map(
        "label", label,
        "x", mouseX,
        "y", mouseY,
        "windowHwnd", expectedHwnd,
        "windowPid", expectedPid,
        "windowContainsPoint", false,
        "nativeChain", [],
        "uiaElementCaptured", false,
        "uiaElement", 0,
        "smallestElementCaptured", false,
        "smallestElement", 0,
        "uiaParentChain", [],
        "candidateQueries", [],
        "candidates", [],
        "exceptionType", ""
    )
    windowRect := GetReportCaptionWindowRect(expectedHwnd)
    result["windowContainsPoint"] :=
        IsObject(windowRect)
        && mouseX >= windowRect.l
        && mouseX < windowRect.r
        && mouseY >= windowRect.t
        && mouseY < windowRect.b
    result["nativeChain"] :=
        CollectReportCaptionNativePointChain(
            mouseX,
            mouseY,
            expectedPid
        )

    try {
        pointElement := UIA.ElementFromPoint(mouseX, mouseY)
        result["uiaElementCaptured"] := true
        result["uiaElement"] :=
            SnapshotReportCaptionUiaElement(
                pointElement,
                expectedPid
            )
        smallestElement := UIA.SmallestElementFromPoint(
            mouseX,
            mouseY
        )
        result["smallestElementCaptured"] := true
        result["smallestElement"] :=
            SnapshotReportCaptionUiaElement(
                smallestElement,
                expectedPid
            )
        result["uiaParentChain"] :=
            CollectReportCaptionUiaParentChain(
                smallestElement,
                expectedPid
            )
    } catch as pointError {
        result["exceptionType"] := Type(pointError)
    }

    if collectCandidates
        CollectReportCaptionWindowCandidates(
            expectedHwnd,
            expectedPid,
            result
        )
    return result
}

CollectReportCaptionWindowCandidates(expectedHwnd, expectedPid, result) {
    try rootElement :=
        UIA.ElementFromChromium("ahk_id " expectedHwnd)
    catch {
        try rootElement := UIA.ElementFromHandle(expectedHwnd)
        catch as rootError {
            result["candidateQueries"].Push({
                label: "ROOT",
                succeeded: false,
                rawCount: 0,
                exceptionType: Type(rootError)
            })
            return
        }
    }

    querySpecs := [
        {label: "CONTROL_TYPE_EDIT", condition: {Type: "Edit"}},
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
        },
        {
            label: "KNOWN_LABEL_IMAGE_DESCRIPTION",
            condition: {Name: "图像描述"}
        },
        {
            label: "KNOWN_LABEL_SAVE",
            condition: {Name: "保存"}
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
            elements := rootElement.FindElements(querySpec.condition)
            queryResult.succeeded := true
            queryResult.rawCount := elements.Length
            AddUniqueReportCaptionCandidates(
                result["candidates"],
                elements,
                querySpec.label,
                expectedPid
            )
        } catch as queryError {
            queryResult.exceptionType := Type(queryError)
        }
        result["candidateQueries"].Push(queryResult)
    }
}

AddUniqueReportCaptionCandidates(
    candidates,
    elements,
    source,
    expectedPid
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
        candidates.Push({
            element: element,
            sources: source,
            snapshot: SnapshotReportCaptionUiaElement(
                element,
                expectedPid
            )
        })
    }
}

CollectReportCaptionUiaParentChain(element, expectedPid) {
    chain := []
    currentElement := element
    loop 20 {
        chain.Push(
            SnapshotReportCaptionUiaElement(
                currentElement,
                expectedPid
            )
        )
        currentElement :=
            UIA.RawViewWalker.TryGetParentElement(currentElement)
        if !IsObject(currentElement)
            break
    }
    return chain
}

SnapshotReportCaptionUiaElement(element, expectedPid) {
    snapshot := Map(
        "controlType", "UNKNOWN",
        "controlTypeName", "UNKNOWN",
        "rect", "UNKNOWN",
        "processMatches", false,
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
        "scrollPatternAvailable", false
    )
    try {
        snapshot["controlType"] := element.ControlType
        try snapshot["controlTypeName"] :=
            UIA.ControlType[snapshot["controlType"]]
    }
    try snapshot["rect"] :=
        FormatReportCaptionRect(element.BoundingRectangle)
    try snapshot["processMatches"] :=
        element.ProcessId = expectedPid
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

CollectReportCaptionNativePointChain(mouseX, mouseY, expectedPid) {
    chain := []
    pointValue := mouseY << 32 | (mouseX & 0xFFFFFFFF)
    hwnd := DllCall(
        "user32.dll\WindowFromPoint",
        "int64",
        pointValue,
        "ptr"
    )
    loop 16 {
        if !hwnd
            break
        chain.Push(
            SnapshotReportCaptionNativeWindow(hwnd, expectedPid)
        )
        hwnd := DllCall(
            "user32.dll\GetParent",
            "ptr",
            hwnd,
            "ptr"
        )
    }
    return chain
}

SnapshotReportCaptionNativeWindow(hwnd, expectedPid) {
    snapshot := Map(
        "hwnd", hwnd,
        "className", "UNKNOWN",
        "controlId", "UNKNOWN",
        "rect", "UNKNOWN",
        "clientRect", "UNKNOWN",
        "processMatches", false,
        "visible", false,
        "enabled", false
    )
    try snapshot["className"] :=
        WinGetClass("ahk_id " hwnd)
    try snapshot["controlId"] :=
        DllCall("user32.dll\GetDlgCtrlID", "ptr", hwnd, "int")
    try snapshot["rect"] :=
        FormatReportCaptionRect(GetReportCaptionWindowRect(hwnd))
    try snapshot["clientRect"] :=
        FormatReportCaptionRect(
            GetReportCaptionClientRectScreen(hwnd)
        )
    try snapshot["processMatches"] :=
        WinGetPID("ahk_id " hwnd) = expectedPid
    try snapshot["visible"] :=
        DllCall("user32.dll\IsWindowVisible", "ptr", hwnd, "int")
            != 0
    try snapshot["enabled"] :=
        DllCall("user32.dll\IsWindowEnabled", "ptr", hwnd, "int")
            != 0
    return snapshot
}

SnapshotReportCaptionWindow(hwnd) {
    snapshot := Map(
        "hwnd", hwnd,
        "pid", 0,
        "processName", "UNKNOWN",
        "className", "UNKNOWN",
        "titleLength", 0,
        "rect", "UNKNOWN",
        "clientRect", "UNKNOWN",
        "rootOwnerHwnd", 0,
        "dpi", 0,
        "scalingPercent", 0,
        "minMaxState", "UNKNOWN",
        "style", "UNKNOWN",
        "exStyle", "UNKNOWN"
    )
    try snapshot["pid"] := WinGetPID("ahk_id " hwnd)
    try snapshot["processName"] :=
        WinGetProcessName("ahk_id " hwnd)
    try snapshot["className"] := WinGetClass("ahk_id " hwnd)
    try snapshot["titleLength"] :=
        StrLen(WinGetTitle("ahk_id " hwnd))
    try snapshot["rect"] :=
        FormatReportCaptionRect(GetReportCaptionWindowRect(hwnd))
    try snapshot["clientRect"] :=
        FormatReportCaptionRect(
            GetReportCaptionClientRectScreen(hwnd)
        )
    try snapshot["rootOwnerHwnd"] :=
        DllCall(
            "user32.dll\GetAncestor",
            "ptr",
            hwnd,
            "uint",
            3,
            "ptr"
        )
    try snapshot["dpi"] :=
        DllCall("user32.dll\GetDpiForWindow", "ptr", hwnd, "uint")
    if snapshot["dpi"]
        snapshot["scalingPercent"] :=
            Round(snapshot["dpi"] * 100 / 96)
    try snapshot["minMaxState"] := WinGetMinMax("ahk_id " hwnd)
    try snapshot["style"] := WinGetStyle("ahk_id " hwnd)
    try snapshot["exStyle"] := WinGetExStyle("ahk_id " hwnd)
    return snapshot
}

SnapshotReportCaptionMonitors(windowHwnd) {
    result := Map(
        "virtualScreen",
            SysGet(76) "," SysGet(77) ","
            . SysGet(78) "," SysGet(79),
        "primaryMonitor", MonitorGetPrimary(),
        "windowMonitor", 0,
        "items", []
    )
    windowRect := GetReportCaptionWindowRect(windowHwnd)
    bestArea := -1
    loop MonitorGetCount() {
        MonitorGet A_Index, &left, &top, &right, &bottom
        MonitorGetWorkArea(
            A_Index,
            &workLeft,
            &workTop,
            &workRight,
            &workBottom
        )
        item := Map(
            "index", A_Index,
            "rect", left "," top "," right "," bottom,
            "workRect",
                workLeft "," workTop ","
                . workRight "," workBottom
        )
        result["items"].Push(item)
        if IsObject(windowRect) {
            intersectionWidth :=
                Max(0, Min(windowRect.r, right)
                    - Max(windowRect.l, left))
            intersectionHeight :=
                Max(0, Min(windowRect.b, bottom)
                    - Max(windowRect.t, top))
            intersectionArea :=
                intersectionWidth * intersectionHeight
            if intersectionArea > bestArea {
                bestArea := intersectionArea
                result["windowMonitor"] := A_Index
            }
        }
    }
    return result
}

GetReportCaptionWindowRect(hwnd) {
    try {
        WinGetPos &x, &y, &width, &height, "ahk_id " hwnd
        return {
            l: x,
            t: y,
            r: x + width,
            b: y + height
        }
    }
    return 0
}

GetReportCaptionClientRectScreen(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall(
        "user32.dll\GetClientRect",
        "ptr",
        hwnd,
        "ptr",
        rectBuffer,
        "int"
    )
        return 0
    pointBuffer := Buffer(8, 0)
    if !DllCall(
        "user32.dll\ClientToScreen",
        "ptr",
        hwnd,
        "ptr",
        pointBuffer,
        "int"
    )
        return 0
    left := NumGet(pointBuffer, 0, "int")
    top := NumGet(pointBuffer, 4, "int")
    return {
        l: left,
        t: top,
        r: left + NumGet(rectBuffer, 8, "int"),
        b: top + NumGet(rectBuffer, 12, "int")
    }
}

ReportCaptionDiagnosticWindowStillActive(session) {
    if WinExist("A") != session["windowHwnd"]
        return false
    try return WinGetPID("A") = session["windowPid"]
    return false
}

CopyReportCaptionDiagnosticFailure(code, session) {
    global ReportCaptionDiagnosticSession
    report := FormatReportCaptionDiagnostic(session, code)
    A_Clipboard := report
    ClipWait 2
    ReportCaptionDiagnosticSession := 0
    ShowReportCaptionDiagnosticTip(
        "诊断停止：" code "`n安全摘要已复制到剪贴板。"
    )
}

FormatReportCaptionDiagnostic(session, state) {
    report :=
        "Test=ReportImageCaptionMigrationDiagnostic`r`n"
        . "DiagnosticVersion=1.0`r`n"
        . "State=" state "`r`n"
        . "Privacy=NO_RAW_NAME_VALUE_TEXT_TITLE_OR_URL_OUTPUT`r`n"
        . "SelectionPayloadPersisted=false`r`n"
        . "MouseClickSent=false`r`n"
        . "WheelSent=false`r`n"
        . "PasteSent=false`r`n"
        . "ElapsedMs=" (A_TickCount - session["startedAt"])
        . "`r`n`r`n"
        . FormatReportCaptionWindowSection(session["window"])
        . "`r`n`r`n"
        . FormatReportCaptionMonitorSection(session["monitors"])
        . "`r`n`r`n"
        . FormatReportCaptionSourceSection(session["source"])

    if IsObject(session["captionPoint"])
        report .= "`r`n`r`n"
            . FormatReportCaptionPointSection(
                session["captionPoint"]
            )
    if IsObject(session["imagePoint"])
        report .= "`r`n`r`n"
            . FormatReportCaptionPointSection(
                session["imagePoint"]
            )
    return report "`r`n"
}

FormatReportCaptionWindowSection(snapshot) {
    return "[Window]`r`n"
        . "Hwnd=" snapshot["hwnd"] "`r`n"
        . "Pid=" snapshot["pid"] "`r`n"
        . "ProcessName=" snapshot["processName"] "`r`n"
        . "ClassName=" snapshot["className"] "`r`n"
        . "TitleLength=" snapshot["titleLength"] "`r`n"
        . "Rect=" snapshot["rect"] "`r`n"
        . "ClientRect=" snapshot["clientRect"] "`r`n"
        . "RootOwnerHwnd=" snapshot["rootOwnerHwnd"] "`r`n"
        . "Dpi=" snapshot["dpi"] "`r`n"
        . "ScalingPercent=" snapshot["scalingPercent"] "`r`n"
        . "MinMaxState=" snapshot["minMaxState"] "`r`n"
        . "Style=" snapshot["style"] "`r`n"
        . "ExStyle=" snapshot["exStyle"]
}

FormatReportCaptionMonitorSection(monitors) {
    report := "[Monitors]`r`n"
        . "VirtualScreen=" monitors["virtualScreen"] "`r`n"
        . "PrimaryMonitor=" monitors["primaryMonitor"] "`r`n"
        . "WindowMonitor=" monitors["windowMonitor"] "`r`n"
        . "MonitorCount=" monitors["items"].Length
    for item in monitors["items"] {
        report .= "`r`nMonitor=" item["index"]
            . " Rect=" item["rect"]
            . " WorkRect=" item["workRect"]
    }
    return report
}

FormatReportCaptionSourceSection(source) {
    probe := source["selectionCopyProbe"]
    report := "[SourceSelection]`r`n"
        . "FocusedElementCaptured="
        . ReportCaptionDiagnosticBoolean(
            source["focusedElementCaptured"]
        ) "`r`n"
        . "ForegroundUnchanged="
        . ReportCaptionDiagnosticBoolean(
            source["foregroundUnchanged"]
        ) "`r`n"
        . "MouseUnchanged="
        . ReportCaptionDiagnosticBoolean(
            source["mouseUnchanged"]
        ) "`r`n"
        . "CopyProbeState=" probe["state"] "`r`n"
        . "ModifiersReleased="
        . ReportCaptionDiagnosticBoolean(
            probe["modifiersReleased"]
        ) "`r`n"
        . "OriginalClipboardCaptured="
        . ReportCaptionDiagnosticBoolean(
            probe["originalClipboardCaptured"]
        ) "`r`n"
        . "CopySent="
        . ReportCaptionDiagnosticBoolean(probe["copySent"])
        . "`r`nClipboardUpdated="
        . ReportCaptionDiagnosticBoolean(
            probe["clipboardUpdated"]
        ) "`r`n"
        . "CopiedTextLength=" probe["copiedTextLength"] "`r`n"
        . "CopiedTextNonWhitespace="
        . ReportCaptionDiagnosticBoolean(
            probe["copiedTextNonWhitespace"]
        ) "`r`n"
        . "CopiedLineBreakCount="
        . probe["copiedLineBreakCount"] "`r`n"
        . "ClipboardRestoreAssigned="
        . ReportCaptionDiagnosticBoolean(
            probe["clipboardRestoreAssigned"]
        ) "`r`n"
        . "CopyForegroundUnchanged="
        . ReportCaptionDiagnosticBoolean(
            probe["foregroundUnchanged"]
        ) "`r`n"
        . "CopyExceptionType=" probe["exceptionType"]

    if IsObject(source["focusedElement"])
        report .= "`r`n`r`n[SourceFocusedElement]`r`n"
            . FormatReportCaptionUiaElement(
                source["focusedElement"]
            )
    report .= "`r`n`r`n[SourceFocusedParentChain]"
    for index, snapshot in source["focusedParentChain"] {
        report .= "`r`n`r`nChain=" index "`r`n"
            . FormatReportCaptionUiaElement(snapshot)
    }
    return report
}

FormatReportCaptionPointSection(point) {
    report := "[" point["label"] "]`r`n"
        . "Point=" point["x"] "," point["y"] "`r`n"
        . "WindowContainsPoint="
        . ReportCaptionDiagnosticBoolean(
            point["windowContainsPoint"]
        ) "`r`n"
        . "UiaElementCaptured="
        . ReportCaptionDiagnosticBoolean(
            point["uiaElementCaptured"]
        ) "`r`n"
        . "SmallestElementCaptured="
        . ReportCaptionDiagnosticBoolean(
            point["smallestElementCaptured"]
        ) "`r`n"
        . "ExceptionType=" point["exceptionType"]

    if IsObject(point["uiaElement"])
        report .= "`r`n`r`n["
            . point["label"] ".PointElement]`r`n"
            . FormatReportCaptionUiaElement(
                point["uiaElement"]
            )
    if IsObject(point["smallestElement"])
        report .= "`r`n`r`n["
            . point["label"] ".SmallestElement]`r`n"
            . FormatReportCaptionUiaElement(
                point["smallestElement"]
            )

    report .= "`r`n`r`n["
        . point["label"] ".NativeParentChain]"
    for index, snapshot in point["nativeChain"] {
        report .= "`r`n`r`nChain=" index "`r`n"
            . FormatReportCaptionNativeWindow(snapshot)
    }

    report .= "`r`n`r`n["
        . point["label"] ".UiaParentChain]"
    for index, snapshot in point["uiaParentChain"] {
        report .= "`r`n`r`nChain=" index "`r`n"
            . FormatReportCaptionUiaElement(snapshot)
    }

    if point["candidateQueries"].Length {
        report .= "`r`n`r`n["
            . point["label"] ".CandidateQueries]"
        for query in point["candidateQueries"] {
            report .= "`r`nQuery=" query.label
                . " Succeeded="
                . ReportCaptionDiagnosticBoolean(query.succeeded)
                . " RawCount=" query.rawCount
                . " ExceptionType=" query.exceptionType
        }
        report .= "`r`n`r`n["
            . point["label"] ".Candidates]"
        for index, candidate in point["candidates"] {
            report .= "`r`n`r`nCandidate=" index
                . "`r`nSources=" candidate.sources
                . "`r`n"
                . FormatReportCaptionUiaElement(
                    candidate.snapshot
                )
        }
    }
    return report
}

FormatReportCaptionUiaElement(snapshot) {
    return "ControlType=" snapshot["controlType"] "`r`n"
        . "ControlTypeName=" snapshot["controlTypeName"] "`r`n"
        . "Rect=" snapshot["rect"] "`r`n"
        . "ProcessMatches="
        . ReportCaptionDiagnosticBoolean(
            snapshot["processMatches"]
        ) "`r`n"
        . "HasKeyboardFocus="
        . ReportCaptionDiagnosticBoolean(
            snapshot["hasKeyboardFocus"]
        ) "`r`n"
        . "IsKeyboardFocusable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["isKeyboardFocusable"]
        ) "`r`n"
        . "IsEnabled="
        . ReportCaptionDiagnosticBoolean(snapshot["isEnabled"])
        . "`r`nIsOffscreen="
        . ReportCaptionDiagnosticBoolean(snapshot["isOffscreen"])
        . "`r`nIsControlElement="
        . ReportCaptionDiagnosticBoolean(
            snapshot["isControlElement"]
        ) "`r`n"
        . "IsContentElement="
        . ReportCaptionDiagnosticBoolean(
            snapshot["isContentElement"]
        ) "`r`n"
        . "IsPassword="
        . ReportCaptionDiagnosticBoolean(snapshot["isPassword"])
        . "`r`nTextPatternAvailable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["textPatternAvailable"]
        ) "`r`n"
        . "TextPattern2Available="
        . ReportCaptionDiagnosticBoolean(
            snapshot["textPattern2Available"]
        ) "`r`n"
        . "TextEditPatternAvailable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["textEditPatternAvailable"]
        ) "`r`n"
        . "ValuePatternAvailable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["valuePatternAvailable"]
        ) "`r`n"
        . "LegacyPatternAvailable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["legacyPatternAvailable"]
        ) "`r`n"
        . "SelectionPatternAvailable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["selectionPatternAvailable"]
        ) "`r`n"
        . "ScrollPatternAvailable="
        . ReportCaptionDiagnosticBoolean(
            snapshot["scrollPatternAvailable"]
        )
}

FormatReportCaptionNativeWindow(snapshot) {
    return "Hwnd=" snapshot["hwnd"] "`r`n"
        . "ClassName=" snapshot["className"] "`r`n"
        . "ControlId=" snapshot["controlId"] "`r`n"
        . "Rect=" snapshot["rect"] "`r`n"
        . "ClientRect=" snapshot["clientRect"] "`r`n"
        . "ProcessMatches="
        . ReportCaptionDiagnosticBoolean(
            snapshot["processMatches"]
        ) "`r`n"
        . "Visible="
        . ReportCaptionDiagnosticBoolean(snapshot["visible"])
        . "`r`nEnabled="
        . ReportCaptionDiagnosticBoolean(snapshot["enabled"])
}

FormatReportCaptionRect(rectangle) {
    if !IsObject(rectangle)
        return "UNKNOWN"
    return rectangle.l "," rectangle.t ","
        . rectangle.r "," rectangle.b
}

ReportCaptionDiagnosticBoolean(value) {
    return value ? "true" : "false"
}

ShowReportCaptionDiagnosticTip(text) {
    ToolTip text
    SetTimer (() => ToolTip()), -5000
}
