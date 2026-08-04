; Montage layout controls for MedExNMFusion.  The physical-click transports
; below are the ones confirmed by the Windows field test (0.7).
class MxNMMontageDefaults {
    static Section := "MontageHotkeys"
    static EnabledKey := "Enabled"
    static LayoutRowKey := "LayoutRow"
    static LayoutColumnKey := "LayoutColumn"
    static BodyChordKey := "BodyChord"
    static HeadChordKey := "HeadChord"
    static LungChordKey := "LungChord"
    static EnabledDefault := "false"
    static LayoutRowDefault := "4"
    static LayoutColumnDefault := "4"
    static BodyChordDefault := "+!b"
    static HeadChordDefault := "+!h"
    static LungChordDefault := "+!l"

    static ManagedConfigDefaults() {
        defaults := [
            ManagedConfigEntry(this.Section, this.EnabledKey, this.EnabledDefault),
            ManagedConfigEntry(this.Section, this.LayoutRowKey, this.LayoutRowDefault),
            ManagedConfigEntry(this.Section, this.LayoutColumnKey, this.LayoutColumnDefault),
            ManagedConfigEntry(this.Section, this.BodyChordKey, this.BodyChordDefault),
            ManagedConfigEntry(this.Section, this.HeadChordKey, this.HeadChordDefault),
            ManagedConfigEntry(this.Section, this.LungChordKey, this.LungChordDefault)
        ]
        for profile in MxNMMontageProfileDefaults() {
            defaults.Push(ManagedConfigEntry(this.Section, profile.ThicknessKey, profile.Thickness))
            defaults.Push(ManagedConfigEntry(this.Section, profile.SliceKey, profile.Slice))
            defaults.Push(ManagedConfigEntry(this.Section, profile.ZoomKey, profile.Zoom))
        }
        return defaults
    }
}

class MxNMMontageTiming {
    ; The layout matrix exposes no selected-state signal. All other transitions
    ; use a control/value confirmation instead of a fixed inter-step delay.
    static LayoutSettleMs := 350
    static EditConfirmTimeoutMs := 300
    static EditConfirmPollMs := 20
    static ButtonSettleMs := 60
}

MxNMMontageProfileDefaults() {
    return [
        {Id: "body", Label: "Body", Preset: "default", ThicknessKey: "BodyThickness", Thickness: "8.5", SliceKey: "BodySlice", Slice: "8", ZoomKey: "BodyZoom", Zoom: "0.7"},
        {Id: "head", Label: "Head", Preset: "default", ThicknessKey: "HeadThickness", Thickness: "4", SliceKey: "HeadSlice", Slice: "11", ZoomKey: "HeadZoom", Zoom: "1.2"},
        {Id: "lung", Label: "Lung", Preset: "lung", ThicknessKey: "LungThickness", Thickness: "8", SliceKey: "LungSlice", Slice: "23", ZoomKey: "LungZoom", Zoom: "0.85"}
    ]
}

LoadMxNMMontageSettings(configPath := "") {
    settings := {ok: false, enabled: false, code: "CONFIG_UNAVAILABLE", layoutRow: 0, layoutColumn: 0, chords: Map(), profiles: Map()}
    if configPath = "" {
        try configPath := ReportAssistantConfig.Path()
        catch
            return settings
    }
    if !FileExist(configPath)
        return settings
    try {
        if IniRead(configPath, "Config", "SchemaVersion", "") != String(ReportAssistantConfigDefaults.SchemaVersion)
            return settings
        settings.enabled := ParseOptionalFeatureEnabled(IniRead(configPath, MxNMMontageDefaults.Section, MxNMMontageDefaults.EnabledKey, MxNMMontageDefaults.EnabledDefault))
        settings.layoutRow := MxNMMontagePositiveInteger(IniRead(configPath, MxNMMontageDefaults.Section, MxNMMontageDefaults.LayoutRowKey, MxNMMontageDefaults.LayoutRowDefault), 1, 5)
        settings.layoutColumn := MxNMMontagePositiveInteger(IniRead(configPath, MxNMMontageDefaults.Section, MxNMMontageDefaults.LayoutColumnKey, MxNMMontageDefaults.LayoutColumnDefault), 1, 4)
        settings.chords["body"] := NormalizeOptionalHotkeyChord(IniRead(configPath, MxNMMontageDefaults.Section, MxNMMontageDefaults.BodyChordKey, MxNMMontageDefaults.BodyChordDefault))
        settings.chords["head"] := NormalizeOptionalHotkeyChord(IniRead(configPath, MxNMMontageDefaults.Section, MxNMMontageDefaults.HeadChordKey, MxNMMontageDefaults.HeadChordDefault))
        settings.chords["lung"] := NormalizeOptionalHotkeyChord(IniRead(configPath, MxNMMontageDefaults.Section, MxNMMontageDefaults.LungChordKey, MxNMMontageDefaults.LungChordDefault))
        if !settings.layoutRow || !settings.layoutColumn {
            settings.code := "CONFIG_LAYOUT_INVALID"
            return settings
        }
        for definition in MxNMMontageProfileDefaults() {
            thickness := MxNMMontageDecimal(IniRead(configPath, MxNMMontageDefaults.Section, definition.ThicknessKey, definition.Thickness), 0.1, 100)
            slice := MxNMMontagePositiveInteger(IniRead(configPath, MxNMMontageDefaults.Section, definition.SliceKey, definition.Slice), 1, 9999)
            zoom := MxNMMontageDecimal(IniRead(configPath, MxNMMontageDefaults.Section, definition.ZoomKey, definition.Zoom), 0.1, 10)
            if thickness = "" || !slice || zoom = "" {
                settings.code := "CONFIG_PROFILE_INVALID"
                return settings
            }
            settings.profiles[definition.Id] := {label: definition.Label, preset: definition.Preset, thickness: thickness, slice: String(slice), zoom: zoom}
        }
    } catch {
        settings.code := "CONFIG_READ_FAILED"
        return settings
    }
    settings.ok := true
    settings.code := "READY"
    return settings
}

MxNMMontagePositiveInteger(value, minimum, maximum) {
    value := Trim(String(value), " `t`r`n")
    if !RegExMatch(value, "^\d+$")
        return 0
    numeric := Integer(value)
    return numeric >= minimum && numeric <= maximum ? numeric : 0
}

MxNMMontageDecimal(value, minimum, maximum) {
    value := Trim(String(value), " `t`r`n")
    if !RegExMatch(value, "^\d+(?:\.\d+)?$")
        return ""
    numeric := Number(value)
    return numeric >= minimum && numeric <= maximum ? String(numeric) : ""
}

ValidateMxNMMontageSettings(settings, featureSettings := 0) {
    if !IsObject(settings) || !settings.ok {
        return MakeViewerToolHotkeyValidation(
            false, "MontageConfig", "Montage Beta 配置无法读取。"
        )
    }
    if settings.layoutRow < 1 || settings.layoutRow > 5 {
        return MakeViewerToolHotkeyValidation(
            false, "MontageLayoutRow", "Montage 布局行数必须为 1–5。"
        )
    }
    if settings.layoutColumn < 1 || settings.layoutColumn > 4 {
        return MakeViewerToolHotkeyValidation(
            false, "MontageLayoutColumn", "Montage 布局列数必须为 1–4。"
        )
    }
    if !settings.enabled
        return MakeViewerToolHotkeyValidation(true)

    seen := BuildHotkeyChordSet(ReservedApplicationHotkeyChords())
    if IsObject(featureSettings) {
        for definition in [
            {enabled: featureSettings.ReportImageCaptionEnabled, chord: featureSettings.ReportImageCaptionChord},
            {enabled: featureSettings.ViewerArrowEnabled, chord: featureSettings.ViewerArrowChord},
            {enabled: featureSettings.ViewerLengthEnabled, chord: featureSettings.ViewerLengthChord},
            {enabled: featureSettings.ViewerSuv3DEnabled, chord: featureSettings.ViewerSuv3DChord},
            {enabled: featureSettings.ViewerCaptureEnabled, chord: featureSettings.ViewerCaptureChord},
            {enabled: featureSettings.ViewerClearEnabled, chord: featureSettings.ViewerClearChord}
        ] {
            if definition.enabled
                seen[NormalizeHotkeyChord(definition.chord)] := true
        }
    }
    for definition in [
        {id: "body", field: "MontageBodyChord", label: "Body 排版"},
        {id: "head", field: "MontageHeadChord", label: "Head 排版"},
        {id: "lung", field: "MontageLungChord", label: "Lung 排版"}
    ] {
        chord := NormalizeOptionalHotkeyChord(settings.chords[definition.id])
        if chord = "" || InStr(chord, Chr(13)) || InStr(chord, Chr(10))
            return MakeViewerToolHotkeyValidation(
                false, definition.field,
                "启用 Montage Beta 前必须设置“" definition.label "”快捷键。"
            )
        if !ViewerToolHotkeyChordIsSafe(chord)
            return MakeViewerToolHotkeyValidation(
                false, definition.field,
                "“" definition.label "”快捷键格式无效。"
            )
        chordKey := NormalizeHotkeyChord(chord)
        if seen.Has(chordKey)
            return MakeViewerToolHotkeyValidation(
                false, definition.field,
                "“" definition.label "”快捷键与其他功能重复。"
            )
        seen[chordKey] := true
    }
    return MakeViewerToolHotkeyValidation(true)
}

MxNMMontageSettingsMatch(expected, actual) {
    if !IsObject(expected) || !IsObject(actual)
        return false
    return expected.enabled = actual.enabled
        && expected.layoutRow = actual.layoutRow
        && expected.layoutColumn = actual.layoutColumn
        && expected.chords["body"] = actual.chords["body"]
        && expected.chords["head"] = actual.chords["head"]
        && expected.chords["lung"] = actual.chords["lung"]
}

MxNMMontageHotkeyDefinitions(settings) {
    return [
        HotkeyDefinition("montage-body", settings.chords["body"], InvokeMxNMMontageHotkey.Bind("body", settings.chords["body"], settings)),
        HotkeyDefinition("montage-head", settings.chords["head"], InvokeMxNMMontageHotkey.Bind("head", settings.chords["head"], settings)),
        HotkeyDefinition("montage-lung", settings.chords["lung"], InvokeMxNMMontageHotkey.Bind("lung", settings.chords["lung"], settings))
    ]
}

InvokeMxNMMontageHotkey(profileId, chord, settings, *) {
    static busy := false
    if busy || !settings.ok || !settings.profiles.Has(profileId)
        return
    busy := true
    try {
        viewerHwnd := WinExist("A")
        if !MxNMMontageWaitForHotkeyRelease(chord) {
            result := MxNMMontageResult(false, "HOTKEY_RELEASE_TIMEOUT")
        } else {
            result := MxNMMontageRun(profileId, settings, viewerHwnd)
        }
        if result.ok
            Flash(settings.profiles[profileId].label " montage 已完成", 1200)
        else
            Flash(MxNMMontageFailureMessage(result.code), 2200)
    } finally {
        busy := false
    }
}

MxNMMontageWaitForHotkeyRelease(chord) {
    deadline := A_TickCount + 2000
    while ViewerHotkeyChordHasPressedComponent(chord) {
        if A_TickCount >= deadline
            return false
        Sleep 10
    }
    return true
}

MxNMMontageRun(profileId, settings, viewerHwnd) {
    if !settings.profiles.Has(profileId)
        return MxNMMontageResult(false, "PROFILE_UNKNOWN")
    session := MxNMMontageCreateSession(viewerHwnd)
    if !session.ok
        return session
    profile := settings.profiles[profileId]
    layoutPoint := MxNMMontageLayoutPoint(
        settings.layoutRow,
        settings.layoutColumn
    )
    if !layoutPoint.ok
        return MxNMMontageResult(false, "LAYOUT_PROFILE_INVALID")
    steps := [
        MxNMMontageStaticClick.Bind(21112, "Static", layoutPoint.xRatio, layoutPoint.yRatio, 0, ""),
        MxNMMontageStaticClick.Bind(21007, "Static", .479866, .5, 21155, "ComboBox"),
        MxNMMontageComboSelect.Bind(21155, "null"),
        MxNMMontageStaticClick.Bind(21007, "Static", .869128, .5, 21014, "ComboBox"),
        MxNMMontageComboSelect.Bind(21014, profile.preset),
        MxNMMontageSetEdit.Bind(21012, profile.thickness),
        MxNMMontageInvokeButton.Bind(21015),
        MxNMMontageSetEdit.Bind(21201, profile.slice),
        MxNMMontageInvokeButton.Bind(21203),
        MxNMMontageStaticClick.Bind(21007, "Static", .681208, .5, 21032, "Edit"),
        MxNMMontageSetEdit.Bind(21032, profile.zoom),
        MxNMMontageCommitZoom
    ]
    for index, step in steps {
        if !MxNMMontageViewerStillActive(session)
            return MxNMMontageResult(false, "VIEWER_FOREGROUND_CHANGED")
        result := step.Call(session)
        if !result.ok
            return result
        if index = 1
            Sleep MxNMMontageTiming.LayoutSettleMs
    }
    return MxNMMontageResult(true, "READY")
}

MxNMMontageLayoutPoint(row, column) {
    if row < 1 || row > 5 || column < 1 || column > 4
        return {ok: false, xRatio: 0, yRatio: 0}
    ; Calibrated from the same control-local grid used by field test 0.7.
    ; R4C4 remains exactly 0.881579,0.771014.
    return {
        ok: true,
        xRatio: 0.131579 + (column - 1) * 0.25,
        yRatio: 0.171014 + (row - 1) * 0.20
    }
}

MxNMMontageCreateSession(viewerHwnd) {
    if !viewerHwnd
        return MxNMMontageResult(false, "VIEWER_NOT_FOUND")
    try processName := WinGetProcessName("ahk_id " viewerHwnd)
    catch
        return MxNMMontageResult(false, "VIEWER_PROCESS_UNAVAILABLE")
    if StrLower(processName) != "medexnmfusion.exe"
        return MxNMMontageResult(false, "VIEWER_NOT_MEDEX")
    try viewerPid := WinGetPID("ahk_id " viewerHwnd)
    catch
        return MxNMMontageResult(false, "VIEWER_PID_UNAVAILABLE")
    rootOwner := MxNMMontageRootOwner(viewerHwnd)
    return {ok: true, code: "READY", viewerHwnd: viewerHwnd, viewerPid: viewerPid, viewerRootOwner: rootOwner}
}

MxNMMontageStaticClick(controlId, className, xRatio, yRatio, effectId, effectClass, session) {
    resolved := MxNMMontageResolveControl(session, controlId, className)
    if !resolved.ok
        return resolved
    rect := resolved.rectObject
    width := rect.r - rect.l, height := rect.b - rect.t
    if width < 40 || height < 20
        return MxNMMontageResult(false, "CONTROL_RECT_TOO_SMALL")
    x := rect.l + Round(width * xRatio), y := rect.t + Round(height * yRatio)
    if MxNMMontageWindowFromPoint(x, y) != resolved.hwnd
        return MxNMMontageResult(false, "POINT_HWND_MISMATCH")
    if !MxNMMontagePhysicalClick(x, y)
        return MxNMMontageResult(false, "STATIC_PHYSICAL_CLICK_FAILED")
    if effectId {
        effect := MxNMMontageWaitForControl(session, effectId, effectClass, 1500)
        if !effect.ok
            return MxNMMontageResult(false, "STATIC_CLICK_NO_EFFECT")
    }
    return MxNMMontageResult(true, effectId ? "STATIC_CLICK_EFFECT_CONFIRMED" : "STATIC_CLICK_DISPATCHED")
}

MxNMMontageComboSelect(controlId, optionName, session) {
    resolved := MxNMMontageResolveControl(session, controlId, "ComboBox")
    if !resolved.ok
        return resolved
    try combo := UIA.ElementFromHandle(resolved.hwnd)
    catch
        return MxNMMontageResult(false, "COMBO_UIA_ELEMENT_FAILED")
    try {
        if combo.ProcessId != session.viewerPid || !combo.IsExpandCollapsePatternAvailable
            throw Error()
        combo.ExpandCollapsePattern.Expand()
    } catch {
        return MxNMMontageResult(false, "COMBO_EXPAND_FAILED")
    }
    deadline := A_TickCount + 1500
    loop {
        options := MxNMMontageCollectComboOptions(combo, optionName, session)
        if options.matches.Length = 1 || A_TickCount >= deadline
            break
        Sleep 20
    }
    if options.matches.Length != 1 {
        try combo.ExpandCollapsePattern.Collapse()
        return MxNMMontageResult(false, "COMBO_OPTION_NOT_UNIQUE")
    }
    option := options.matches[1]
    try optionRect := option.BoundingRectangle
    catch {
        try combo.ExpandCollapsePattern.Collapse()
        return MxNMMontageResult(false, "COMBO_OPTION_GEOMETRY_FAILED")
    }
    if !IsObject(optionRect) || optionRect.r - optionRect.l < 4 || optionRect.b - optionRect.t < 4 {
        try combo.ExpandCollapsePattern.Collapse()
        return MxNMMontageResult(false, "COMBO_OPTION_RECT_INVALID")
    }
    x := Round((optionRect.l + optionRect.r) / 2), y := Round((optionRect.t + optionRect.b) / 2)
    pointHwnd := MxNMMontageWindowFromPoint(x, y)
    try pointPid := WinGetPID("ahk_id " pointHwnd)
    catch {
        pointPid := 0
    }
    try pointClass := WinGetClass("ahk_id " pointHwnd)
    catch {
        pointClass := ""
    }
    if !pointHwnd || pointPid != session.viewerPid || StrLower(pointClass) != "combolbox" {
        try combo.ExpandCollapsePattern.Collapse()
        return MxNMMontageResult(false, "COMBO_OPTION_POINT_MISMATCH")
    }
    if !MxNMMontagePhysicalClick(x, y)
        return MxNMMontageResult(false, "COMBO_OPTION_PHYSICAL_CLICK_FAILED")
    Sleep 120
    try combo.ExpandCollapsePattern.Collapse()
    deadline := A_TickCount + 900
    loop {
        try currentValue := combo.ValuePattern.Value
        catch {
            currentValue := ""
        }
        if StrLower(Trim(currentValue, " `t`r`n")) = StrLower(optionName)
            return MxNMMontageResult(true, "COMBO_PHYSICAL_SELECTION_CONFIRMED")
        if A_TickCount >= deadline
            break
        Sleep 20
    }
    return MxNMMontageResult(false, "COMBO_VALUE_NOT_CONFIRMED")
}

MxNMMontageCollectComboOptions(combo, optionName, session) {
    result := {matches: []}
    try desktop := UIA.GetRootElement()
    catch
        return result
    try candidates := desktop.FindElements({Name: optionName, Type: "ListItem", cs: 0})
    catch
        return result
    for candidate in candidates {
        try {
            if candidate.ProcessId != session.viewerPid || !candidate.IsEnabled || candidate.IsOffscreen || !candidate.IsSelectionItemPatternAvailable
                continue
            if MxNMMontageOptionBelongsToCombo(candidate, combo)
                result.matches.Push(candidate)
        }
    }
    return result
}

MxNMMontageOptionBelongsToCombo(option, combo) {
    current := option
    loop 12 {
        try {
            if UIA.CompareElementsEx(current, combo)
                return true
        }
        try current := UIA.RawViewWalker.TryGetParentElement(current)
        catch
            return false
        if !IsObject(current)
            return false
    }
    return false
}

MxNMMontageSetEdit(controlId, value, session) {
    resolved := MxNMMontageResolveControl(session, controlId, "Edit")
    if !resolved.ok
        return resolved
    try element := UIA.ElementFromHandle(resolved.hwnd)
    catch
        return MxNMMontageResult(false, "EDIT_UIA_ELEMENT_FAILED")
    try {
        if element.ProcessId != session.viewerPid || !element.IsValuePatternAvailable
            throw Error()
        element.ValuePattern.SetValue(value)
        valueConfirmed := false
        deadline := A_TickCount + MxNMMontageTiming.EditConfirmTimeoutMs
        loop {
            if String(element.ValuePattern.Value) = value {
                valueConfirmed := true
                break
            }
            if A_TickCount >= deadline
                break
            Sleep MxNMMontageTiming.EditConfirmPollMs
        }
        if !valueConfirmed
            return MxNMMontageResult(false, "EDIT_VALUE_NOT_CONFIRMED")
    } catch {
        return MxNMMontageResult(false, "EDIT_SET_VALUE_FAILED")
    }
    return MxNMMontageResult(true, "EDIT_VALUE_CONFIRMED")
}

MxNMMontageInvokeButton(controlId, session) {
    resolved := MxNMMontageResolveControl(session, controlId, "Button")
    if !resolved.ok
        return resolved
    try element := UIA.ElementFromHandle(resolved.hwnd)
    catch
        return MxNMMontageResult(false, "BUTTON_UIA_ELEMENT_FAILED")
    try {
        if element.ProcessId != session.viewerPid || !element.IsInvokePatternAvailable
            throw Error()
        element.InvokePattern.Invoke()
    } catch
        return MxNMMontageResult(false, "BUTTON_INVOKE_FAILED")
    Sleep MxNMMontageTiming.ButtonSettleMs
    return MxNMMontageResult(true, "BUTTON_INVOKE_DISPATCHED")
}

MxNMMontageCommitZoom(session) {
    resolved := MxNMMontageResolveControl(session, 21032, "Edit")
    if !resolved.ok
        return resolved
    try element := UIA.ElementFromHandle(resolved.hwnd)
    catch
        return MxNMMontageResult(false, "ZOOM_UIA_ELEMENT_FAILED")
    try element.SetFocus()
    catch
        return MxNMMontageResult(false, "ZOOM_FOCUS_FAILED")
    try focused := UIA.GetFocusedElement()
    catch
        return MxNMMontageResult(false, "ZOOM_FOCUS_NOT_CONFIRMED")
    try matches := focused.ProcessId = session.viewerPid && String(focused.AutomationId) = "21032"
    catch {
        matches := false
    }
    if !matches || !MxNMMontageViewerStillActive(session)
        return MxNMMontageResult(false, "ZOOM_FOCUS_NOT_CONFIRMED")
    Send "{Enter}"
    return MxNMMontageResult(true, "ENTER_DISPATCHED")
}

MxNMMontageResolveControl(session, controlId, className) {
    win32 := []
    callback := CallbackCreate(MxNMMontageCollectNativeControl.Bind(session, controlId, className, win32), "Fast", 2)
    try DllCall("User32\EnumChildWindows", "Ptr", session.viewerRootOwner, "Ptr", callback, "Ptr", 0, "Int")
    finally CallbackFree(callback)
    uiaCandidates := MxNMMontageCollectUiaControls(
        session,
        controlId,
        className
    )
    candidatesByHwnd := Map()
    for candidate in win32
        candidatesByHwnd[candidate.hwnd] := candidate
    for candidate in uiaCandidates
        candidatesByHwnd[candidate.hwnd] := candidate
    candidates := []
    for _, candidate in candidatesByHwnd
        candidates.Push(candidate)
    if candidates.Length != 1
        return MxNMMontageResult(false, "CONTROL_NOT_UNIQUE")
    candidate := candidates[1]
    return {ok: true, code: "CONTROL_READY", hwnd: candidate.hwnd, rectObject: candidate.rect}
}

MxNMMontageCollectUiaControls(session, controlId, className) {
    candidates := []
    try root := UIA.ElementFromHandle(session.viewerRootOwner)
    catch
        return candidates
    try elements := root.FindElements({AutomationId: String(controlId)})
    catch
        return candidates
    viewerRect := MxNMMontageWindowRect(session.viewerRootOwner)
    if !IsObject(viewerRect)
        return candidates
    for element in elements {
        try {
            if element.ProcessId != session.viewerPid || StrLower(element.ClassName) != StrLower(className) || !element.IsEnabled || element.IsOffscreen
                continue
            hwnd := element.NativeWindowHandle
            if !hwnd || MxNMMontageRootOwner(hwnd) != session.viewerRootOwner
                continue
            rect := MxNMMontageWindowRect(hwnd)
            if !IsObject(rect) || !MxNMMontageRectInside(rect, viewerRect)
                continue
            candidates.Push({hwnd: hwnd, rect: rect})
        }
    }
    return candidates
}

MxNMMontageCollectNativeControl(session, controlId, className, candidates, hwnd, *) {
    if !hwnd
        return true
    try {
        if DllCall("User32\GetDlgCtrlID", "Ptr", hwnd, "Int") != controlId || StrLower(WinGetClass("ahk_id " hwnd)) != StrLower(className) || WinGetPID("ahk_id " hwnd) != session.viewerPid
            return true
        if !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int") || !DllCall("User32\IsWindowEnabled", "Ptr", hwnd, "Int") || MxNMMontageRootOwner(hwnd) != session.viewerRootOwner
            return true
        rect := MxNMMontageWindowRect(hwnd), viewerRect := MxNMMontageWindowRect(session.viewerRootOwner)
        if IsObject(rect) && IsObject(viewerRect) && MxNMMontageRectInside(rect, viewerRect)
            candidates.Push({hwnd: hwnd, rect: rect})
    }
    return true
}

MxNMMontageWaitForControl(session, controlId, className, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    loop {
        result := MxNMMontageResolveControl(session, controlId, className)
        if result.ok || A_TickCount >= deadline
            return result
        Sleep 50
    }
}

MxNMMontagePhysicalClick(x, y) {
    ; All resolved rectangles and WindowFromPoint checks use screen coordinates.
    ; CoordMode is per AHK thread, so the hotkey handler must set it itself.
    CoordMode "Mouse", "Screen"
    MouseGetPos &originalX, &originalY
    clicked := false, restored := false
    try {
        MouseClick "left", x, y, 1, 0
        clicked := true
    } finally {
        try {
            MouseMove originalX, originalY, 0
            restored := true
        }
    }
    return clicked && restored
}

MxNMMontageViewerStillActive(session) {
    foreground := WinExist("A")
    if !foreground
        return false
    try {
        return WinGetPID("ahk_id " foreground) = session.viewerPid && MxNMMontageRootOwner(foreground) = session.viewerRootOwner
    } catch
        return false
}

MxNMMontageWindowRect(hwnd) {
    try {
        WinGetPos &x, &y, &width, &height, "ahk_id " hwnd
        return {l: x, t: y, r: x + width, b: y + height}
    }
    return 0
}

MxNMMontageWindowFromPoint(x, y) {
    return DllCall("User32\WindowFromPoint", "Int64", y << 32 | (x & 0xFFFFFFFF), "Ptr")
}

MxNMMontageRootOwner(hwnd) {
    root := DllCall("User32\GetAncestor", "Ptr", hwnd, "UInt", 3, "Ptr")
    return root ? root : hwnd
}

MxNMMontageRectInside(inner, outer) {
    return inner.l >= outer.l && inner.t >= outer.t && inner.r <= outer.r && inner.b <= outer.b && inner.r > inner.l && inner.b > inner.t
}

MxNMMontageResult(ok, code) {
    return {ok: ok = true, code: code}
}

MxNMMontageFailureMessage(code) {
    messages := Map(
        "LAYOUT_PROFILE_INVALID", "Montage 布局行列无效；未执行。",
        "VIEWER_NOT_MEDEX", "请在 MedExNMFusion Viewer 前台执行 Montage。",
        "VIEWER_FOREGROUND_CHANGED", "Viewer 前台已变化，Montage 已停止。",
        "HOTKEY_RELEASE_TIMEOUT", "请松开 Montage 快捷键后重试。",
        "CONTROL_NOT_UNIQUE", "Viewer 控件未唯一识别，Montage 未继续。"
    )
    return messages.Has(code) ? messages[code] : "Montage 未完成：" code
}
