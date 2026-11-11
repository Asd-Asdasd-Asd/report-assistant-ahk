; Cover workflow, field profile R2C3: bottom-right MIP -> report left,
; bottom-left coronal fusion -> reset slice -> report right.
; Reuses Montage transports, never its thickness/zoom/null-caption workflow.
MxNMCoverHotkeyDefinitions(settings) {
    return [HotkeyDefinition("viewer-cover", settings.coverChord,
        InvokeMxNMCoverHotkey.Bind(settings.coverChord, settings))]
}

InvokeMxNMCoverHotkey(chord, settings, *) {
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
                session.coverLayoutRow := settings.coverLayoutRow
                session.coverLayoutColumn := settings.coverLayoutColumn
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
    steps := ["PREFLIGHT", "SELECT_LAYOUT", "ANNOTATION_TAB", "CAPTION_DEFAULT",
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
        if step = "SELECT_LAYOUT" {
            point := MxNMMontageLayoutPoint(session.coverLayoutRow, session.coverLayoutColumn)
            result := MxNMMontageStaticClick(21112, "Static", point.xRatio, point.yRatio, 0, "", 0, session)
            if result.ok {
                session.coverLayoutDispatched := true
                Sleep MxNMMontageTiming.LayoutSettleMs
            }
            return result
        }
        if step = "ANNOTATION_TAB"
            return MxNMMontageStaticClick(21007, "Static", .479866, .5, 21155, "ComboBox", 0, session)
        if step = "CAPTION_DEFAULT"
            return MxNMMontageComboSelect(21155, "default", session)
        if step = "BIND_SURFACE" {
            surface := MxNMCoverResolveSurface(session)
            MxNMCoverLogSurface(session, surface)
            if surface.ok
                session.coverSurface := surface
            return surface
        }
        if !MxNMCoverSurfaceUnchanged(session)
            return {ok: false, code: "COVER_SURFACE_CHANGED"}
        if step = "SELECT_MIP" || step = "SELECT_FUSION"
            return MxNMCoverSelectPane(session, step = "SELECT_MIP" ? 4 : 3)
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
    if !MxNMCoverLayoutSupported(paths.layoutConfigPath, session.coverLayoutRow, session.coverLayoutColumn)
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
        || !MxNMCoverLayoutSupported(session.coverConfigPath, session.coverLayoutRow, session.coverLayoutColumn)
        return false
    for id, control in session.coverControls {
        resolved := MxNMMontageResolveControl(session, id, control.className)
        if !resolved.ok || resolved.hwnd != control.hwnd
            return false
    }
    return true
}

MxNMCoverLayoutSupported(path, row := 2, column := 3) {
    ; First-page row-major layout matrix. Default R2C3 maps to ShowModel7.
    ; Config confirms semantics, NOT the currently selected layout.
    ; The layout selection still uses the validated Montage physical transport.
    try {
        if !MxNMMontagePositiveInteger(row, 1, 5) || !MxNMMontagePositiveInteger(column, 1, 4)
            return false
        section := "ShowModel" ((row - 1) * 4 + column)
        if IniRead(path, section, "LowWndSize", "") != "4"
            || IniRead(path, section, "ShowModelPage", "") != "0"
            return false
        panes := []
        for index in [1, 2, 3, 4] {
            pane := Map()
            for key in ["Left", "Top", "Width", "Height", "ImageType", "ImageOrient", "ImageOrigin"] {
                value := IniRead(path, section, "LowWnd" key "_" index, "")
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
    rootRect := Win32WindowRect(session.viewerRootOwner)
    layoutRect := Win32WindowRect(session.coverControls[21112].hwnd)
    if !IsObject(rootRect) || !IsObject(layoutRect)
        || layoutRect.right <= layoutRect.left || layoutRect.bottom <= layoutRect.top
        return {ok: false, code: "COVER_ROOT_RECT_INVALID"}
    if !session.HasOwnProp("coverLayoutDispatched")
        return {ok: false, code: "COVER_LAYOUT_NOT_DISPATCHED"}

    identity := {pid: session.viewerPid, rootHwnd: session.viewerRootOwner}
    candidates := [], seen := Map()
    callback := CallbackCreate(CollectMxNMContextSurfaceCandidate.Bind(identity, rootRect, seen, candidates), "Fast", 2)
    try {
        for topHwnd in MxNMMontageOwnerFamilyWindows(session) {
            CollectMxNMContextSurfaceCandidate(identity, rootRect, seen, candidates, topHwnd)
            DllCall("User32\EnumChildWindows", "Ptr", topHwnd, "Ptr", callback, "Ptr", 0, "Int")
        }
    } finally CallbackFree(callback)
    for candidate in candidates
        candidate.parent := Win32ParentHwnd(candidate.hwnd)
    return MxNMCoverChooseSurface(candidates, rootRect, layoutRect, identity,
        MxNMCoverPanePointMatches.Bind(identity))
}

MxNMCoverChooseSurface(candidates, rootRect, layoutRect, identity, pointMatches) {
    groups := Map(), canvases := []
    dialogs := []
    frameCount := 0, imageSideCount := 0, gridCount := 0
    panelWidth := layoutRect.right - layoutRect.left
    panelHeight := layoutRect.bottom - layoutRect.top
    for candidate in candidates {
        if candidate.className = "#32770" && candidate.hwnd != identity.rootHwnd
            && dialogs.Length < 3 && candidate.width >= panelWidth {
            rect := candidate.rect
            dialogs.Push((rect.left - rootRect.left) "/" (rect.top - rootRect.top)
                "/" candidate.width "/" candidate.height)
        }
        if candidate.hwnd = identity.rootHwnd || !RectEncloses(rootRect, candidate.rect)
            continue
        frameCount += 1
        ; The live layout palette bounds the toolbar side. Size filters scale
        ; with that control and do not assume a maximized Viewer or a monitor.
        if candidate.rect.left < layoutRect.right
            || candidate.width * 2 < panelWidth || candidate.height * 2 < panelHeight
            || !MxNMCoverIsDrawingClass(candidate.className)
            continue
        imageSideCount += 1
        if candidate.className = "#32770" && MxNMCoverSpansImageArea(candidate.rect, layoutRect)
            canvases.Push(candidate)
        if candidate.parent {
            key := candidate.parent "|" candidate.className
            if !groups.Has(key)
                groups[key] := []
            groups[key].Push(candidate)
        }
    }

    layouts := [], sharedLayouts := []
    for _, siblings in groups {
        panes := MxNMCoverArrangePaneWindows(siblings)
        if !IsObject(panes)
            continue
        bounds := {left: panes[1].rect.left, top: panes[1].rect.top,
            right: panes[4].rect.right, bottom: panes[4].rect.bottom}
        if !MxNMCoverSpansImageArea(bounds, layoutRect)
            continue
        gridCount += 1
        if MxNMCoverAllPanePointsMatch(panes, pointMatches)
            layouts.Push({mode: "PANE_WINDOWS", panes: panes, hwnd: siblings[1].parent})
    }
    for canvas in canvases {
        panes := MxNMCoverSplitCanvas(canvas)
        if MxNMCoverAllPanePointsMatch(panes, pointMatches)
            sharedLayouts.Push({mode: "SHARED_CANVAS", panes: panes, hwnd: canvas.hwnd})
    }

    ; The same drawing area may expose both its canvas and its four children.
    ; Independent valid areas remain ambiguous even if one has richer metadata.
    for shared in sharedLayouts {
        if layouts.Length = 1 && layouts[1].mode = "PANE_WINDOWS"
            && MxNMCoverSameDrawingArea(layouts[1], shared)
            continue
        layouts.Push(shared)
    }
    summary := {
        ok: layouts.Length = 1,
        code: layouts.Length = 1 ? "COVER_SURFACE_READY"
            : layouts.Length > 1 ? "COVER_SURFACE_NOT_UNIQUE"
            : gridCount || canvases.Length ? "COVER_PANE_POINT_MISMATCH" : "COVER_SURFACE_NOT_FOUND",
        candidateCount: layouts.Length,
        geometry: "runtime=" candidates.Length ",frame=" frameCount ",imageSide=" imageSideCount
            ",grids=" gridCount ",canvas=" canvases.Length ",canvasHit=" sharedLayouts.Length
            ",root=" (rootRect.right - rootRect.left) "/" (rootRect.bottom - rootRect.top)
            ",panelRight=" (layoutRect.right - rootRect.left)
    }
    for dialog in dialogs
        summary.geometry .= ",dlg=" dialog
    if summary.ok {
        summary.mode := layouts[1].mode
        summary.hwnd := layouts[1].hwnd
        summary.panes := layouts[1].panes
    }
    return summary
}

MxNMCoverSpansImageArea(rect, layoutRect) {
    return rect.right - rect.left >= layoutRect.right - layoutRect.left
        && rect.bottom - rect.top >= (layoutRect.bottom - layoutRect.top) * 2
        && rect.top < layoutRect.bottom && rect.bottom > layoutRect.bottom
}

MxNMCoverIsDrawingClass(className) {
    return className != "" && className != "Static" && className != "ComboBox"
        && className != "Edit" && !MxNMContextClassLooksLikeToolChrome(className)
}

MxNMCoverArrangePaneWindows(siblings) {
    if siblings.Length != 4
        return 0
    bounds := siblings[1].rect.Clone()
    for sibling in siblings {
        rect := sibling.rect
        bounds.left := Min(bounds.left, rect.left)
        bounds.top := Min(bounds.top, rect.top)
        bounds.right := Max(bounds.right, rect.right)
        bounds.bottom := Max(bounds.bottom, rect.bottom)
    }
    cells := MxNMCoverSplitCanvas({rect: bounds, hwnd: 0})
    panes := [0, 0, 0, 0]
    for sibling in siblings {
        for index, cell in cells {
            if !MxNMCoverPaneRectMatches(sibling.rect, cell.rect)
                continue
            if IsObject(panes[index])
                return 0
            panes[index] := sibling
            break
        }
    }
    for pane in panes {
        if !IsObject(pane)
            return 0
    }
    return panes
}

MxNMCoverSplitCanvas(canvas) {
    rect := canvas.rect
    columns := [rect.left, (rect.left + rect.right) // 2, rect.right]
    rows := [rect.top, (rect.top + rect.bottom) // 2, rect.bottom]
    panes := []
    loop 2 {
        row := A_Index
        loop 2 {
            column := A_Index
            panes.Push({hwnd: canvas.hwnd, rect: {
                left: columns[column], right: columns[column + 1],
                top: rows[row], bottom: rows[row + 1]
            }})
        }
    }
    return panes
}

MxNMCoverPaneRectMatches(actual, cell) {
    ; Allow narrow pane borders and gutters in proportion to the cell.
    dx := Max(1, (cell.right - cell.left) * .03)
    dy := Max(1, (cell.bottom - cell.top) * .03)
    return Abs(actual.left - cell.left) <= dx && Abs(actual.right - cell.right) <= dx
        && Abs(actual.top - cell.top) <= dy && Abs(actual.bottom - cell.bottom) <= dy
}

MxNMCoverSameDrawingArea(grid, shared) {
    if grid.hwnd != shared.hwnd
        return false
    for index, pane in grid.panes {
        if !MxNMCoverPaneRectMatches(pane.rect, shared.panes[index].rect)
            return false
    }
    return true
}

MxNMCoverPaneCenter(pane) {
    rect := pane.rect
    return {x: (rect.left + rect.right) // 2, y: (rect.top + rect.bottom) // 2}
}

MxNMCoverAllPanePointsMatch(panes, pointMatches) {
    for pane in panes {
        if !pointMatches.Call(pane, MxNMCoverPaneCenter(pane))
            return false
    }
    return true
}

MxNMCoverPanePointMatches(identity, pane, point) {
    hit := Win32WindowFromPoint(point)
    if !hit || Win32WindowPid(hit) != identity.pid || Win32RootOwner(hit) != identity.rootHwnd
        || !Win32IsWindowEnabled(hit) || !RectHasPoint(pane.rect, point)
        return false
    if hit = pane.hwnd
        return true
    if !Win32IsChild(pane.hwnd, hit)
        return false
    hitRect := Win32ClientRectScreen(hit)
    paneRect := Win32ClientRectScreen(pane.hwnd)
    ; Accept a render child spanning the whole canvas or the expected cell.
    ; A small child overlay at the center cannot pass either geometry check.
    return IsObject(hitRect) && IsObject(paneRect)
        && (MxNMCoverPaneRectMatches(hitRect, pane.rect) || MxNMCoverPaneRectMatches(hitRect, paneRect))
        && MxNMCoverIsDrawingClass(Win32WindowClass(hit))
}

MxNMCoverLogSurface(session, surface) {
    if !session.HasOwnProp("operation") || !surface.HasOwnProp("candidateCount")
        return
    session.operation.SetField("viewer.candidateCount", surface.candidateCount)
    session.operation.SetField("cover.geometry", surface.geometry)
    if surface.ok
        session.operation.SetField("cover.surfaceMode", surface.mode)
}

MxNMCoverSurfaceUnchanged(session) {
    if !MxNMMontageViewerStillActive(session)
        return false
    current := MxNMCoverResolveSurface(session)
    bound := session.coverSurface
    if !current.ok || current.hwnd != bound.hwnd || current.mode != bound.mode {
        MxNMCoverLogSurface(session, current)
        return false
    }
    for index, pane in current.panes {
        prior := bound.panes[index]
        if pane.hwnd != prior.hwnd || RectKey(pane.rect) != RectKey(prior.rect)
            return false
    }
    return MxNMMontageViewerStillActive(session)
}

MxNMCoverSelectPane(session, index) {
    pane := session.coverSurface.panes[index]
    point := MxNMCoverPaneCenter(pane)
    identity := {pid: session.viewerPid, rootHwnd: session.viewerRootOwner}
    if !MxNMCoverSurfaceUnchanged(session) || !MxNMCoverPanePointMatches(identity, pane, point)
        || !MxNMMontageViewerStillActive(session)
        return {ok: false, code: "COVER_PANE_POINT_MISMATCH"}
    if !MxNMMontagePhysicalClick(point.x, point.y)
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
