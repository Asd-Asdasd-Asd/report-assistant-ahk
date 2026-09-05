ViewerToolHotkeyDefinitions(settings, bareOnly := false) {
    definitions := []
    if settings.ViewerArrowEnabled
        && settings.ViewerArrowChord != ""
        && ViewerHotkeyChordIsBare(settings.ViewerArrowChord) = bareOnly {
        definitions.Push(HotkeyDefinition(
            "viewer-tool-arrow",
            settings.ViewerArrowChord,
            InvokeMxNMViewerToolHotkey.Bind(
                "arrow",
                settings.ViewerArrowChord
            )
        ))
    }
    if settings.ViewerLengthEnabled
        && settings.ViewerLengthChord != ""
        && ViewerHotkeyChordIsBare(settings.ViewerLengthChord) = bareOnly {
        definitions.Push(HotkeyDefinition(
            "viewer-tool-length",
            settings.ViewerLengthChord,
            InvokeMxNMViewerToolHotkey.Bind(
                "length",
                settings.ViewerLengthChord
            )
        ))
    }
    if settings.ViewerSuv3DEnabled
        && settings.ViewerSuv3DChord != ""
        && ViewerHotkeyChordIsBare(settings.ViewerSuv3DChord) = bareOnly {
        definitions.Push(HotkeyDefinition(
            "viewer-tool-suv3d",
            settings.ViewerSuv3DChord,
            InvokeMxNMViewerSuv3DHotkey.Bind(
                settings.ViewerSuv3DChord
            )
        ))
    }
    if settings.ViewerClearEnabled
        && settings.ViewerClearChord != ""
        && ViewerHotkeyChordIsBare(settings.ViewerClearChord) = bareOnly {
        definitions.Push(HotkeyDefinition(
            "viewer-clear-annotations",
            settings.ViewerClearChord,
            InvokeMxNMViewerClearHotkey.Bind(
                settings.ViewerClearChord
            )
        ))
    }
    return definitions
}

ViewerCaptureHotkeyDefinitions(settings) {
    if !settings.ViewerCaptureEnabled
        || settings.ViewerCaptureChord = "" {
        return []
    }
    return [
        HotkeyDefinition(
            "viewer-capture-f12",
            settings.ViewerCaptureChord,
            InvokeMxNMViewerCaptureHotkey.Bind(
                settings.ViewerCaptureChord
            )
        )
    ]
}

MedExViewerForegroundActive(*) {
    global VIEWER_EXE

    try foregroundHwnd := WinExist("A")
    catch
        return false
    if !foregroundHwnd
        return false
    try processName := WinGetProcessName("ahk_id " foregroundHwnd)
    catch
        return false
    return StrLower(processName) = StrLower(VIEWER_EXE)
}

InvokeMxNMViewerCaptureHotkey(chord, *) {
    return RunMxNMViewerHotkey("capture", chord)
}

; One bounded entry transaction for all Viewer hotkeys. No action is replayed.
RunMxNMViewerHotkey(commandName, chord) {
    static active := false
    action := commandName = "capture" ? "ViewerCapture"
        : commandName = "clear" ? "ViewerClear" : "ViewerTool"
    operation := BeginAutomationDiagnosticOperation(action)
    operation.SetField("viewer.command", commandName)
    operation.SetField("viewer.dispatchResult", "NOT_DISPATCHED")
    operation.SetField("viewer.effectState", "UNOBSERVABLE")
    if active {
        operation.Complete("CANCELLED", "BUSY")
        return false
    }
    active := true
    resultCode := "UNEXPECTED_ERROR"
    outcome := "FAILED"
    try {
        foregroundHwnd := WinExist("A")
        operation.SetField("viewer.foregroundHwnd", foregroundHwnd)
        if !foregroundHwnd || !(commandName = "capture"
            ? MedExViewerForegroundActive() : MedExViewerToolForegroundActive()) {
            resultCode := "WRONG_FOREGROUND"
            outcome := "CANCELLED"
            return false
        }
        operation.SetField("viewer.keysBefore", MxNMViewerModifierState())
        releaseStartedAt := A_TickCount
        resultCode := WaitMxNMViewerHotkeyRelease(chord, foregroundHwnd)
        operation.SetField("viewer.releaseMs", A_TickCount - releaseStartedAt)
        operation.SetField("viewer.keysAfter", MxNMViewerModifierState())
        if resultCode != "RELEASED" {
            outcome := "CANCELLED"
            if resultCode = "KEY_RELEASE_TIMEOUT"
                Flash("快捷键等待松键超时，请松开按键后重试", 1600)
            return false
        }
        operation.Stage("KEYS_RELEASED")
        if commandName = "capture" {
            pulseHwnd := ResolveMxNMViewerCapturePulseHwnd(foregroundHwnd)
            ; Feedback discovery must not move the final foreground check away
            ; from the actual keyboard dispatch boundary.
            if WinExist("A") != foregroundHwnd {
                resultCode := "FOREGROUND_CHANGED"
                outcome := "CANCELLED"
                return false
            }
            operation.SetField("viewer.focusHwnd", MxNMViewerFocusedHwnd(foregroundHwnd))
            resultCode := "DISPATCH_FAILED"
            Send "{F12}"
            operation.SetField("viewer.dispatchResult", "DISPATCHED")
            operation.Stage("COMMAND_DISPATCHED")
            try ShowReportAssistantDispatchPulse(pulseHwnd ? pulseHwnd : foregroundHwnd)
        } else if commandName = "clear" {
            result := MxNMAnnotationCleaner.DeleteAll(
                0, 0, 0, MxNMAnnotationCleanupVerificationMode.COMMAND_ONLY
            )
            resultCode := result.code
            if !result.ok {
                Flash(MxNMViewerClearFailureMessage(result), 2200)
                return false
            }
            operation.SetField("viewer.dispatchResult", "DISPATCHED")
            operation.Stage("COMMAND_DISPATCHED")
        } else {
            operation.SetField("viewer.focusHwnd", MxNMViewerFocusedHwnd(foregroundHwnd))
            result := MxNMViewerToolCommandProvider.Invoke(commandName)
            resultCode := result.code
            operation.SetField("viewer.targetHwnd", result.buttonHwnd)
            operation.SetField("viewer.parentHwnd", result.buttonParentHwnd)
            operation.SetField("viewer.controlId", result.commandId)
            operation.SetField("viewer.candidateCount", result.runtimeCandidateCount)
            if !result.ok {
                if result.code = MxNMViewerToolCode.WRONG_FOREGROUND {
                    outcome := "CANCELLED"
                    return false
                }
                LogMxNMViewerToolFailure(commandName, result)
                Flash(MxNMViewerToolFailureMessage(result.code), 1600)
                return false
            }
            operation.SetField("viewer.dispatchResult", "DISPATCHED")
            operation.Stage("COMMAND_DISPATCHED")
        }
        resultCode := "DISPATCHED"
        outcome := "COMPLETED"
        return true
    } catch as viewerHotkeyError {
        if resultCode != "DISPATCH_FAILED"
            resultCode := "UNEXPECTED_ERROR"
        operation.SetField("viewer.errorType", Type(viewerHotkeyError))
        Flash("Viewer 快捷键执行失败，请复制诊断信息", 1600)
        return false
    } finally {
        active := false
        operation.Complete(outcome, resultCode)
    }
}

WaitMxNMViewerHotkeyRelease(chord, foregroundHwnd, timeoutMs := 3000) {
    startedAt := A_TickCount
    loop {
        state := MxNMViewerReleaseDecision(
            ViewerHotkeyChordHasPressedComponent(chord),
            WinExist("A") = foregroundHwnd,
            A_TickCount - startedAt,
            timeoutMs
        )
        if state != "WAITING"
            return state
        Sleep 10
    }
}

MxNMViewerReleaseDecision(pressed, foregroundMatches, elapsedMs, timeoutMs) {
    if !foregroundMatches
        return "FOREGROUND_CHANGED"
    if !pressed
        return "RELEASED"
    if elapsedMs >= timeoutMs
        return "KEY_RELEASE_TIMEOUT"
    return "WAITING"
}

MxNMViewerModifierState() {
    try {
        physical := 0
        logical := 0
        for index, key in ["Control", "Alt", "Shift", "LWin", "RWin"] {
            bit := 1 << (index - 1)
            if GetKeyState(key, "P")
                physical |= bit
            if GetKeyState(key)
                logical |= bit
        }
        return "p:" physical ",l:" logical
    } catch {
        return "UNAVAILABLE"
    }
}

MxNMViewerFocusedHwnd(foregroundHwnd) {
    try {
        threadId := DllCall("User32\GetWindowThreadProcessId", "Ptr", foregroundHwnd, "Ptr", 0, "UInt")
        guiInfo := Buffer(8 + 6 * A_PtrSize + 16, 0)
        NumPut("UInt", guiInfo.Size, guiInfo)
        if threadId && DllCall("User32\GetGUIThreadInfo", "UInt", threadId, "Ptr", guiInfo.Ptr, "Int")
            return NumGet(guiInfo, 8 + A_PtrSize, "Ptr")
    }
    return 0
}

ResolveMxNMViewerCapturePulseHwnd(viewerHwnd) {
    if !viewerHwnd
        return 0
    try viewerPid := WinGetPID("ahk_id " viewerHwnd)
    catch
        return viewerHwnd
    if !viewerPid
        return viewerHwnd
    try ownerHwnd := ResolveMxNMRootOwnerHwnd(viewerHwnd)
    catch
        ownerHwnd := 0
    if !ownerHwnd
        return viewerHwnd

    bestHwnd := viewerHwnd
    bestVisibleArea := MxNMViewerCapturePulseVisibleArea(viewerHwnd)
    try candidates := WinGetList("ahk_pid " viewerPid)
    catch
        candidates := []
    for candidateHwnd in candidates {
        try visible := DllCall(
            "User32\IsWindowVisible",
            "Ptr", candidateHwnd,
            "Int"
        ) != 0
        catch
            visible := false
        if !visible
            continue
        try candidateOwner := ResolveMxNMRootOwnerHwnd(candidateHwnd)
        catch
            candidateOwner := 0
        if candidateOwner != ownerHwnd
            continue
        visibleArea := MxNMViewerCapturePulseVisibleArea(candidateHwnd)
        if visibleArea > bestVisibleArea {
            bestHwnd := candidateHwnd
            bestVisibleArea := visibleArea
        }
    }
    return bestHwnd
}

MxNMViewerCapturePulseVisibleArea(hwnd) {
    if !hwnd
        return 0
    try WinGetPos(&x, &y, &width, &height, "ahk_id " hwnd)
    catch
        return 0
    if width <= 0 || height <= 0
        return 0
    virtualLeft := SysGet(76)
    virtualTop := SysGet(77)
    virtualRight := virtualLeft + SysGet(78)
    virtualBottom := virtualTop + SysGet(79)
    visibleWidth := Max(
        0,
        Min(x + width, virtualRight) - Max(x, virtualLeft)
    )
    visibleHeight := Max(
        0,
        Min(y + height, virtualBottom) - Max(y, virtualTop)
    )
    return visibleWidth * visibleHeight
}

InvokeMxNMViewerSuv3DHotkey(chord, *) {
    return RunMxNMViewerHotkey("suv3d", chord)
}

InvokeMxNMViewerClearHotkey(chord, *) {
    return RunMxNMViewerHotkey("clear", chord)
}

ViewerHotkeyChordHasPressedComponent(chord) {
    normalized := Trim(String(chord), " `t`r`n")
    if !RegExMatch(normalized, "^([!+^#]*)(.+)$", &match)
        throw ValueError("Invalid Viewer hotkey chord")
    if GetKeyState(match[2], "P")
        return true
    if InStr(match[1], "^")
        && GetKeyState("Control", "P")
        return true
    if InStr(match[1], "!")
        && GetKeyState("Alt", "P")
        return true
    if InStr(match[1], "+")
        && GetKeyState("Shift", "P")
        return true
    if InStr(match[1], "#")
        && (
            GetKeyState("LWin", "P")
            || GetKeyState("RWin", "P")
        ) {
        return true
    }
    return false
}


MxNMViewerClearFailureMessage(result) {
    code := result.code
    if code = MxNMAnnotationCleanupCode.TARGET_UNAVAILABLE
        return "未找到可清除的 Viewer 图像（"
            . MxNMViewerClearContextValue(
                result,
                "targetCode",
                "UNKNOWN"
            )
            . "/"
            . MxNMViewerClearContextValue(
                result,
                "targetConfigCode",
                "UNKNOWN"
            )
            . "/"
            . MxNMViewerClearContextValue(
                result,
                "targetSessionCacheHit",
                false
            )
            . "/"
            . MxNMViewerClearContextValue(
                result,
                "targetSessionGeneration",
                0
            )
            . "/"
            . MxNMViewerClearContextValue(
                result,
                "targetSessionCandidateCount",
                0
            )
            . "/"
            . MxNMViewerClearContextValue(
                result,
                "targetSessionPointProbeCount",
                0
            )
            . "）"
    if code = MxNMAnnotationCleanupCode.TARGET_CLIENT_POINT_INVALID
        return "Viewer 图像坐标转换失败，未执行清除"
    if code = MxNMAnnotationCleanupCode.TARGET_CHANGED
        return "Viewer 已变化，未执行清除"
    if code = MxNMAnnotationCleanupCode.COMMAND_FAILED
        return "Viewer 右键菜单命令失败（"
            . result.failureReason
            . "）"
    if code = MxNMAnnotationCleanupCode.CONFIRMATION_REQUIRED
        return "清除需要人工确认，未继续执行"
    if code = MxNMAnnotationCleanupCode.CLEANUP_NOT_VERIFIED
        return "已执行清除，但未能确认结果"
    return "Viewer 标注清除失败"
}

MxNMViewerClearContextValue(result, key, fallback := "") {
    if !IsObject(result)
        || !result.HasOwnProp("context")
        || Type(result.context) != "Map"
        || !result.context.Has(key) {
        return fallback
    }
    return result.context[key]
}

InvokeMxNMViewerToolHotkey(commandName, chord, *) {
    return RunMxNMViewerHotkey(commandName, chord)
}

LogMxNMViewerToolFailure(commandName, result) {
    WriteMxNMViewerFailureDiagnostic(
        "ViewerTool",
        result.code,
        Map(
            "stage", "TOOL_COMMAND",
            "commandName", commandName,
            "viewerPid", result.HasOwnProp("viewerPid")
                ? result.viewerPid
                : 0,
            "viewerHwnd", result.HasOwnProp("viewerHwnd")
                ? result.viewerHwnd
                : 0,
            "runtimeCandidateCount", result.HasOwnProp(
                "runtimeCandidateCount"
            ) ? result.runtimeCandidateCount : 0,
            "viewerProcessCount", result.HasOwnProp(
                "viewerProcessCount"
            ) ? result.viewerProcessCount : 0
        )
    )
}

MxNMViewerToolFailureMessage(code) {
    if code = MxNMViewerToolCode.COMMAND_SCHEMA_INVALID
        return "Viewer 工具配置已变化，快捷键未执行"
    if code = MxNMViewerToolCode.VIEWER_NOT_FOUND
        return "未找到 MedEx Viewer"
    if code = MxNMViewerToolCode.VIEWER_NOT_UNIQUE
        return "MedEx Viewer 窗口不唯一，快捷键未执行"
    if code = MxNMViewerToolCode.BUTTON_DISABLED
        return "Viewer 当前未启用该测量工具"
    if code = MxNMViewerToolCode.BUTTON_TARGET_INVALID
        || code = MxNMViewerToolCode.BUTTON_SET_NOT_UNIQUE
        || code = MxNMViewerToolCode.BUTTON_LAYOUT_INVALID {
        return "Viewer 工具按钮布局校验失败，未执行点击"
    }
    if code = MxNMViewerToolCode.BUSY
        return "Viewer 工具快捷键正在执行"
    return "Viewer 工具快捷键执行失败"
}
