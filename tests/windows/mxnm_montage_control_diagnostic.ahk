#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

global MxNMMontageDiagnosticSession := 0
global MxNMMontageDiagnosticArmed := false

^!+F8::AdvanceMxNMMontageDiagnostic()
^!+F9::ArmMxNMMontageDiagnosticCapture()
^!+F7::ResetMxNMMontageDiagnostic()
^!+F6::FinishMxNMMontageDiagnostic("OPERATOR_FINISHED_EARLY")

ArmMxNMMontageDiagnosticCapture() {
    global MxNMMontageDiagnosticSession
    global MxNMMontageDiagnosticArmed

    if !IsObject(MxNMMontageDiagnosticSession) {
        ShowMxNMMontageDiagnosticTip(
            "请先让 Viewer 位于前台，并按 Ctrl+Alt+Shift+F8 开始诊断。"
        )
        return
    }
    if MxNMMontageDiagnosticArmed {
        ShowMxNMMontageDiagnosticTip("延时取样已经布防。")
        return
    }
    MxNMMontageDiagnosticArmed := true
    ShowMxNMMontageDiagnosticTip(
        "延时取样已布防，4 秒后记录当前阶段。`n"
        . "现在手工展开 dropdown，并把鼠标停在目标选项上。"
    )
    SetTimer CaptureArmedMxNMMontageDiagnostic, -4000
}

CaptureArmedMxNMMontageDiagnostic() {
    global MxNMMontageDiagnosticArmed
    if !MxNMMontageDiagnosticArmed
        return
    MxNMMontageDiagnosticArmed := false
    AdvanceMxNMMontageDiagnostic()
}

AdvanceMxNMMontageDiagnostic() {
    global MxNMMontageDiagnosticSession

    if !IsObject(MxNMMontageDiagnosticSession) {
        StartMxNMMontageDiagnostic()
        return
    }

    session := MxNMMontageDiagnosticSession
    if !MxNMMontageDiagnosticViewerStillAvailable(session) {
        FinishMxNMMontageDiagnostic("VIEWER_PROCESS_CHANGED")
        return
    }

    stages := MxNMMontageDiagnosticStages()
    stageIndex := session["nextStage"]
    if stageIndex > stages.Length {
        FinishMxNMMontageDiagnostic("COMPLETE")
        return
    }

    MouseGetPos &mouseX, &mouseY
    point := SnapshotMxNMMontagePoint(
        stages[stageIndex].label,
        mouseX,
        mouseY,
        session["viewerHwnd"],
        session["viewerPid"],
        session["viewerRootOwner"]
    )
    if !point["pointProcessMatches"] {
        ShowMxNMMontageDiagnosticTip(
            "当前鼠标点不属于已绑定的 Viewer 进程。`n"
            . "本阶段没有记录，请重新定位后再按 Ctrl+Alt+Shift+F8。"
        )
        return
    }

    session["points"].Push(point)
    session["nextStage"] += 1
    if session["nextStage"] > stages.Length {
        FinishMxNMMontageDiagnostic("COMPLETE")
        return
    }
    ShowMxNMMontageStagePrompt(session["nextStage"], stages)
}

StartMxNMMontageDiagnostic() {
    global MxNMMontageDiagnosticSession

    viewerHwnd := WinExist("A")
    if !viewerHwnd {
        ShowMxNMMontageDiagnosticTip("未找到前台 Viewer 窗口。")
        return
    }
    try viewerPid := WinGetPID("ahk_id " viewerHwnd)
    catch {
        ShowMxNMMontageDiagnosticTip("无法读取前台窗口进程。")
        return
    }
    try processName := WinGetProcessName("ahk_id " viewerHwnd)
    catch {
        processName := ""
    }
    if StrLower(processName) != "medexnmfusion.exe" {
        ShowMxNMMontageDiagnosticTip(
            "前台窗口不是 MedExNMFusion.exe，诊断未开始。"
        )
        return
    }

    rootOwner := MxNMMontageRootOwner(viewerHwnd)
    if !rootOwner
        rootOwner := viewerHwnd
    MxNMMontageDiagnosticSession := Map(
        "startedAt", A_TickCount,
        "viewerHwnd", viewerHwnd,
        "viewerPid", viewerPid,
        "viewerRootOwner", rootOwner,
        "viewer", SnapshotMxNMMontageWindow(viewerHwnd),
        "nextStage", 1,
        "points", []
    )
    stages := MxNMMontageDiagnosticStages()
    ShowMxNMMontageStagePrompt(1, stages)
}

ResetMxNMMontageDiagnostic() {
    global MxNMMontageDiagnosticSession
    global MxNMMontageDiagnosticArmed
    SetTimer CaptureArmedMxNMMontageDiagnostic, 0
    MxNMMontageDiagnosticArmed := false
    MxNMMontageDiagnosticSession := 0
    ShowMxNMMontageDiagnosticTip(
        "Montage 控件诊断已重置。`n"
        . "让 Viewer 位于前台，然后按 Ctrl+Alt+Shift+F8 开始。"
    )
}

FinishMxNMMontageDiagnostic(state) {
    global MxNMMontageDiagnosticSession
    global MxNMMontageDiagnosticArmed

    if !IsObject(MxNMMontageDiagnosticSession) {
        ShowMxNMMontageDiagnosticTip("当前没有正在进行的诊断。")
        return
    }
    session := MxNMMontageDiagnosticSession
    SetTimer CaptureArmedMxNMMontageDiagnostic, 0
    MxNMMontageDiagnosticArmed := false
    report := FormatMxNMMontageDiagnostic(session, state)
    outputPath := WriteMxNMMontageDiagnosticReport(report)
    A_Clipboard := report
    copied := ClipWait(2)
    MxNMMontageDiagnosticSession := 0
    ShowMxNMMontageDiagnosticTip(
        "Montage 控件诊断结束：" state "`n"
        . "结果已写入：" outputPath "`n"
        . (copied ? "同时已复制到剪贴板。" : "剪贴板写入未确认。")
    )
}

MxNMMontageDiagnosticStages() {
    return [
        {
            label: "GRID_R1_C1",
            prompt: "把鼠标停在布局矩阵第 1 行第 1 列按钮中央。"
        },
        {
            label: "GRID_R1_C4",
            prompt: "把鼠标停在布局矩阵第 1 行第 4 列按钮中央。"
        },
        {
            label: "GRID_R5_C1_VISIBLE",
            prompt: "把鼠标停在第 5 行第 1 列仍露出且能点击的部分。"
        },
        {
            label: "GRID_R5_C4_VISIBLE",
            prompt: "把鼠标停在第 5 行第 4 列仍露出且能点击的部分。"
        },
        {
            label: "GRID_R4_C4_TARGET",
            prompt: "把鼠标停在实际使用的第 4 行第 4 列布局按钮中央。"
        },
        {
            label: "TAB3",
            prompt: "把鼠标停在 Tab 3 上；不要让脚本代替你点击。"
        },
        {
            label: "CAPTION_DROPDOWN",
            prompt: "手工进入 Tab 3，把鼠标停在四角图注 dropdown 上。"
        },
        {
            label: "CAPTION_NULL_OPTION",
            prompt: "手工展开图注 dropdown，把鼠标停在 null 选项上。"
        },
        {
            label: "TAB5",
            prompt: "把鼠标停在 Tab 5 上。"
        },
        {
            label: "WINDOW_PRESET_DROPDOWN",
            prompt: "手工进入 Tab 5，把鼠标停在窗宽预设 dropdown 上。"
        },
        {
            label: "WINDOW_DEFAULT_OPTION",
            prompt: "手工展开 dropdown，把鼠标停在 default 选项上。"
        },
        {
            label: "WINDOW_LUNG_OPTION",
            prompt: "把鼠标停在 lung 选项上；必要时重新展开 dropdown。"
        },
        {
            label: "THICKNESS_EDIT",
            prompt: "把鼠标停在层厚文本框中央。"
        },
        {
            label: "THICKNESS_APPLY",
            prompt: "把鼠标停在层厚的更改按钮上。"
        },
        {
            label: "CURRENT_SLICE_EDIT",
            prompt: "把鼠标停在当前层文本框中央。"
        },
        {
            label: "CURRENT_SLICE_JUMP",
            prompt: "把鼠标停在当前层的跳转按钮上。"
        },
        {
            label: "TAB4",
            prompt: "把鼠标停在 Tab 4 上。"
        },
        {
            label: "ZOOM_EDIT",
            prompt: "手工进入 Tab 4，把鼠标停在当前放大倍数文本框中央。"
        }
    ]
}

ShowMxNMMontageStagePrompt(stageIndex, stages) {
    ShowMxNMMontageDiagnosticTip(
        "Montage 控件诊断 " stageIndex "/" stages.Length "`n"
        . stages[stageIndex].prompt "`n"
        . "定位后按 Ctrl+Alt+Shift+F8 记录。`n"
        . "dropdown 可按 Ctrl+Alt+Shift+F9 延时 4 秒取样。`n"
        . "F7 重置；F6 提前结束。"
    )
}

SnapshotMxNMMontagePoint(
    label,
    mouseX,
    mouseY,
    viewerHwnd,
    viewerPid,
    viewerRootOwner
) {
    pointHwnd := MxNMMontageWindowFromPoint(mouseX, mouseY)
    pointPid := 0
    if pointHwnd {
        try pointPid := WinGetPID("ahk_id " pointHwnd)
    }
    pointRootOwner := MxNMMontageRootOwner(pointHwnd)
    clientPoint := MxNMMontageClientPoint(viewerHwnd, mouseX, mouseY)
    result := Map(
        "label", label,
        "screenPoint", mouseX "," mouseY,
        "viewerClientPoint", clientPoint.point,
        "viewerClientRatio", clientPoint.ratio,
        "pointHwnd", pointHwnd,
        "pointPid", pointPid,
        "pointProcessMatches", pointPid = viewerPid,
        "pointRootOwner", pointRootOwner,
        "pointRootOwnerMatches", pointRootOwner = viewerRootOwner,
        "nativeChain", CollectMxNMMontageNativeChain(
            pointHwnd,
            viewerPid
        ),
        "uiaCaptured", false,
        "uia", 0,
        "uiaParentChain", [],
        "uiaExceptionType", ""
    )
    try {
        element := UIA.SmallestElementFromPoint(mouseX, mouseY)
        result["uiaCaptured"] := true
        result["uia"] := SnapshotMxNMMontageUiaElement(
            element,
            viewerPid,
            mouseX,
            mouseY
        )
        result["uiaParentChain"] := CollectMxNMMontageUiaParentChain(
            element,
            viewerPid,
            mouseX,
            mouseY
        )
    } catch as pointError {
        result["uiaExceptionType"] := Type(pointError)
    }
    return result
}

SnapshotMxNMMontageUiaElement(
    element,
    expectedPid,
    mouseX,
    mouseY
) {
    snapshot := Map(
        "controlType", "UNKNOWN",
        "controlTypeName", "UNKNOWN",
        "safeNameToken", "REDACTED",
        "nameLength", "UNKNOWN",
        "automationId", "UNKNOWN",
        "className", "UNKNOWN",
        "rect", "UNKNOWN",
        "rectContainsPoint", false,
        "processMatches", false,
        "enabled", false,
        "offscreen", false,
        "keyboardFocusable", false,
        "invokePattern", false,
        "expandCollapsePattern", false,
        "valuePattern", false,
        "rangeValuePattern", false,
        "selectionPattern", false,
        "selectionItemPattern", false,
        "togglePattern", false,
        "legacyPattern", false
    )
    try {
        snapshot["controlType"] := element.ControlType
        try snapshot["controlTypeName"] :=
            UIA.ControlType[snapshot["controlType"]]
    }
    try {
        rawName := element.Name
        snapshot["nameLength"] := StrLen(rawName)
        snapshot["safeNameToken"] := SafeMxNMMontageNameToken(rawName)
        rawName := ""
    }
    try snapshot["automationId"] :=
        SafeMxNMMontageIdentifier(element.AutomationId)
    try snapshot["className"] :=
        SafeMxNMMontageIdentifier(element.ClassName)
    try {
        rect := element.BoundingRectangle
        snapshot["rect"] := FormatMxNMMontageRect(rect)
        snapshot["rectContainsPoint"] :=
            MxNMMontageRectContainsPoint(rect, mouseX, mouseY)
    }
    try snapshot["processMatches"] := element.ProcessId = expectedPid
    try snapshot["enabled"] := element.IsEnabled = true
    try snapshot["offscreen"] := element.IsOffscreen = true
    try snapshot["keyboardFocusable"] := element.IsKeyboardFocusable = true
    try snapshot["invokePattern"] := element.IsInvokePatternAvailable = true
    try snapshot["expandCollapsePattern"] :=
        element.IsExpandCollapsePatternAvailable = true
    try snapshot["valuePattern"] := element.IsValuePatternAvailable = true
    try snapshot["rangeValuePattern"] :=
        element.IsRangeValuePatternAvailable = true
    try snapshot["selectionPattern"] :=
        element.IsSelectionPatternAvailable = true
    try snapshot["selectionItemPattern"] :=
        element.IsSelectionItemPatternAvailable = true
    try snapshot["togglePattern"] := element.IsTogglePatternAvailable = true
    try snapshot["legacyPattern"] :=
        element.IsLegacyIAccessiblePatternAvailable = true
    return snapshot
}

CollectMxNMMontageUiaParentChain(
    element,
    expectedPid,
    mouseX,
    mouseY
) {
    chain := []
    current := element
    loop 12 {
        chain.Push(
            SnapshotMxNMMontageUiaElement(
                current,
                expectedPid,
                mouseX,
                mouseY
            )
        )
        try current := UIA.RawViewWalker.TryGetParentElement(current)
        catch
            break
        if !IsObject(current)
            break
    }
    return chain
}

CollectMxNMMontageNativeChain(hwnd, expectedPid) {
    chain := []
    loop 12 {
        if !hwnd
            break
        snapshot := Map(
            "hwnd", hwnd,
            "className", "UNKNOWN",
            "controlId", "UNKNOWN",
            "rect", "UNKNOWN",
            "processMatches", false,
            "visible", false,
            "enabled", false
        )
        try snapshot["className"] :=
            SafeMxNMMontageIdentifier(WinGetClass("ahk_id " hwnd))
        try snapshot["controlId"] :=
            DllCall("user32.dll\GetDlgCtrlID", "ptr", hwnd, "int")
        try snapshot["rect"] :=
            FormatMxNMMontageRect(GetMxNMMontageWindowRect(hwnd))
        try snapshot["processMatches"] :=
            WinGetPID("ahk_id " hwnd) = expectedPid
        try snapshot["visible"] :=
            DllCall("user32.dll\IsWindowVisible", "ptr", hwnd, "int") != 0
        try snapshot["enabled"] :=
            DllCall("user32.dll\IsWindowEnabled", "ptr", hwnd, "int") != 0
        chain.Push(snapshot)
        hwnd := DllCall("user32.dll\GetParent", "ptr", hwnd, "ptr")
    }
    return chain
}

SnapshotMxNMMontageWindow(hwnd) {
    snapshot := Map(
        "hwnd", hwnd,
        "pid", 0,
        "processName", "UNKNOWN",
        "className", "UNKNOWN",
        "titleLength", 0,
        "rect", "UNKNOWN",
        "clientRect", "UNKNOWN",
        "rootOwner", 0,
        "dpi", 0,
        "scalingPercent", 0
    )
    try snapshot["pid"] := WinGetPID("ahk_id " hwnd)
    try snapshot["processName"] := WinGetProcessName("ahk_id " hwnd)
    try snapshot["className"] :=
        SafeMxNMMontageIdentifier(WinGetClass("ahk_id " hwnd))
    try snapshot["titleLength"] := StrLen(WinGetTitle("ahk_id " hwnd))
    try snapshot["rect"] :=
        FormatMxNMMontageRect(GetMxNMMontageWindowRect(hwnd))
    try snapshot["clientRect"] :=
        FormatMxNMMontageRect(GetMxNMMontageClientRectScreen(hwnd))
    snapshot["rootOwner"] := MxNMMontageRootOwner(hwnd)
    try snapshot["dpi"] :=
        DllCall("user32.dll\GetDpiForWindow", "ptr", hwnd, "uint")
    if snapshot["dpi"]
        snapshot["scalingPercent"] := Round(snapshot["dpi"] * 100 / 96)
    return snapshot
}

FormatMxNMMontageDiagnostic(session, state) {
    report :=
        "Test=MxNMMontageControlDiagnostic`r`n"
        . "DiagnosticVersion=0.1`r`n"
        . "State=" state "`r`n"
        . "ExpectedLayoutRows=5`r`n"
        . "ExpectedLayoutColumns=4`r`n"
        . "ConfiguredTargetRow=4`r`n"
        . "ConfiguredTargetColumn=4`r`n"
        . "InteractionMode=HOVER_ONLY_NO_AUTOMATION_CLICK`r`n"
        . "Privacy=NO_RAW_NAME_VALUE_OR_WINDOW_TITLE_OUTPUT`r`n"
        . "RawNamePersisted=false`r`n"
        . "RawValuePersisted=false`r`n"
        . "ScreenshotCaptured=false`r`n"
        . "MouseClickSent=false`r`n"
        . "TextInputSent=false`r`n"
        . "ElapsedMs=" (A_TickCount - session["startedAt"]) "`r`n"
        . "CapturedPointCount=" session["points"].Length "`r`n`r`n"
        . "[Viewer]`r`n"
        . FormatMxNMMontageWindow(session["viewer"])
        . "`r`n`r`n"
        . FormatMxNMMontageGridSummary(session["points"])

    for point in session["points"]
        report .= "`r`n`r`n" . FormatMxNMMontagePoint(point)
    return report "`r`n"
}

FormatMxNMMontageWindow(snapshot) {
    return "Hwnd=" snapshot["hwnd"] "`r`n"
        . "Pid=" snapshot["pid"] "`r`n"
        . "ProcessName=" snapshot["processName"] "`r`n"
        . "ClassName=" snapshot["className"] "`r`n"
        . "TitleLength=" snapshot["titleLength"] "`r`n"
        . "Rect=" snapshot["rect"] "`r`n"
        . "ClientRect=" snapshot["clientRect"] "`r`n"
        . "RootOwner=" snapshot["rootOwner"] "`r`n"
        . "Dpi=" snapshot["dpi"] "`r`n"
        . "ScalingPercent=" snapshot["scalingPercent"]
}

FormatMxNMMontageGridSummary(points) {
    topLeft := FindMxNMMontagePoint(points, "GRID_R1_C1")
    topRight := FindMxNMMontagePoint(points, "GRID_R1_C4")
    bottomLeft := FindMxNMMontagePoint(points, "GRID_R5_C1_VISIBLE")
    bottomRight := FindMxNMMontagePoint(points, "GRID_R5_C4_VISIBLE")
    target := FindMxNMMontagePoint(points, "GRID_R4_C4_TARGET")
    report := "[LayoutGrid]`r`n"
        . "CornerCaptureComplete="
        . MxNMMontageBoolean(
            IsObject(topLeft)
            && IsObject(topRight)
            && IsObject(bottomLeft)
            && IsObject(bottomRight)
        )
    if IsObject(topLeft) && IsObject(topRight)
        report .= "`r`nEstimatedColumnStep="
            . Round(
                (MxNMMontagePointX(topRight)
                    - MxNMMontagePointX(topLeft)) / 3,
                3
            )
    if IsObject(topLeft) && IsObject(bottomLeft)
        report .= "`r`nEstimatedRowStep="
            . Round(
                (MxNMMontagePointY(bottomLeft)
                    - MxNMMontagePointY(topLeft)) / 4,
                3
            )
    if IsObject(bottomLeft)
        report .= "`r`nRow5Col1PointProcessMatches="
            . MxNMMontageBoolean(bottomLeft["pointProcessMatches"])
            . "`r`nRow5Col1UiaOffscreen="
            . MxNMMontageUiaField(bottomLeft, "offscreen", "UNKNOWN")
            . "`r`nRow5Col1UiaRectContainsPoint="
            . MxNMMontageUiaField(
                bottomLeft,
                "rectContainsPoint",
                "UNKNOWN"
            )
    if IsObject(bottomRight)
        report .= "`r`nRow5Col4PointProcessMatches="
            . MxNMMontageBoolean(bottomRight["pointProcessMatches"])
            . "`r`nRow5Col4UiaOffscreen="
            . MxNMMontageUiaField(bottomRight, "offscreen", "UNKNOWN")
            . "`r`nRow5Col4UiaRectContainsPoint="
            . MxNMMontageUiaField(
                bottomRight,
                "rectContainsPoint",
                "UNKNOWN"
            )
    if IsObject(target)
        report .= "`r`nTargetR4C4Point=" target["screenPoint"]
    return report
}

FormatMxNMMontagePoint(point) {
    report := "[" point["label"] "]`r`n"
        . "ScreenPoint=" point["screenPoint"] "`r`n"
        . "ViewerClientPoint=" point["viewerClientPoint"] "`r`n"
        . "ViewerClientRatio=" point["viewerClientRatio"] "`r`n"
        . "PointHwnd=" point["pointHwnd"] "`r`n"
        . "PointPid=" point["pointPid"] "`r`n"
        . "PointProcessMatches="
        . MxNMMontageBoolean(point["pointProcessMatches"]) "`r`n"
        . "PointRootOwner=" point["pointRootOwner"] "`r`n"
        . "PointRootOwnerMatches="
        . MxNMMontageBoolean(point["pointRootOwnerMatches"]) "`r`n"
        . "UiaCaptured=" MxNMMontageBoolean(point["uiaCaptured"])
        . "`r`nUiaExceptionType=" point["uiaExceptionType"]
    if IsObject(point["uia"])
        report .= "`r`n`r`n[" point["label"] ".Uia]`r`n"
            . FormatMxNMMontageUia(point["uia"])
    report .= "`r`n`r`n[" point["label"] ".UiaParentChain]"
    for index, snapshot in point["uiaParentChain"]
        report .= "`r`n`r`nChain=" index "`r`n"
            . FormatMxNMMontageUia(snapshot)
    report .= "`r`n`r`n[" point["label"] ".NativeParentChain]"
    for index, snapshot in point["nativeChain"]
        report .= "`r`n`r`nChain=" index "`r`n"
            . FormatMxNMMontageNative(snapshot)
    return report
}

FormatMxNMMontageUia(snapshot) {
    return "ControlType=" snapshot["controlType"] "`r`n"
        . "ControlTypeName=" snapshot["controlTypeName"] "`r`n"
        . "SafeNameToken=" snapshot["safeNameToken"] "`r`n"
        . "NameLength=" snapshot["nameLength"] "`r`n"
        . "AutomationId=" snapshot["automationId"] "`r`n"
        . "ClassName=" snapshot["className"] "`r`n"
        . "Rect=" snapshot["rect"] "`r`n"
        . "RectContainsPoint="
        . MxNMMontageBoolean(snapshot["rectContainsPoint"]) "`r`n"
        . "ProcessMatches="
        . MxNMMontageBoolean(snapshot["processMatches"]) "`r`n"
        . "Enabled=" MxNMMontageBoolean(snapshot["enabled"]) "`r`n"
        . "Offscreen=" MxNMMontageBoolean(snapshot["offscreen"]) "`r`n"
        . "KeyboardFocusable="
        . MxNMMontageBoolean(snapshot["keyboardFocusable"]) "`r`n"
        . "InvokePattern="
        . MxNMMontageBoolean(snapshot["invokePattern"]) "`r`n"
        . "ExpandCollapsePattern="
        . MxNMMontageBoolean(snapshot["expandCollapsePattern"]) "`r`n"
        . "ValuePattern="
        . MxNMMontageBoolean(snapshot["valuePattern"]) "`r`n"
        . "RangeValuePattern="
        . MxNMMontageBoolean(snapshot["rangeValuePattern"]) "`r`n"
        . "SelectionPattern="
        . MxNMMontageBoolean(snapshot["selectionPattern"]) "`r`n"
        . "SelectionItemPattern="
        . MxNMMontageBoolean(snapshot["selectionItemPattern"]) "`r`n"
        . "TogglePattern="
        . MxNMMontageBoolean(snapshot["togglePattern"]) "`r`n"
        . "LegacyPattern="
        . MxNMMontageBoolean(snapshot["legacyPattern"])
}

FormatMxNMMontageNative(snapshot) {
    return "Hwnd=" snapshot["hwnd"] "`r`n"
        . "ClassName=" snapshot["className"] "`r`n"
        . "ControlId=" snapshot["controlId"] "`r`n"
        . "Rect=" snapshot["rect"] "`r`n"
        . "ProcessMatches="
        . MxNMMontageBoolean(snapshot["processMatches"]) "`r`n"
        . "Visible=" MxNMMontageBoolean(snapshot["visible"]) "`r`n"
        . "Enabled=" MxNMMontageBoolean(snapshot["enabled"])
}

FindMxNMMontagePoint(points, label) {
    for point in points {
        if point["label"] = label
            return point
    }
    return 0
}

MxNMMontageUiaField(point, field, fallback) {
    if !IsObject(point["uia"])
        return fallback
    if !point["uia"].Has(field)
        return fallback
    value := point["uia"][field]
    if value = true || value = false
        return MxNMMontageBoolean(value)
    return value
}

MxNMMontagePointX(point) {
    return Integer(StrSplit(point["screenPoint"], ",")[1])
}

MxNMMontagePointY(point) {
    return Integer(StrSplit(point["screenPoint"], ",")[2])
}

SafeMxNMMontageNameToken(rawName) {
    normalized := StrLower(Trim(String(rawName), " `t`r`n"))
    if normalized = "null"
        return "NULL"
    if normalized = "default"
        return "DEFAULT"
    if normalized = "lung"
        return "LUNG"
    return "REDACTED"
}

SafeMxNMMontageIdentifier(value) {
    value := String(value)
    if StrLen(value) > 160
        return SubStr(value, 1, 160) "[TRUNCATED]"
    return StrReplace(StrReplace(value, "`r", ""), "`n", "")
}

MxNMMontageClientPoint(hwnd, screenX, screenY) {
    rect := GetMxNMMontageClientRectScreen(hwnd)
    if !IsObject(rect)
        return {point: "UNKNOWN", ratio: "UNKNOWN"}
    width := rect.r - rect.l
    height := rect.b - rect.t
    clientX := screenX - rect.l
    clientY := screenY - rect.t
    ratio := "UNKNOWN"
    if width > 0 && height > 0
        ratio := Round(clientX / width, 6) "," Round(clientY / height, 6)
    return {point: clientX "," clientY, ratio: ratio}
}

GetMxNMMontageWindowRect(hwnd) {
    if !hwnd
        return 0
    try {
        WinGetPos &x, &y, &width, &height, "ahk_id " hwnd
        return {l: x, t: y, r: x + width, b: y + height}
    }
    return 0
}

GetMxNMMontageClientRectScreen(hwnd) {
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

MxNMMontageWindowFromPoint(mouseX, mouseY) {
    pointValue := mouseY << 32 | (mouseX & 0xFFFFFFFF)
    return DllCall(
        "user32.dll\WindowFromPoint",
        "int64",
        pointValue,
        "ptr"
    )
}

MxNMMontageRootOwner(hwnd) {
    if !hwnd
        return 0
    rootOwner := DllCall(
        "user32.dll\GetAncestor",
        "ptr",
        hwnd,
        "uint",
        3,
        "ptr"
    )
    return rootOwner ? rootOwner : hwnd
}

MxNMMontageRectContainsPoint(rect, x, y) {
    return IsObject(rect)
        && x >= rect.l
        && x < rect.r
        && y >= rect.t
        && y < rect.b
}

FormatMxNMMontageRect(rect) {
    if !IsObject(rect)
        return "UNKNOWN"
    return rect.l "," rect.t "," rect.r "," rect.b
}

MxNMMontageDiagnosticViewerStillAvailable(session) {
    try return WinExist("ahk_pid " session["viewerPid"]) != 0
    return false
}

WriteMxNMMontageDiagnosticReport(report) {
    outputDirectory := A_Temp "\MedExAHK"
    outputPath := outputDirectory "\mxnm_montage_control_diagnostic.txt"
    DirCreate outputDirectory
    try FileDelete outputPath
    FileAppend report, outputPath, "UTF-8"
    return outputPath
}

MxNMMontageBoolean(value) {
    return value ? "true" : "false"
}

ShowMxNMMontageDiagnosticTip(text) {
    ToolTip text
    SetTimer (() => ToolTip()), -8000
}
