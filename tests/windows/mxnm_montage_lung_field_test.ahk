#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\Lib\UIA.ahk

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

global MxNMMontageLungFieldSession := 0
global MxNMMontageLungFieldBusy := false

^!+F10::AdvanceMxNMMontageLungFieldTest()
^!+F7::AbortMxNMMontageLungFieldTest()

AdvanceMxNMMontageLungFieldTest() {
    global MxNMMontageLungFieldSession
    global MxNMMontageLungFieldBusy

    if MxNMMontageLungFieldBusy
        return
    MxNMMontageLungFieldBusy := true
    try {
        if !IsObject(MxNMMontageLungFieldSession) {
            StartMxNMMontageLungFieldTest()
            return
        }
        session := MxNMMontageLungFieldSession
        if !WaitForMxNMMontageLungFieldChordRelease() {
            FinishMxNMMontageLungFieldTest(
                "FAILED",
                "HOTKEY_RELEASE_TIMEOUT"
            )
            return
        }
        if !MxNMMontageLungViewerStillActive(session) {
            FinishMxNMMontageLungFieldTest(
                "FAILED",
                "VIEWER_FOREGROUND_CHANGED"
            )
            return
        }

        stages := MxNMMontageLungFieldStages()
        stageIndex := session["nextStage"]
        if stageIndex > stages.Length {
            FinishMxNMMontageLungFieldTest("COMPLETE", "READY")
            return
        }

        MouseGetPos &mouseBeforeX, &mouseBeforeY
        startedAt := A_TickCount
        try result := stages[stageIndex].handler.Call(session)
        catch as mxnmMontageLungStageErr {
            result := NewMxNMMontageLungFieldResult(
                false,
                "UNEXPECTED_STAGE_ERROR"
            )
            result["exceptionType"] := Type(mxnmMontageLungStageErr)
        }
        result["id"] := stages[stageIndex].id
        result["stage"] := stageIndex
        result["elapsedMs"] := A_TickCount - startedAt
        MouseGetPos &mouseAfterX, &mouseAfterY
        result["mouseUnchanged"] :=
            mouseBeforeX = mouseAfterX && mouseBeforeY = mouseAfterY
        result["foregroundStillValid"] :=
            MxNMMontageLungViewerStillActive(session)
        session["steps"].Push(result)

        if !result["ok"] || !result["foregroundStillValid"] {
            failureCode := result["ok"]
                ? "VIEWER_CHANGED_AFTER_STAGE"
                : result["code"]
            FinishMxNMMontageLungFieldTest("FAILED", failureCode)
            return
        }

        session["nextStage"] += 1
        if session["nextStage"] > stages.Length {
            FinishMxNMMontageLungFieldTest("COMPLETE", "READY")
            return
        }
        nextStage := stages[session["nextStage"]]
        ShowMxNMMontageLungFieldTip(
            "步骤 " stageIndex "/" stages.Length " 已执行："
            . stages[stageIndex].label "`n"
            . "请目视确认 Viewer，再按 Ctrl+Alt+Shift+F10：`n"
            . nextStage.label "`n"
            . "异常时按 Ctrl+Alt+Shift+F7 中止。"
        )
    } finally {
        MxNMMontageLungFieldBusy := false
    }
}

StartMxNMMontageLungFieldTest() {
    global MxNMMontageLungFieldSession

    viewerHwnd := WinExist("A")
    if !viewerHwnd {
        ShowMxNMMontageLungFieldTip("未找到前台 Viewer。")
        return
    }
    try processName := WinGetProcessName("ahk_id " viewerHwnd)
    catch {
        processName := ""
    }
    if StrLower(processName) != "medexnmfusion.exe" {
        ShowMxNMMontageLungFieldTip(
            "前台窗口不是 MedExNMFusion.exe，测试未开始。"
        )
        return
    }
    try viewerPid := WinGetPID("ahk_id " viewerHwnd)
    catch {
        ShowMxNMMontageLungFieldTip("无法读取 Viewer PID。")
        return
    }
    viewerRootOwner := MxNMMontageLungRootOwner(viewerHwnd)
    if !viewerRootOwner
        viewerRootOwner := viewerHwnd
    viewerRect := GetMxNMMontageLungWindowRect(viewerRootOwner)
    if !IsObject(viewerRect) {
        ShowMxNMMontageLungFieldTip("无法读取 Viewer 矩形。")
        return
    }

    MxNMMontageLungFieldSession := Map(
        "startedAt", A_TickCount,
        "viewerHwnd", viewerHwnd,
        "viewerRootOwner", viewerRootOwner,
        "viewerPid", viewerPid,
        "viewerProcessName", processName,
        "viewerRect", FormatMxNMMontageLungRect(viewerRect),
        "viewerDpi", MxNMMontageLungWindowDpi(viewerRootOwner),
        "nextStage", 1,
        "steps", []
    )
    ShowMxNMMontageLungFieldTip(
        "Lung montage 受控执行测试已绑定 Viewer。`n"
        . "只在无患者隐私的测试检查中继续。`n"
        . "每次 Ctrl+Alt+Shift+F10 只执行一步。`n"
        . "下一步：选择布局第 4 行第 4 列。`n"
        . "Ctrl+Alt+Shift+F7 可中止。"
    )
}

AbortMxNMMontageLungFieldTest() {
    global MxNMMontageLungFieldSession
    if !IsObject(MxNMMontageLungFieldSession) {
        ShowMxNMMontageLungFieldTip("当前没有进行中的 Lung 测试。")
        return
    }
    FinishMxNMMontageLungFieldTest("ABORTED", "OPERATOR_ABORTED")
}

MxNMMontageLungFieldStages() {
    return [
        {
            id: "layout-r4-c4",
            label: "选择布局第 4 行第 4 列",
            handler: RunMxNMMontageLungStaticClick.Bind(
                21112,
                "Static",
                0.881579,
                0.771014,
                0,
                ""
            )
        },
        {
            id: "tab-3",
            label: "进入 Tab 3",
            handler: RunMxNMMontageLungStaticClick.Bind(
                21007,
                "Static",
                0.479866,
                0.5,
                21155,
                "ComboBox"
            )
        },
        {
            id: "caption-null",
            label: "四角图注选择 null",
            handler: RunMxNMMontageLungComboSelection.Bind(21155, "null")
        },
        {
            id: "tab-5",
            label: "进入 Tab 5",
            handler: RunMxNMMontageLungStaticClick.Bind(
                21007,
                "Static",
                0.869128,
                0.5,
                21014,
                "ComboBox"
            )
        },
        {
            id: "window-lung",
            label: "窗宽预设选择 lung",
            handler: RunMxNMMontageLungComboSelection.Bind(21014, "lung")
        },
        {
            id: "thickness-value",
            label: "层厚设置为 7.5",
            handler: RunMxNMMontageLungEditValue.Bind(21012, "7.5")
        },
        {
            id: "thickness-apply",
            label: "调用层厚更改按钮",
            handler: RunMxNMMontageLungButtonInvoke.Bind(21015)
        },
        {
            id: "slice-value",
            label: "当前层设置为 23",
            handler: RunMxNMMontageLungEditValue.Bind(21201, "23")
        },
        {
            id: "slice-jump",
            label: "调用当前层跳转按钮",
            handler: RunMxNMMontageLungButtonInvoke.Bind(21203)
        },
        {
            id: "tab-4",
            label: "进入 Tab 4",
            handler: RunMxNMMontageLungStaticClick.Bind(
                21007,
                "Static",
                0.681208,
                0.5,
                21032,
                "Edit"
            )
        },
        {
            id: "zoom-value",
            label: "放大倍数设置为 0.9",
            handler: RunMxNMMontageLungEditValue.Bind(21032, "0.9")
        },
        {
            id: "zoom-enter",
            label: "发送 Enter 应用放大倍数",
            handler: RunMxNMMontageLungEnterCommit
        }
    ]
}

RunMxNMMontageLungStaticClick(
    controlId,
    className,
    xRatio,
    yRatio,
    effectControlId,
    effectClassName,
    session
) {
    result := NewMxNMMontageLungFieldResult(false, "CONTROL_NOT_UNIQUE")
    resolved := ResolveMxNMMontageLungControl(
        session,
        controlId,
        className
    )
    MergeMxNMMontageLungResult(result, resolved)
    if !resolved["ok"]
        return result

    rect := resolved["rectObject"]
    width := rect.r - rect.l
    height := rect.b - rect.t
    if width < 40 || height < 20 {
        result["code"] := "CONTROL_RECT_TOO_SMALL"
        return result
    }
    clientX := Round(width * xRatio)
    clientY := Round(height * yRatio)
    screenX := rect.l + clientX
    screenY := rect.t + clientY
    result["screenPoint"] := screenX "," screenY
    result["clientPoint"] := clientX "," clientY
    pointHwnd := MxNMMontageLungWindowFromPoint(screenX, screenY)
    result["windowFromPoint"] := pointHwnd
    if pointHwnd != resolved["hwnd"] {
        result["code"] := "POINT_HWND_MISMATCH"
        return result
    }

    MouseGetPos &originalMouseX, &originalMouseY
    try {
        MouseClick "left", screenX, screenY, 1, 0
        result["mouseClickSent"] := true
    } catch as mxnmMontageLungPhysicalClickErr {
        result["code"] := "STATIC_PHYSICAL_CLICK_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungPhysicalClickErr)
    } finally {
        try {
            MouseMove originalMouseX, originalMouseY, 0
            result["cursorRestored"] := true
        }
        catch {
        }
    }
    if !result["mouseClickSent"]
        return result
    if !result["cursorRestored"] {
        result["code"] := "CURSOR_RESTORE_FAILED"
        return result
    }
    if effectControlId {
        result["effectControlId"] := effectControlId
        effectResult := WaitForMxNMMontageLungControl(
            session,
            effectControlId,
            effectClassName,
            1500
        )
        result["effectObserved"] := effectResult["ok"]
        result["effectCandidateCount"] := effectResult["candidateCount"]
        if !result["effectObserved"] {
            result["code"] := "STATIC_CLICK_NO_EFFECT"
            return result
        }
        result["code"] := "STATIC_CLICK_EFFECT_CONFIRMED"
    } else {
        result["code"] := "STATIC_CLICK_VISUAL_CONFIRMATION_REQUIRED"
    }
    result["ok"] := true
    return result
}

WaitForMxNMMontageLungControl(
    session,
    controlId,
    className,
    timeoutMs
) {
    startedAt := A_TickCount
    lastResult := 0
    loop {
        lastResult := ResolveMxNMMontageLungControl(
            session,
            controlId,
            className
        )
        if lastResult["ok"]
            return lastResult
        if A_TickCount - startedAt >= timeoutMs
            return lastResult
        Sleep 50
    }
}

RunMxNMMontageLungComboSelection(controlId, optionName, session) {
    result := NewMxNMMontageLungFieldResult(false, "CONTROL_NOT_UNIQUE")
    resolved := ResolveMxNMMontageLungControl(
        session,
        controlId,
        "ComboBox"
    )
    MergeMxNMMontageLungResult(result, resolved)
    result["requestedOption"] := StrUpper(optionName)
    if !resolved["ok"]
        return result
    try combo := UIA.ElementFromHandle(resolved["hwnd"])
    catch as mxnmMontageLungComboElementErr {
        result["code"] := "COMBO_UIA_ELEMENT_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungComboElementErr)
        return result
    }
    try {
        if combo.ProcessId != session["viewerPid"]
            throw Error("Combo PID mismatch")
        if !combo.IsExpandCollapsePatternAvailable
            throw Error("ExpandCollapse unavailable")
        combo.ExpandCollapsePattern.Expand()
    } catch as mxnmMontageLungExpandErr {
        result["code"] := "COMBO_EXPAND_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungExpandErr)
        return result
    }

    matches := []
    deadline := A_TickCount + 900
    loop {
        try matches := combo.FindElements({
            Name: optionName,
            Type: "ListItem"
        })
        catch
            matches := []
        if matches.Length = 1 || A_TickCount >= deadline
            break
        Sleep 20
    }
    result["optionCandidateCount"] := matches.Length
    if matches.Length != 1 {
        result["code"] := "COMBO_OPTION_NOT_UNIQUE"
        try combo.ExpandCollapsePattern.Collapse()
        return result
    }
    option := matches[1]
    try {
        if option.ProcessId != session["viewerPid"]
            throw Error("Option PID mismatch")
        if !option.IsSelectionItemPatternAvailable
            throw Error("SelectionItem unavailable")
        option.SelectionItemPattern.Select()
        result["selectionDispatched"] := true
    } catch as mxnmMontageLungSelectionErr {
        result["code"] := "COMBO_SELECTION_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungSelectionErr)
        try combo.ExpandCollapsePattern.Collapse()
        return result
    }
    Sleep 120
    try combo.ExpandCollapsePattern.Collapse()
    try currentValue := combo.ValuePattern.Value
    catch {
        currentValue := ""
    }
    result["valueMatches"] :=
        StrLower(Trim(currentValue, " `t`r`n")) = StrLower(optionName)
    currentValue := ""
    if !result["valueMatches"] {
        result["code"] := "COMBO_VALUE_NOT_CONFIRMED"
        return result
    }
    result["ok"] := true
    result["code"] := "COMBO_SELECTION_CONFIRMED"
    return result
}

RunMxNMMontageLungEditValue(controlId, requestedValue, session) {
    result := NewMxNMMontageLungFieldResult(false, "CONTROL_NOT_UNIQUE")
    resolved := ResolveMxNMMontageLungControl(session, controlId, "Edit")
    MergeMxNMMontageLungResult(result, resolved)
    result["requestedValue"] := requestedValue
    if !resolved["ok"]
        return result
    try element := UIA.ElementFromHandle(resolved["hwnd"])
    catch as mxnmMontageLungEditElementErr {
        result["code"] := "EDIT_UIA_ELEMENT_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungEditElementErr)
        return result
    }
    try {
        if element.ProcessId != session["viewerPid"]
            throw Error("Edit PID mismatch")
        if !element.IsValuePatternAvailable
            throw Error("ValuePattern unavailable")
        element.ValuePattern.SetValue(requestedValue)
        result["setValueDispatched"] := true
        Sleep 60
        observedValue := element.ValuePattern.Value
        result["valueMatches"] := String(observedValue) = requestedValue
        observedValue := ""
    } catch as mxnmMontageLungSetValueErr {
        result["code"] := "EDIT_SET_VALUE_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungSetValueErr)
        return result
    }
    if !result["valueMatches"] {
        result["code"] := "EDIT_VALUE_NOT_CONFIRMED"
        return result
    }
    result["ok"] := true
    result["code"] := "EDIT_VALUE_CONFIRMED"
    return result
}

RunMxNMMontageLungButtonInvoke(controlId, session) {
    result := NewMxNMMontageLungFieldResult(false, "CONTROL_NOT_UNIQUE")
    resolved := ResolveMxNMMontageLungControl(session, controlId, "Button")
    MergeMxNMMontageLungResult(result, resolved)
    if !resolved["ok"]
        return result
    try element := UIA.ElementFromHandle(resolved["hwnd"])
    catch as mxnmMontageLungButtonElementErr {
        result["code"] := "BUTTON_UIA_ELEMENT_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungButtonElementErr)
        return result
    }
    try {
        if element.ProcessId != session["viewerPid"]
            throw Error("Button PID mismatch")
        if !element.IsInvokePatternAvailable
            throw Error("Invoke unavailable")
        element.InvokePattern.Invoke()
        result["invokeDispatched"] := true
    } catch as mxnmMontageLungInvokeErr {
        result["code"] := "BUTTON_INVOKE_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungInvokeErr)
        return result
    }
    Sleep 120
    result["ok"] := true
    result["code"] := "BUTTON_INVOKE_DISPATCHED"
    return result
}

RunMxNMMontageLungEnterCommit(session) {
    result := NewMxNMMontageLungFieldResult(false, "CONTROL_NOT_UNIQUE")
    resolved := ResolveMxNMMontageLungControl(session, 21032, "Edit")
    MergeMxNMMontageLungResult(result, resolved)
    if !resolved["ok"]
        return result
    try element := UIA.ElementFromHandle(resolved["hwnd"])
    catch as mxnmMontageLungZoomElementErr {
        result["code"] := "ZOOM_UIA_ELEMENT_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungZoomElementErr)
        return result
    }
    try element.SetFocus()
    catch as mxnmMontageLungFocusErr {
        result["code"] := "ZOOM_FOCUS_FAILED"
        result["exceptionType"] := Type(mxnmMontageLungFocusErr)
        return result
    }
    try focused := UIA.GetFocusedElement()
    catch {
        focused := 0
    }
    if !IsObject(focused) {
        result["code"] := "ZOOM_FOCUS_NOT_CONFIRMED"
        return result
    }
    try focusMatches :=
        focused.ProcessId = session["viewerPid"]
        && String(focused.AutomationId) = "21032"
    catch {
        focusMatches := false
    }
    result["focusMatches"] := focusMatches
    if !focusMatches {
        result["code"] := "ZOOM_FOCUS_NOT_CONFIRMED"
        return result
    }
    if !MxNMMontageLungViewerStillActive(session) {
        result["code"] := "VIEWER_CHANGED_BEFORE_ENTER"
        return result
    }
    Send "{Enter}"
    result["enterSent"] := true
    Sleep 120
    result["ok"] := true
    result["code"] := "ENTER_DISPATCHED"
    return result
}

ResolveMxNMMontageLungControl(session, controlId, className) {
    result := Map(
        "ok", false,
        "code", "CONTROL_NOT_UNIQUE",
        "controlId", controlId,
        "expectedClass", className,
        "candidateCount", 0,
        "win32CandidateCount", 0,
        "uiaRawCandidateCount", 0,
        "uiaCandidateCount", 0,
        "uiaQuerySucceeded", false,
        "hwnd", 0,
        "parentHwnd", 0,
        "rect", "UNKNOWN",
        "rectObject", 0
    )
    win32Candidates := []
    callback := CallbackCreate(
        CollectMxNMMontageLungControl.Bind(
            session,
            controlId,
            className,
            win32Candidates
        ),
        "Fast",
        2
    )
    try DllCall(
        "User32\EnumChildWindows",
        "Ptr", session["viewerRootOwner"],
        "Ptr", callback,
        "Ptr", 0,
        "Int"
    )
    finally CallbackFree(callback)
    result["win32CandidateCount"] := win32Candidates.Length

    uiaResult := CollectMxNMMontageLungUiaControls(
        session,
        controlId,
        className
    )
    result["uiaQuerySucceeded"] := uiaResult["querySucceeded"]
    result["uiaRawCandidateCount"] := uiaResult["rawCount"]
    result["uiaCandidateCount"] := uiaResult["candidates"].Length

    candidatesByHwnd := Map()
    for candidate in win32Candidates
        candidatesByHwnd[candidate.hwnd] := candidate
    for candidate in uiaResult["candidates"]
        candidatesByHwnd[candidate.hwnd] := candidate
    candidates := []
    for _, candidate in candidatesByHwnd
        candidates.Push(candidate)
    result["candidateCount"] := candidates.Length
    if candidates.Length != 1
        return result
    candidate := candidates[1]
    result["hwnd"] := candidate.hwnd
    result["parentHwnd"] := candidate.parentHwnd
    result["rect"] := FormatMxNMMontageLungRect(candidate.rect)
    result["rectObject"] := candidate.rect
    result["ok"] := true
    result["code"] := "CONTROL_READY"
    return result
}

CollectMxNMMontageLungUiaControls(session, controlId, className) {
    result := Map(
        "querySucceeded", false,
        "rawCount", 0,
        "candidates", []
    )
    try rootElement := UIA.ElementFromHandle(session["viewerRootOwner"])
    catch
        return result
    try elements := rootElement.FindElements({
        AutomationId: String(controlId)
    })
    catch
        return result
    result["querySucceeded"] := true
    result["rawCount"] := elements.Length
    viewerRect := GetMxNMMontageLungWindowRect(session["viewerRootOwner"])
    if !IsObject(viewerRect)
        return result
    for element in elements {
        try {
            if element.ProcessId != session["viewerPid"]
                continue
            if StrLower(element.ClassName) != StrLower(className)
                continue
            if !element.IsEnabled || element.IsOffscreen
                continue
            hwnd := element.NativeWindowHandle
            if !hwnd
                continue
            if MxNMMontageLungRootOwner(hwnd)
                != session["viewerRootOwner"] {
                continue
            }
            rect := GetMxNMMontageLungWindowRect(hwnd)
            if !IsObject(rect)
                || !MxNMMontageLungRectInside(rect, viewerRect) {
                continue
            }
            parentHwnd := DllCall(
                "User32\GetParent",
                "Ptr", hwnd,
                "Ptr"
            )
            result["candidates"].Push({
                hwnd: hwnd,
                parentHwnd: parentHwnd,
                rect: rect
            })
        }
    }
    return result
}

CollectMxNMMontageLungControl(
    session,
    expectedControlId,
    expectedClass,
    candidates,
    hwnd,
    *
) {
    if !hwnd
        return true
    try controlId := DllCall(
        "User32\GetDlgCtrlID",
        "Ptr", hwnd,
        "Int"
    )
    catch
        return true
    if controlId != expectedControlId
        return true
    try className := WinGetClass("ahk_id " hwnd)
    catch
        return true
    if StrLower(className) != StrLower(expectedClass)
        return true
    try pid := WinGetPID("ahk_id " hwnd)
    catch
        return true
    if pid != session["viewerPid"]
        return true
    if !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")
        || !DllCall("User32\IsWindowEnabled", "Ptr", hwnd, "Int") {
        return true
    }
    if MxNMMontageLungRootOwner(hwnd) != session["viewerRootOwner"]
        return true
    rect := GetMxNMMontageLungWindowRect(hwnd)
    viewerRect := GetMxNMMontageLungWindowRect(session["viewerRootOwner"])
    if !IsObject(rect)
        || !IsObject(viewerRect)
        || !MxNMMontageLungRectInside(rect, viewerRect) {
        return true
    }
    parentHwnd := DllCall("User32\GetParent", "Ptr", hwnd, "Ptr")
    candidates.Push({
        hwnd: hwnd,
        parentHwnd: parentHwnd,
        rect: rect
    })
    return true
}

NewMxNMMontageLungFieldResult(ok, code) {
    return Map(
        "ok", ok,
        "code", code,
        "id", "UNKNOWN",
        "stage", 0,
        "elapsedMs", 0,
        "mouseUnchanged", false,
        "foregroundStillValid", false,
        "controlId", 0,
        "expectedClass", "UNKNOWN",
        "candidateCount", 0,
        "win32CandidateCount", 0,
        "uiaRawCandidateCount", 0,
        "uiaCandidateCount", 0,
        "uiaQuerySucceeded", false,
        "hwnd", 0,
        "parentHwnd", 0,
        "rect", "UNKNOWN",
        "screenPoint", "NOT_APPLICABLE",
        "clientPoint", "NOT_APPLICABLE",
        "windowFromPoint", 0,
        "downSent", false,
        "upSent", false,
        "mouseClickSent", false,
        "cursorRestored", false,
        "effectControlId", 0,
        "effectCandidateCount", 0,
        "effectObserved", false,
        "requestedOption", "NOT_APPLICABLE",
        "optionCandidateCount", 0,
        "selectionDispatched", false,
        "requestedValue", "NOT_APPLICABLE",
        "setValueDispatched", false,
        "valueMatches", false,
        "invokeDispatched", false,
        "focusMatches", false,
        "enterSent", false,
        "exceptionType", ""
    )
}

MergeMxNMMontageLungResult(result, source) {
    for key, value in source {
        if key = "ok" || key = "rectObject"
            continue
        result[key] := value
    }
}

WaitForMxNMMontageLungFieldChordRelease() {
    return KeyWait("F10", "T2")
        && KeyWait("Ctrl", "T2")
        && KeyWait("Alt", "T2")
        && KeyWait("Shift", "T2")
}

MxNMMontageLungViewerStillActive(session) {
    foregroundHwnd := WinExist("A")
    if !foregroundHwnd
        return false
    try foregroundPid := WinGetPID("ahk_id " foregroundHwnd)
    catch
        return false
    return foregroundPid = session["viewerPid"]
        && MxNMMontageLungRootOwner(foregroundHwnd)
            = session["viewerRootOwner"]
}

FinishMxNMMontageLungFieldTest(state, code) {
    global MxNMMontageLungFieldSession

    if !IsObject(MxNMMontageLungFieldSession)
        return
    session := MxNMMontageLungFieldSession
    report := FormatMxNMMontageLungFieldReport(session, state, code)
    outputPath := WriteMxNMMontageLungFieldReport(report)
    A_Clipboard := report
    copied := ClipWait(2)
    MxNMMontageLungFieldSession := 0
    ShowMxNMMontageLungFieldTip(
        "Lung montage 测试结束：" state " / " code "`n"
        . "结果：" outputPath "`n"
        . (copied ? "同时已复制到剪贴板。" : "剪贴板写入未确认。")
    )
}

FormatMxNMMontageLungFieldReport(session, state, code) {
    mouseMovementSent := MxNMMontageLungAnyStepTrue(
        session,
        "mouseClickSent"
    ) || MxNMMontageLungAnyStepTrue(session, "cursorRestored")
    mouseButtonInputSent := MxNMMontageLungAnyStepTrue(
        session,
        "mouseClickSent"
    )
    report :=
        "Test=MxNMMontageLungFieldTest`r`n"
        . "FieldTestVersion=0.3`r`n"
        . "State=" state "`r`n"
        . "Code=" code "`r`n"
        . "InteractionMode=OPERATOR_STEPPED_ONE_ACTION_PER_HOTKEY`r`n"
        . "Profile=LUNG_7.5_23_0.9_LAYOUT_R4_C4`r`n"
        . "MouseMovementSent=" MxNMMontageLungBoolean(mouseMovementSent) "`r`n"
        . "MouseButtonInputSent=" MxNMMontageLungBoolean(mouseButtonInputSent) "`r`n"
        . "TextKeyboardInputSent=false`r`n"
        . "KeyboardInputSent=ENTER_ONLY`r`n"
        . "ClipboardPayloadRead=false`r`n"
        . "ScreenshotCaptured=false`r`n"
        . "ViewerHwnd=" session["viewerHwnd"] "`r`n"
        . "ViewerRootOwner=" session["viewerRootOwner"] "`r`n"
        . "ViewerPid=" session["viewerPid"] "`r`n"
        . "ViewerProcessName=" session["viewerProcessName"] "`r`n"
        . "ViewerRect=" session["viewerRect"] "`r`n"
        . "ViewerDpi=" session["viewerDpi"] "`r`n"
        . "ElapsedMs=" (A_TickCount - session["startedAt"]) "`r`n"
        . "CompletedStepCount=" session["steps"].Length
    for step in session["steps"]
        report .= "`r`n`r`n[Step" step["stage"] "]`r`n"
            . FormatMxNMMontageLungFieldStep(step)
    return report "`r`n"
}

MxNMMontageLungAnyStepTrue(session, key) {
    for step in session["steps"] {
        if step.Has(key) && step[key]
            return true
    }
    return false
}

FormatMxNMMontageLungFieldStep(step) {
    report := "Id=" step["id"]
    booleanKeys := Map(
        "ok", true,
        "mouseUnchanged", true,
        "foregroundStillValid", true,
        "uiaQuerySucceeded", true,
        "downSent", true,
        "upSent", true,
        "mouseClickSent", true,
        "cursorRestored", true,
        "effectObserved", true,
        "selectionDispatched", true,
        "setValueDispatched", true,
        "valueMatches", true,
        "invokeDispatched", true,
        "focusMatches", true,
        "enterSent", true
    )
    for key in [
        "ok",
        "code",
        "elapsedMs",
        "mouseUnchanged",
        "foregroundStillValid",
        "controlId",
        "expectedClass",
        "candidateCount",
        "win32CandidateCount",
        "uiaRawCandidateCount",
        "uiaCandidateCount",
        "uiaQuerySucceeded",
        "hwnd",
        "parentHwnd",
        "rect",
        "screenPoint",
        "clientPoint",
        "windowFromPoint",
        "downSent",
        "upSent",
        "mouseClickSent",
        "cursorRestored",
        "effectControlId",
        "effectCandidateCount",
        "effectObserved",
        "requestedOption",
        "optionCandidateCount",
        "selectionDispatched",
        "requestedValue",
        "setValueDispatched",
        "valueMatches",
        "invokeDispatched",
        "focusMatches",
        "enterSent",
        "exceptionType"
    ] {
        value := step[key]
        if booleanKeys.Has(key)
            value := MxNMMontageLungBoolean(value)
        report .= "`r`n" key "=" value
    }
    return report
}

WriteMxNMMontageLungFieldReport(report) {
    outputDirectory := A_Temp "\MedExAHK"
    outputPath := outputDirectory "\mxnm_montage_lung_field_test.txt"
    DirCreate outputDirectory
    try FileDelete outputPath
    FileAppend report, outputPath, "UTF-8"
    return outputPath
}

GetMxNMMontageLungWindowRect(hwnd) {
    if !hwnd
        return 0
    try {
        WinGetPos &x, &y, &width, &height, "ahk_id " hwnd
        return {l: x, t: y, r: x + width, b: y + height}
    }
    return 0
}

MxNMMontageLungWindowDpi(hwnd) {
    try return DllCall(
        "User32\GetDpiForWindow",
        "Ptr", hwnd,
        "UInt"
    )
    return 0
}

MxNMMontageLungWindowFromPoint(x, y) {
    pointValue := y << 32 | (x & 0xFFFFFFFF)
    return DllCall(
        "User32\WindowFromPoint",
        "Int64", pointValue,
        "Ptr"
    )
}

MxNMMontageLungRootOwner(hwnd) {
    if !hwnd
        return 0
    rootOwner := DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", 3,
        "Ptr"
    )
    return rootOwner ? rootOwner : hwnd
}

MxNMMontageLungRectInside(inner, outer) {
    return inner.l >= outer.l
        && inner.t >= outer.t
        && inner.r <= outer.r
        && inner.b <= outer.b
        && inner.r > inner.l
        && inner.b > inner.t
}

FormatMxNMMontageLungRect(rect) {
    if !IsObject(rect)
        return "UNKNOWN"
    return rect.l "," rect.t "," rect.r "," rect.b
}

MxNMMontageLungBoolean(value) {
    return value ? "true" : "false"
}

ShowMxNMMontageLungFieldTip(text) {
    ToolTip text
    SetTimer (() => ToolTip()), -9000
}
