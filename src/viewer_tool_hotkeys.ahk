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
    static active := false
    if active
        return
    if !MedExViewerForegroundActive()
        return
    try viewerHwnd := WinExist("A")
    catch
        return
    if !viewerHwnd
        return
    active := true
    try {
        while ViewerHotkeyChordHasPressedComponent(chord)
            Sleep 10
        if WinExist("A") != viewerHwnd
            || !MedExViewerForegroundActive() {
            return
        }
        pulseHwnd := ResolveMxNMViewerCapturePulseHwnd(viewerHwnd)
        try Send "{F12}"
        catch {
            Flash("Viewer 截图快捷键执行失败", 1200)
            return
        }
        ShowReportAssistantDispatchPulse(
            pulseHwnd ? pulseHwnd : viewerHwnd
        )
    } finally {
        active := false
    }
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
    static active := false
    if active
        return
    try foregroundHwnd := WinExist("A")
    catch
        return
    if !foregroundHwnd
        return
    active := true
    try {
        while ViewerHotkeyChordHasPressedComponent(chord)
            Sleep 10
        if WinExist("A") != foregroundHwnd
            return
        result := MxNMViewerToolCommandProvider.Invoke("suv3d")
        if !result.ok {
            if result.code != MxNMViewerToolCode.WRONG_FOREGROUND {
                LogMxNMViewerToolFailure("suv3d", result)
                Flash(MxNMViewerToolFailureMessage(result.code), 1600)
            }
            return
        }
    } finally {
        active := false
    }
}

InvokeMxNMViewerClearHotkey(chord, *) {
    static active := false
    if active
        return
    try foregroundHwnd := WinExist("A")
    catch
        return
    if !foregroundHwnd
        return
    active := true
    try {
        while ViewerHotkeyChordHasPressedComponent(chord)
            Sleep 10
        if WinExist("A") != foregroundHwnd
            return
        result := MxNMAnnotationCleaner.DeleteAll(
            0,
            0,
            0,
            MxNMAnnotationCleanupVerificationMode.COMMAND_ONLY
        )
        if !result.ok
            Flash(MxNMViewerClearFailureMessage(result), 2200)
    } finally {
        active := false
    }
}

ViewerHotkeyChordHasPressedComponent(chord) {
    normalized := Trim(String(chord), " `t`r`n")
    if !RegExMatch(normalized, "^([!+^#]*)(.+)$", &match)
        return false
    try {
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
    } catch {
        return false
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
    static active := false
    if active
        return
    try foregroundHwnd := WinExist("A")
    catch
        return
    if !foregroundHwnd
        return
    active := true
    try {
        while ViewerHotkeyChordHasPressedComponent(chord)
            Sleep 10
        if WinExist("A") != foregroundHwnd
            return
        result := MxNMViewerToolCommandProvider.Invoke(commandName)
        if result.ok || result.code = MxNMViewerToolCode.WRONG_FOREGROUND
            return
        LogMxNMViewerToolFailure(commandName, result)
        Flash(MxNMViewerToolFailureMessage(result.code), 1600)
    } finally {
        active := false
    }
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
    if code = MxNMViewerToolCode.BUTTON_TARGET_INVALID
        || code = MxNMViewerToolCode.BUTTON_SET_NOT_UNIQUE
        || code = MxNMViewerToolCode.BUTTON_LAYOUT_INVALID {
        return "Viewer 工具按钮布局校验失败，未执行点击"
    }
    if code = MxNMViewerToolCode.BUSY
        return "Viewer 工具快捷键正在执行"
    return "Viewer 工具快捷键执行失败"
}
