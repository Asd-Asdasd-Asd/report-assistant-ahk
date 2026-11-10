; Cover workflow, field profile R2C3: bottom-right MIP -> report left,
; bottom-left coronal fusion -> reset slice -> report right.
; Reuses Montage transports, never its thickness/zoom/null-caption workflow.
MxNMCoverHotkeyDefinitions(settings) {
    return [HotkeyDefinition("viewer-cover", settings.coverChord,
        InvokeMxNMCoverHotkey.Bind(settings.coverChord))]
}

InvokeMxNMCoverHotkey(chord, *) {
    operation := BeginAutomationDiagnosticOperation("ViewerCover")
    operation.SetField("viewer.command", "cover")
    operation.SetField("viewer.effectState", "UNOBSERVABLE")
    if !MxNMViewerWorkflowLock.Acquire() {
        operation.Complete("CANCELLED", "BUSY")
        return
    }
    saved := false
    mouseSaved := false
    result := {ok: false, code: "UNEXPECTED_ERROR"}
    try {
        CoordMode "Mouse", "Screen"
        MouseGetPos &mouseX, &mouseY
        mouseSaved := true
        foreground := WinExist("A")
        operation.SetField("viewer.foregroundHwnd", foreground)
        release := WaitMxNMViewerHotkeyRelease(chord, foreground)
        if release != "RELEASED" {
            result := {ok: false, code: release}
        } else {
            session := MxNMMontageCreateSession(foreground)
            if !session.ok {
                result := session
            } else {
                ; Preserve even an incidental clipboard change made by Viewer.
                payload := ClipboardAll()
                saved := true
                session.operation := operation
                result := MxNMCoverRun(session)
            }
        }
    } catch as err {
        operation.SetField("viewer.errorType", Type(err))
        result := {ok: false, code: "UNEXPECTED_ERROR"}
    } finally {
        if saved {
            try A_Clipboard := payload
            catch
                result := {ok: false, code: "CLIPBOARD_RESTORE_FAILED"}
        }
        if mouseSaved {
            try MouseMove mouseX, mouseY, 0
            catch
                result := {ok: false, code: "MOUSE_RESTORE_FAILED"}
        }
        MxNMViewerWorkflowLock.Release()
        operation.Complete(result.ok ? "COMPLETED" : "FAILED", result.code)
    }
    if result.ok
        Flash("封面图左右保存指令已执行，请检查报告草稿。", 2400)
    else
        Flash("封面图已停止（" result.code "）。请先检查草稿，避免重复保存；可复制诊断信息。", 3500)
}

; Injectable transport lets Windows regressions exercise the actual stop/order
; decisions without clicking Viewer, saving reports, or touching clipboard.
MxNMCoverRun(session, transport := 0) {
    if !IsObject(transport)
        transport := MxNMCoverTransport()
    steps := ["PREFLIGHT", "LAYOUT_R2C3", "ANNOTATION_TAB", "CAPTION_DEFAULT",
        "BIND_SURFACE", "SELECT_MIP", "SAVE_LEFT", "SELECT_FUSION",
        "RESET_DEFAULT", "SAVE_RIGHT"]
    leftDispatched := false
    for step in steps {
        if session.HasOwnProp("operation")
            session.operation.Stage(step)
        result := transport.Execute(step, session)
        if !result.ok {
            result.stage := step
            result.leftSaveDispatched := leftDispatched
            return result
        }
        if step = "SAVE_LEFT"
            leftDispatched := true
    }
    return {ok: true, code: "SAVE_COMMANDS_DISPATCHED", leftSaveDispatched: true}
}

class MxNMCoverTransport {
    Execute(step, session) {
        if !MxNMMontageViewerStillActive(session)
            return {ok: false, code: "VIEWER_FOREGROUND_CHANGED"}
        if step = "PREFLIGHT"
            return MxNMCoverPreflight(session)
        if !MxNMCoverControlsUnchanged(session)
            return {ok: false, code: "COVER_CONTROLS_CHANGED"}
        if step = "LAYOUT_R2C3" {
            point := MxNMMontageLayoutPoint(2, 3)
            result := MxNMMontageStaticClick(21112, "Static", point.xRatio, point.yRatio, 0, "", 0, session)
            if result.ok
                Sleep MxNMMontageTiming.LayoutSettleMs
            return result
        }
        if step = "ANNOTATION_TAB"
            return MxNMMontageStaticClick(21007, "Static", .479866, .5, 21155, "ComboBox", 0, session)
        if step = "CAPTION_DEFAULT"
            return MxNMMontageComboSelect(21155, "default", session)
        if step = "BIND_SURFACE" {
            surface := MxNMCoverResolveSurface(session)
            if surface.ok
                session.coverSurface := surface
            return surface
        }
        if !MxNMCoverSurfaceUnchanged(session)
            return {ok: false, code: "COVER_SURFACE_CHANGED"}
        if step = "SELECT_MIP" || step = "SELECT_FUSION"
            return MxNMCoverSelectPane(session, step = "SELECT_MIP" ? .75 : .25)
        if step != "SAVE_LEFT" && step != "SAVE_RIGHT" && step != "RESET_DEFAULT"
            return {ok: false, code: "COVER_STEP_UNKNOWN"}
        controlId := step = "SAVE_LEFT" ? 21104 : step = "SAVE_RIGHT" ? 21105 : 21102
        result := MxNMCoverInvokeButton(controlId, session)
        if result.ok {
            ; No save-completion/slice-position signal was exposed in the probe.
            ; Bounded settle is field-testable; never label this persistence proof.
            Sleep step = "RESET_DEFAULT" ? 350 : 550
            if session.HasOwnProp("operation")
                session.operation.SetField("viewer.dispatchResult", step "_DISPATCHED")
        }
        return result
    }
}

MxNMCoverPreflight(session) {
    ; Bind config to this process, never newest-file/alternate-directory guessing.
    try processPath := WinGetProcessPath("ahk_id " session.viewerHwnd)
    catch
        return {ok: false, code: "VIEWER_PATH_UNAVAILABLE"}
    paths := ResolveMxNMConfigPathsFromProcessPath("MedExNMFusion.exe", processPath)
    if !paths.ok
        return {ok: false, code: "COVER_CONFIG_UNAVAILABLE"}
    if !MxNMCoverLayoutSupported(paths.layoutConfigPath)
        return {ok: false, code: "COVER_LAYOUT_UNSUPPORTED"}
    session.coverConfigPath := paths.layoutConfigPath
    session.coverControls := Map()
    for spec in [
        {id: 21112, className: "Static"}, {id: 21007, className: "Static"},
        {id: 21104, className: "Button"}, {id: 21102, className: "Button"},
        {id: 21105, className: "Button"}
    ] {
        resolved := MxNMMontageResolveControl(session, spec.id, spec.className)
        if !resolved.ok
            return {ok: false, code: "COVER_CONTROL_NOT_UNIQUE"}
        session.coverControls[spec.id] := {hwnd: resolved.hwnd, className: spec.className}
    }
    return {ok: true, code: "PREFLIGHT_READY"}
}

MxNMCoverControlsUnchanged(session) {
    if !MxNMMontageViewerStillActive(session)
        || !MxNMCoverLayoutSupported(session.coverConfigPath)
        return false
    for id, control in session.coverControls {
        resolved := MxNMMontageResolveControl(session, id, control.className)
        if !resolved.ok || resolved.hwnd != control.hwnd
            return false
    }
    return true
}

MxNMCoverLayoutSupported(path) {
    ; Explicitly supported layout schema. R2C3 maps to ShowModel7 in this
    ; profile. Config confirms semantics, NOT the currently selected layout.
    ; The layout selection still uses the validated Montage physical transport.
    try {
        if IniRead(path, "ShowModel7", "LowWndSize", "") != "4"
            || IniRead(path, "ShowModel7", "ShowModelPage", "") != "0"
            return false
        panes := []
        for index in [1, 2, 3, 4] {
            pane := Map()
            for key in ["Left", "Top", "Width", "Height", "ImageType", "ImageOrient", "ImageOrigin"] {
                value := IniRead(path, "ShowModel7", "LowWnd" key "_" index, "")
                if !RegExMatch(value, "^\d+$")
                    return false
                pane[key] := Integer(value)
            }
            panes.Push(pane)
        }
        return MxNMCoverFourPaneProfileMatches(panes)
    } catch {
        return false
    }
}

MxNMCoverFourPaneProfileMatches(panes) {
    if panes.Length != 4
        return false
    width := panes[1]["Width"], height := panes[1]["Height"]
    if width < 20 || height < 20
        return false
    for index, pane in panes {
        if pane["Left"] != (Mod(index - 1, 2) * width)
            || pane["Top"] != ((index > 2 ? 1 : 0) * height)
            || pane["Width"] != width || pane["Height"] != height
            || pane["ImageType"] != [1, 2, 3, 1][index]
            || pane["ImageOrient"] != 2
            || pane["ImageOrigin"] != (index = 4 ? 2 : 1)
            return false
    }
    return true
}

MxNMCoverResolveSurface(session) {
    rootRect := Win32ClientRectScreen(session.viewerRootOwner)
    if !IsObject(rootRect)
        return {ok: false, code: "COVER_ROOT_RECT_INVALID"}
    identity := {pid: session.viewerPid, rootHwnd: session.viewerRootOwner}
    candidates := [], seen := Map()
    callback := CallbackCreate(CollectMxNMContextSurfaceCandidate.Bind(identity, rootRect, seen, candidates), "Fast", 2)
    try {
        for topHwnd in MxNMMontageOwnerFamilyWindows(session) {
            CollectMxNMContextSurfaceCandidate(identity, rootRect, seen, candidates, topHwnd)
            DllCall("User32\EnumChildWindows", "Ptr", topHwnd, "Ptr", callback, "Ptr", 0, "Int")
        }
    } finally CallbackFree(callback)
    return MxNMCoverChooseSurface(candidates, rootRect, session.viewerRootOwner)
}

MxNMCoverChooseSurface(candidates, rootRect, rootHwnd) {
    matches := []
    for candidate in candidates {
        if candidate.hwnd = rootHwnd || candidate.className != "#32770"
            || candidate.width < (rootRect.right - rootRect.left) * .4
            || candidate.height < (rootRect.bottom - rootRect.top) * .65
            || !RectEncloses(rootRect, candidate.rect)
            continue
        matches.Push(candidate)
    }
    ; Do not rank or guess between large canvas candidates.
    if matches.Length != 1
        return {ok: false, code: "COVER_SURFACE_NOT_UNIQUE"}
    candidate := matches[1]
    return {ok: true, code: "COVER_SURFACE_READY", hwnd: candidate.hwnd, rect: candidate.rect}
}

MxNMCoverSurfaceUnchanged(session) {
    if !MxNMMontageViewerStillActive(session)
        return false
    current := MxNMCoverResolveSurface(session)
    bound := session.coverSurface
    if !current.ok || current.hwnd != bound.hwnd
        return false
    for edge in ["left", "top", "right", "bottom"] {
        if current.rect.%edge% != bound.rect.%edge%
            return false
    }
    return Win32WindowPid(bound.hwnd) = session.viewerPid
        && MxNMMontageRootOwner(bound.hwnd) = session.viewerRootOwner
}

MxNMCoverSelectPane(session, xRatio) {
    rect := session.coverSurface.rect
    x := rect.left + Round((rect.right - rect.left) * xRatio)
    y := rect.top + Round((rect.bottom - rect.top) * .75)
    if !MxNMCoverSurfaceUnchanged(session)
        || MxNMMontageWindowFromPoint(x, y) != session.coverSurface.hwnd
        return {ok: false, code: "COVER_PANE_POINT_MISMATCH"}
    ; Only one click; never retry an ambiguous selection.
    if !MxNMMontagePhysicalClick(x, y)
        return {ok: false, code: "COVER_PANE_CLICK_FAILED"}
    Sleep 100
    return {ok: true, code: "COVER_PANE_CLICK_DISPATCHED"}
}

MxNMCoverInvokeButton(controlId, session) {
    resolved := MxNMMontageResolveControl(session, controlId, "Button")
    if !resolved.ok || resolved.hwnd != session.coverControls[controlId].hwnd
        return {ok: false, code: "COVER_BUTTON_CHANGED"}
    try {
        element := UIA.ElementFromHandle(resolved.hwnd)
        if element.ProcessId != session.viewerPid || !element.IsEnabled
            || element.IsOffscreen || !element.IsInvokePatternAvailable
            return {ok: false, code: "COVER_BUTTON_NOT_READY"}
        ; UIA may yield. Recheck at the dispatch boundary, with no replay.
        if !MxNMCoverControlsUnchanged(session) || !MxNMCoverSurfaceUnchanged(session)
            return {ok: false, code: "COVER_TARGET_CHANGED"}
        element.InvokePattern.Invoke()
        return {ok: true, code: "COVER_BUTTON_INVOKED"}
    } catch {
        return {ok: false, code: "COVER_BUTTON_INVOKE_FAILED"}
    }
}
