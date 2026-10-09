; Generated regression. Uses synthetic windows only; does not operate MedEx.

#Requires AutoHotkey v2.0

#SingleInstance Force

#Warn

; Exception-safe wrappers around User32 window queries plus small rectangle
; helpers. Modules that need a window's PID, root owner, class name or screen
; rectangle call these instead of repeating DllCall boilerplate.
;
; Conventions:
; - Every Win32* query returns 0 / "" / false on failure and never throws.
; - Win32* rectangles are {left, top, right, bottom} in screen coordinates.
;   RectLTRB() converts to the short {l, t, r, b} form that some modules keep;
;   the Rect* predicates accept both forms and Map("l", ...) rects.
; - Point containment is half-open: left/top inclusive, right/bottom exclusive.

class Win32Ancestor {
    static ROOT := 2
    static ROOT_OWNER := 3
}

Win32ForegroundHwnd() {
    try return WinExist("A")
    catch
        return 0
}

Win32ForegroundProcessName() {
    return Win32WindowProcessName(Win32ForegroundHwnd())
}

; True when the foreground window belongs to one of the given executables
; (a name or an array of names, compared case-insensitively).
Win32ForegroundProcessIs(processNames) {
    processName := StrLower(Win32ForegroundProcessName())
    if processName = ""
        return false
    if Type(processNames) != "Array"
        processNames := [processNames]
    for candidate in processNames {
        if processName = StrLower(String(candidate))
            return true
    }
    return false
}

Win32WindowProcessName(hwnd) {
    if !hwnd
        return ""
    try return WinGetProcessName("ahk_id " hwnd)
    catch
        return ""
}

Win32WindowPid(hwnd) {
    if !hwnd
        return 0
    pid := 0
    try DllCall(
        "User32\GetWindowThreadProcessId",
        "Ptr", hwnd,
        "UInt*", &pid,
        "UInt"
    )
    catch
        return 0
    return pid
}

Win32WindowFromPoint(point) {
    if !IsObject(point)
        return 0
    packedPoint := ((Round(point.y) & 0xFFFFFFFF) << 32)
        | (Round(point.x) & 0xFFFFFFFF)
    try return DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch
        return 0
}

Win32RootOwner(hwnd) {
    return Win32Ancestor_(hwnd, Win32Ancestor.ROOT_OWNER)
}

Win32RootWindow(hwnd) {
    return Win32Ancestor_(hwnd, Win32Ancestor.ROOT)
}

Win32Ancestor_(hwnd, flag) {
    if !hwnd
        return 0
    try return DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", flag,
        "Ptr"
    )
    catch
        return 0
}

Win32RootOwnerFromPoint(point) {
    pointHwnd := Win32WindowFromPoint(point)
    return pointHwnd ? Win32RootOwner(pointHwnd) : 0
}

Win32ParentHwnd(hwnd) {
    if !hwnd
        return 0
    try return DllCall(
        "User32\GetParent",
        "Ptr", hwnd,
        "Ptr"
    )
    catch
        return 0
}

Win32WindowClass(hwnd) {
    if !hwnd
        return ""
    classNameBuffer := Buffer(512 * 2, 0)
    try length := DllCall(
        "User32\GetClassNameW",
        "Ptr", hwnd,
        "Ptr", classNameBuffer.Ptr,
        "Int", 512,
        "Int"
    )
    catch
        return ""
    return length > 0
        ? StrGet(classNameBuffer, length, "UTF-16")
        : ""
}

Win32IsWindow(hwnd) {
    if !hwnd
        return false
    try return DllCall("User32\IsWindow", "Ptr", hwnd, "Int") != 0
    catch
        return false
}

Win32IsWindowVisible(hwnd) {
    if !hwnd
        return false
    try return DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int") != 0
    catch
        return false
}

Win32IsWindowEnabled(hwnd) {
    if !hwnd
        return false
    try return DllCall("User32\IsWindowEnabled", "Ptr", hwnd, "Int") != 0
    catch
        return false
}

Win32IsChild(parentHwnd, hwnd) {
    if !parentHwnd || !hwnd
        return false
    try return DllCall(
        "User32\IsChild",
        "Ptr", parentHwnd,
        "Ptr", hwnd,
        "Int"
    ) != 0
    catch
        return false
}

Win32WindowRect(hwnd) {
    if !hwnd
        return 0
    rectBuffer := Buffer(16, 0)
    try ok := DllCall(
        "User32\GetWindowRect",
        "Ptr", hwnd,
        "Ptr", rectBuffer.Ptr,
        "Int"
    )
    catch
        return 0
    if !ok
        return 0
    return {
        left: NumGet(rectBuffer, 0, "Int"),
        top: NumGet(rectBuffer, 4, "Int"),
        right: NumGet(rectBuffer, 8, "Int"),
        bottom: NumGet(rectBuffer, 12, "Int")
    }
}

Win32ClientRectScreen(hwnd) {
    if !hwnd
        return 0
    rectBuffer := Buffer(16, 0)
    topLeft := Buffer(8, 0)
    bottomRight := Buffer(8, 0)
    try {
        if !DllCall(
            "User32\GetClientRect",
            "Ptr", hwnd,
            "Ptr", rectBuffer.Ptr,
            "Int"
        ) {
            return 0
        }
        NumPut("Int", NumGet(rectBuffer, 0, "Int"), topLeft, 0)
        NumPut("Int", NumGet(rectBuffer, 4, "Int"), topLeft, 4)
        NumPut("Int", NumGet(rectBuffer, 8, "Int"), bottomRight, 0)
        NumPut("Int", NumGet(rectBuffer, 12, "Int"), bottomRight, 4)
        if !DllCall(
            "User32\ClientToScreen",
            "Ptr", hwnd,
            "Ptr", topLeft.Ptr,
            "Int"
        ) {
            return 0
        }
        if !DllCall(
            "User32\ClientToScreen",
            "Ptr", hwnd,
            "Ptr", bottomRight.Ptr,
            "Int"
        ) {
            return 0
        }
    } catch {
        return 0
    }
    return {
        left: NumGet(topLeft, 0, "Int"),
        top: NumGet(topLeft, 4, "Int"),
        right: NumGet(bottomRight, 0, "Int"),
        bottom: NumGet(bottomRight, 4, "Int")
    }
}

Win32ScreenToClient(hwnd, screenPoint) {
    if !hwnd || !IsObject(screenPoint)
        return 0
    pointBuffer := Buffer(8, 0)
    NumPut("Int", screenPoint.x, pointBuffer, 0)
    NumPut("Int", screenPoint.y, pointBuffer, 4)
    try ok := DllCall(
        "User32\ScreenToClient",
        "Ptr", hwnd,
        "Ptr", pointBuffer.Ptr,
        "Int"
    )
    catch
        return 0
    if !ok
        return 0
    return {
        x: NumGet(pointBuffer, 0, "Int"),
        y: NumGet(pointBuffer, 4, "Int")
    }
}

Win32WindowIsSameOrDescendant(hwnd, ancestorHwnd) {
    if !hwnd || !ancestorHwnd
        return false
    seen := Map()
    while hwnd && !seen.Has(hwnd) {
        if hwnd = ancestorHwnd
            return true
        seen[hwnd] := true
        hwnd := Win32ParentHwnd(hwnd)
    }
    return false
}

; Parent-chain distance from hwnd up to rootHwnd; 32 when unreachable.
Win32WindowDepth(hwnd, rootHwnd) {
    if hwnd = rootHwnd
        return 0
    depth := 0
    seen := Map()
    while hwnd && !seen.Has(hwnd) && depth < 32 {
        seen[hwnd] := true
        hwnd := Win32ParentHwnd(hwnd)
        depth += 1
        if hwnd = rootHwnd
            return depth
    }
    return 32
}

Win32VirtualScreenRect() {
    left := SysGet(76)
    top := SysGet(77)
    width := SysGet(78)
    height := SysGet(79)
    return {
        left: left,
        top: top,
        right: left + width,
        bottom: top + height,
        width: width,
        height: height
    }
}

PointInsideVirtualScreen(point) {
    if !IsObject(point)
        return false
    screen := Win32VirtualScreenRect()
    return screen.width > 0
        && screen.height > 0
        && point.x >= screen.left
        && point.x < screen.right
        && point.y >= screen.top
        && point.y < screen.bottom
}

; Normalise any supported rect form to {left, top, right, bottom}; 0 otherwise.
RectEdges(rect) {
    if !IsObject(rect)
        return 0
    if Type(rect) = "Map" {
        if !rect.Has("l")
            return 0
        return {
            left: rect["l"],
            top: rect["t"],
            right: rect["r"],
            bottom: rect["b"]
        }
    }
    if rect.HasOwnProp("left")
        return rect
    if rect.HasOwnProp("l")
        return {left: rect.l, top: rect.t, right: rect.r, bottom: rect.b}
    return 0
}

RectLTRB(rect) {
    edges := RectEdges(rect)
    if !IsObject(edges)
        return 0
    return {l: edges.left, t: edges.top, r: edges.right, b: edges.bottom}
}

RectIsEmpty(rect) {
    edges := RectEdges(rect)
    return !IsObject(edges)
        || edges.right <= edges.left
        || edges.bottom <= edges.top
}

RectKey(rect) {
    edges := RectEdges(rect)
    return IsObject(edges)
        ? edges.left "," edges.top "," edges.right "," edges.bottom
        : ""
}

RectHasPoint(rect, point) {
    edges := RectEdges(rect)
    return IsObject(edges)
        && IsObject(point)
        && point.x >= edges.left
        && point.x < edges.right
        && point.y >= edges.top
        && point.y < edges.bottom
}

; True when inner is non-empty and lies entirely inside outer.
RectEncloses(outer, inner) {
    outerEdges := RectEdges(outer)
    innerEdges := RectEdges(inner)
    return IsObject(outerEdges)
        && IsObject(innerEdges)
        && innerEdges.right > innerEdges.left
        && innerEdges.bottom > innerEdges.top
        && innerEdges.left >= outerEdges.left
        && innerEdges.top >= outerEdges.top
        && innerEdges.right <= outerEdges.right
        && innerEdges.bottom <= outerEdges.bottom
}

RectVisibleScreenArea(rect) {
    edges := RectEdges(rect)
    if !IsObject(edges)
        return 0
    screen := Win32VirtualScreenRect()
    width := Max(0, Min(edges.right, screen.right) - Max(edges.left, screen.left))
    height := Max(0, Min(edges.bottom, screen.bottom) - Max(edges.top, screen.top))
    return width * height
}

RectIntersectsScreen(rect) {
    edges := RectEdges(rect)
    if !IsObject(edges) || edges.right <= edges.left || edges.bottom <= edges.top
        return false
    screen := Win32VirtualScreenRect()
    return Min(edges.right, screen.right) > Max(edges.left, screen.left)
        && Min(edges.bottom, screen.bottom) > Max(edges.top, screen.top)
}


class ReportImageCaptionDefaults {
    static CopyTimeoutSeconds := 1
    static ClipboardSettleSeconds := 0.5
    static TargetActivationTimeoutSeconds := 1
    static TargetReadyTimeoutMs := 1500
    static TargetReadyPollMs := 40
    static CaptionFocusSettleMs := 15
    static PasteSettleMs := 20
    ; The first paste into a newly observed renderer can be visible before its
    ; backing editor state accepts the change. Gate only that cold boundary.
    static FirstTargetSessionPasteSettleMs := 500
    static ExplicitSaveSettleMs := 200
    ; WheelDown has a vendor-side conditional save path that is skipped when
    ; advances are too close together. Only wait for the missing remainder.
    static InterAdvanceSaveGateMs := 550
    ; A newly captured caption gets one conservative save window. The later
    ; cached reuse path keeps the field-validated 200 ms cadence.
    static CaptureSaveFallbackSettleMs := 550
    static MinCaptionGapPx := 120
    static MinCaptionPaneHeightPx := 40
    static MinCaptionPaneWidthRatio := 0.4
    static MinImageRegionHeightRatio := 0.5
}



class ReportImageCaptionPasteGate {
    static ReadyTargetKey := ""

    static Plan(target) {
        firstPaste := this.ReadyTargetKey != this.TargetKey(target)
        return {
            path: firstPaste ? "FIRST_TARGET_SESSION_GATE" : "STANDARD",
            milliseconds: firstPaste
                ? ReportImageCaptionDefaults.FirstTargetSessionPasteSettleMs
                : ReportImageCaptionDefaults.PasteSettleMs
        }
    }

    static ObserveSave(target) {
        this.ReadyTargetKey := this.TargetKey(target)
    }

    static TargetKey(target) {
        return String(target.pid) ":" String(target.hwnd)
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



FindRecentColorResetFailureEvent(lines) {
    Loop lines.Length {
        line := lines[lines.Length - A_Index + 1]
        if ColorResetDiagnosticLineField(line, "action") != "MedExColorReset"
            continue
        timestamp := ColorResetDiagnosticLineField(line, "timestamp")
        if timestamp = ""
            continue
        summary := "action=MedExColorReset"
        ; The legacy log uses spaces, not pipes. Copy only useful metadata,
        ; never the raw legacy line or unrelated historical failures.
        for field in ["timestamp", "resultCode", "preflightStage",
            "readinessReason", "readinessElapsedMs", "anchorRootMaxMs", "anchorQueryMaxMs", "exactAnchorQueryCount",
            "exactAnchorCandidateCount", "foregroundGuardReason"] {
            value := ColorResetDiagnosticLineField(line, field)
            if value != "" && value != "UNKNOWN"
                summary .= "|" field "=" AutomationDiagnosticSafeValue(value)
        }
        return {
            action: "MedExColorReset",
            timestamp: timestamp,
            source: "COLOR_RESET_FAILURE",
            summary: summary
        }
    }
    return {action: "NONE", timestamp: "", source: "NONE", summary: ""}
}

ColorResetDiagnosticLineField(line, fieldName) {
    if RegExMatch(line, "(?:^|\s)" fieldName "=([^\s]*)", &match)
        return match[1]
    return ""
}

NewerAutomationDiagnosticEvent(automationEvent, viewerEvent) {
    if viewerEvent.timestamp != ""
        && (automationEvent.timestamp = ""
            || StrCompare(
                viewerEvent.timestamp,
                automationEvent.timestamp
            ) > 0) {
        return viewerEvent
    }
    return automationEvent
}



AutomationDiagnosticSafeValue(value) {
    text := String(value)
    text := StrReplace(text, "`r", " ")
    text := StrReplace(text, "`n", " ")
    text := StrReplace(text, "|", "/")
    if StrLen(text) > 160
        text := SubStr(text, 1, 160)
    return text
}

JoinAutomationDiagnosticFields(fields) {
    output := ""
    for field in fields
        output .= (output = "" ? "" : "|") field
    return output
}



class MxNMViewerToolCommand {
    static Arrow := 21043
    static Length := 21048
    static Suv3D := 21193
    ; Checkpoint 1 legacy mapping evidence only. Production target resolution
    ; no longer depends on these values.
    static BuiltInRowCount := 3
    static ButtonCenterX := 17
    static ButtonCenterY := 17
    static ButtonPitch := 38
    static NativeClassName := "Button"
    static PanelOriginToleranceRatio := 0.01
    static PanelOriginToleranceMinPx := 4
    static PanelOriginToleranceMaxPx := 16

    static Specs() {
        return [
            {id: "arrow", label: "箭头", commandId: this.Arrow},
            {id: "length", label: "长度测量", commandId: this.Length},
            {id: "suv3d", label: "3D SUV测量", commandId: this.Suv3D}
        ]
    }
}

class MxNMViewerToolCode {
    static READY := "READY"
    static CONFIG_UNAVAILABLE := "CONFIG_UNAVAILABLE"
    static COMMAND_SCHEMA_INVALID := "COMMAND_SCHEMA_INVALID"
    static VIEWER_NOT_FOUND := "VIEWER_NOT_FOUND"
    static VIEWER_NOT_UNIQUE := "VIEWER_NOT_UNIQUE"
    static WRONG_FOREGROUND := "WRONG_FOREGROUND"
    static COMMAND_UNKNOWN := "COMMAND_UNKNOWN"
    static BUTTON_TARGET_INVALID := "BUTTON_TARGET_INVALID"
    static BUTTON_DISABLED := "BUTTON_DISABLED"
    static BUTTON_SET_NOT_UNIQUE := "BUTTON_SET_NOT_UNIQUE"
    static BUTTON_LAYOUT_INVALID := "BUTTON_LAYOUT_INVALID"
    static DISPATCH_FAILED := "DISPATCH_FAILED"
    static BUSY := "BUSY"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}



ResolveMxNMViewerToolControlSet(plan, viewerWindows) {
    failure := {
        ok: false,
        code: MxNMViewerToolCode.BUTTON_SET_NOT_UNIQUE,
        pid: 0,
        processCount: 0,
        frameHwnd: 0,
        actionRootHwnd: 0,
        panelHwnd: 0,
        candidateCount: 0,
        controls: Map()
    }
    if !IsObject(plan)
        || viewerWindows.Length = 0 {
        return failure
    }
    processResult := ResolveMxNMViewerToolProcess(
        viewerWindows
    )
    if !processResult.ok {
        failure.code := processResult.code
        failure.processCount := processResult.processCount
        return failure
    }
    runtimePid := processResult.pid
    failure.pid := runtimePid
    failure.processCount := processResult.processCount

    commandKeyById := Map()
    for commandKey, command in plan.commands
        commandKeyById[command.commandId] := commandKey
    candidates := EnumerateMxNMViewerToolControlCandidates(
        viewerWindows,
        runtimePid,
        commandKeyById
    )
    failure.candidateCount := candidates.Length
    if candidates.Length = 0
        return failure

    groups := Map()
    for candidate in candidates {
        if !groups.Has(candidate.parentHwnd) {
            groups[candidate.parentHwnd] := {
                parentHwnd: candidate.parentHwnd,
                parentRect: candidate.parentRect,
                controls: Map()
            }
        }
        group := groups[candidate.parentHwnd]
        if !group.controls.Has(candidate.commandKey)
            group.controls[candidate.commandKey] := []
        group.controls[candidate.commandKey].Push(candidate)
    }

    validGroups := []
    for _, group in groups {
        controls := Map()
        complete := true
        for commandKey, _ in plan.commands {
            if !group.controls.Has(commandKey)
                || group.controls[commandKey].Length != 1 {
                complete := false
                break
            }
            controls[commandKey] :=
                group.controls[commandKey][1]
        }
        if !complete
            continue
        if !ValidateMxNMViewerToolControlLayout(
            plan.commands,
            controls,
            group.parentRect
        ) {
            continue
        }
        actionRootHwnd := 0
        rootsMatch := true
        for _, control in controls {
            if !actionRootHwnd
                actionRootHwnd := control.rootHwnd
            else if control.rootHwnd != actionRootHwnd {
                rootsMatch := false
                break
            }
        }
        if !rootsMatch || !actionRootHwnd
            continue
        validGroups.Push({
            frameHwnd: Win32RootOwner(
                group.parentHwnd
            ),
            actionRootHwnd: actionRootHwnd,
            panelHwnd: group.parentHwnd,
            controls: controls
        })
    }
    if validGroups.Length != 1 {
        failure.code := validGroups.Length = 0
            ? MxNMViewerToolCode.BUTTON_LAYOUT_INVALID
            : MxNMViewerToolCode.BUTTON_SET_NOT_UNIQUE
        return failure
    }
    return {
        ok: true,
        code: MxNMViewerToolCode.READY,
        pid: runtimePid,
        processCount: processResult.processCount,
        frameHwnd: validGroups[1].frameHwnd,
        actionRootHwnd: validGroups[1].actionRootHwnd,
        panelHwnd: validGroups[1].panelHwnd,
        candidateCount: candidates.Length,
        controls: validGroups[1].controls
    }
}

ResolveMxNMViewerToolProcess(viewerWindows) {
    pids := Map()
    for viewerWindow in viewerWindows {
        try pid := WinGetPID("ahk_id " viewerWindow.hwnd)
        catch
            pid := 0
        if pid
            pids[pid] := true
    }
    if pids.Count != 1 {
        return {
            ok: false,
            code: pids.Count = 0
                ? MxNMViewerToolCode.VIEWER_NOT_FOUND
                : MxNMViewerToolCode.VIEWER_NOT_UNIQUE,
            pid: 0,
            processCount: pids.Count
        }
    }
    for pid, _ in pids {
        return {
            ok: true,
            code: MxNMViewerToolCode.READY,
            pid: pid,
            processCount: pids.Count
        }
    }
}

FindMxNMViewerToolWindowGeometry(viewerWindows, hwnd) {
    if !hwnd
        return 0
    for viewerWindow in viewerWindows {
        if viewerWindow.hwnd = hwnd
            return viewerWindow
    }
    return 0
}

EnumerateMxNMViewerToolControlCandidates(
    viewerWindows,
    runtimePid,
    commandKeyById
) {
    candidates := []
    seen := Map()
    for viewerWindow in viewerWindows {
        CollectMxNMViewerToolControlCandidate(
            runtimePid,
            commandKeyById,
            seen,
            candidates,
            viewerWindow.hwnd,
            0
        )
        callback := CallbackCreate(
            CollectMxNMViewerToolControlCandidate.Bind(
                runtimePid,
                commandKeyById,
                seen,
                candidates
            ),
            "Fast",
            2
        )
        try DllCall(
            "User32\EnumChildWindows",
            "Ptr", viewerWindow.hwnd,
            "Ptr", callback,
            "Ptr", 0,
            "Int"
        )
        finally CallbackFree(callback)
    }
    return candidates
}

CollectMxNMViewerToolControlCandidate(
    runtimePid,
    commandKeyById,
    seen,
    candidates,
    hwnd,
    *
) {
    if !hwnd || seen.Has(hwnd)
        return true
    seen[hwnd] := true
    try controlId := DllCall(
        "User32\GetDlgCtrlID",
        "Ptr", hwnd,
        "Int"
    )
    catch
        return true
    if !commandKeyById.Has(controlId)
        return true
    if !Win32IsWindowVisible(hwnd)
        return true
    try candidatePid := WinGetPID("ahk_id " hwnd)
    catch
        candidatePid := 0
    if candidatePid != runtimePid
        return true
    className := Win32WindowClass(hwnd)
    if StrLower(className)
        != StrLower(MxNMViewerToolCommand.NativeClassName) {
        return true
    }
    parentHwnd := Win32ParentHwnd(hwnd)
    if !parentHwnd
        return true
    try parentPid := WinGetPID("ahk_id " parentHwnd)
    catch
        parentPid := 0
    if parentPid != runtimePid
        return true
    rect := Win32WindowRect(hwnd)
    parentRect := Win32WindowRect(parentHwnd)
    if !IsObject(rect)
        || !IsObject(parentRect)
        || !RectEncloses(parentRect, rect) {
        return true
    }
    candidates.Push({
        hwnd: hwnd,
        parentHwnd: parentHwnd,
        rootHwnd: Win32RootWindow(hwnd),
        controlId: controlId,
        commandKey: commandKeyById[controlId],
        className: className,
        rect: rect,
        parentRect: parentRect
    })
    return true
}

MxNMViewerToolPanelMatchesPadOrigin(
    panelHwnd,
    panelRect,
    padOrigin,
    runtimeFrame,
    runtimePid
) {
    if !panelHwnd
        || !IsObject(panelRect)
        || !Win32IsWindowVisible(panelHwnd) {
        return false
    }
    try panelPid := WinGetPID("ahk_id " panelHwnd)
    catch
        panelPid := 0
    if panelPid != runtimePid
        return false
    tolerance := Min(
        MxNMViewerToolCommand.PanelOriginToleranceMaxPx,
        Max(
            MxNMViewerToolCommand.PanelOriginToleranceMinPx,
            Round(
                Min(
                    runtimeFrame.windowWidth,
                    runtimeFrame.windowHeight
                ) * MxNMViewerToolCommand.PanelOriginToleranceRatio
            )
        )
    )
    if Abs(panelRect.left - padOrigin.x) > tolerance
        || Abs(panelRect.top - padOrigin.y) > tolerance {
        return false
    }
    frameRect := {
        left: runtimeFrame.windowX,
        top: runtimeFrame.windowY,
        right: runtimeFrame.windowX
            + runtimeFrame.windowWidth,
        bottom: runtimeFrame.windowY
            + runtimeFrame.windowHeight
    }
    return panelRect.left >= frameRect.left - tolerance
        && panelRect.top >= frameRect.top - tolerance
        && panelRect.right <= frameRect.right + tolerance
        && panelRect.bottom <= frameRect.bottom + tolerance
}

ValidateMxNMViewerToolControlLayout(
    commands,
    controls,
    panelRect
) {
    if Type(commands) != "Map"
        || Type(controls) != "Map"
        || !IsObject(panelRect)
        || commands.Count != controls.Count {
        return false
    }
    for commandKey, command in commands {
        if !controls.Has(commandKey)
            return false
        control := controls[commandKey]
        if !IsObject(control)
            || control.controlId != command.commandId
            || !IsObject(control.rect)
            || !RectEncloses(panelRect, control.rect) {
            return false
        }
    }
    for leftKey, leftCommand in commands {
        leftRect := controls[leftKey].rect
        for rightKey, rightCommand in commands {
            if leftKey = rightKey
                continue
            rightRect := controls[rightKey].rect
            if leftCommand.row < rightCommand.row
                && leftRect.top >= rightRect.top {
                return false
            }
            if leftCommand.row = rightCommand.row
                && leftCommand.column < rightCommand.column
                && leftRect.left >= rightRect.left {
                return false
            }
        }
    }
    return true
}

MxNMViewerToolRectCenter(rect) {
    return {
        x: Round((rect.left + rect.right) / 2),
        y: Round((rect.top + rect.bottom) / 2)
    }
}

DispatchMxNMViewerToolButton(target, timeoutMs := 250) {
    messageResult := Buffer(A_PtrSize, 0)
    try {
        return DllCall(
            "User32\SendMessageTimeoutW",
            "Ptr", target.parentHwnd,
            "UInt", 0x0111,
            "UPtr", target.controlId,
            "Ptr", target.hwnd,
            "UInt", 0x0002,
            "UInt", Max(1, Integer(timeoutMs)),
            "Ptr", messageResult.Ptr,
            "Ptr"
        ) != 0
    } catch {
        return false
    }
}


; Entry fragment for build_viewer_state_regression.py.
; Execute the generated standalone file with AutoHotkey v2 on Windows.
try {
    RunViewerStateRegression()
    FileAppend "Viewer state regression: PASS`n", "*"
    ExitApp 0
} catch as regressionError {
    FileAppend "Viewer state regression: FAIL - " regressionError.Message "`n", "**"
    ExitApp 1
}

RunViewerStateRegression() {
    target := {pid: 101, hwnd: 1001}
    ReportImageCaptionPasteGate.ReadyTargetKey := ""
    AssertViewerState(ReportImageCaptionPasteGate.Plan(target).milliseconds = 500, "first target")
    ; Resolving/planning then cancelling must not consume the first save gate.
    AssertViewerState(ReportImageCaptionPasteGate.Plan(target).milliseconds = 500, "cancel before paste")
    ReportImageCaptionPasteGate.ObserveSave(target)
    AssertViewerState(ReportImageCaptionPasteGate.Plan(target).milliseconds = 20, "saved target")
    AssertViewerState(ReportImageCaptionPasteGate.Plan({pid: 101, hwnd: 1002}).milliseconds = 500, "new HWND in same process")
    AssertViewerState(ReportImageCaptionPasteGate.Plan({pid: 102, hwnd: 1001}).milliseconds = 500, "new process")
    AssertViewerState(MxNMViewerReleaseDecision(true, true, 2999, 3000) = "WAITING", "held before deadline")
    AssertViewerState(MxNMViewerReleaseDecision(true, true, 3000, 3000) = "KEY_RELEASE_TIMEOUT", "held at deadline")
    AssertViewerState(MxNMViewerReleaseDecision(false, true, 0, 3000) = "RELEASED", "next press can release")
    AssertViewerState(MxNMViewerReleaseDecision(false, false, 0, 3000) = "FOREGROUND_CHANGED", "cancel even after release")
    TestColorResetFailureSelection()
    TestViewerNativePanels()
}

TestViewerNativePanels() {
    panel := Gui("+ToolWindow")
    duplicate := Gui("+ToolWindow")
    try {
        controls := AddViewerTestButtons(panel)
        panel.Show("NoActivate x20 y20 w140 h130")
        controls["suv3d"].Enabled := false
        plan := {commands: Map()}
        for spec in MxNMViewerToolCommand.Specs()
            plan.commands[spec.id] := {commandId: spec.commandId, row: 0, column: 0}
        result := ResolveMxNMViewerToolControlSet(plan, [{hwnd: panel.Hwnd}])
        AssertViewerState(result.ok, "disabled sibling still identifies unique panel")
        AssertViewerState(result.controls["length"].controlId = 21048, "length identity independent of row")
        AddViewerTestButtons(duplicate)
        duplicate.Show("NoActivate x180 y20 w140 h130")
        result := ResolveMxNMViewerToolControlSet(plan, [{hwnd: panel.Hwnd}, {hwnd: duplicate.Hwnd}])
        AssertViewerState(!result.ok && result.code = "BUTTON_SET_NOT_UNIQUE", "two complete panels rejected")
    } finally {
        duplicate.Destroy()
        panel.Destroy()
    }
}

AddViewerTestButtons(panel) {
    buttons := Map()
    ; Deliberately use a different visual order from historical vendor rows.
    for index, spec in [MxNMViewerToolCommand.Specs()[3], MxNMViewerToolCommand.Specs()[1], MxNMViewerToolCommand.Specs()[2]] {
        button := panel.Add("Button", "x10 y" (10 + (index - 1) * 35) " w110 h25", spec.id)
        DllCall(A_PtrSize = 8 ? "User32\SetWindowLongPtrW" : "User32\SetWindowLongW", "Ptr", button.Hwnd, "Int", -12, "Ptr", spec.commandId, "Ptr")
        buttons[spec.id] := button
    }
    return buttons
}

AssertViewerState(condition, label) {
    if !condition
        throw Error(label)
}

TestColorResetFailureSelection() {
    oldCaption := {action: "ReportImageCaption", timestamp: "2026-09-04T18:38:57", source: "AUTOMATION"}
    currentFailure := "timestamp=2026-09-07T09:45:20 appVersion=0.8.0 action=MedExColorReset resultCode=ANCHOR_NOT_READY preflightStage=redResetReadiness readinessReason=exactAnchorNotReady exactAnchorQueryCount=8 exactAnchorCandidateCount=0 readinessElapsedMs=406 unlisted=SENSITIVE_FIXTURE"
    color := FindRecentColorResetFailureEvent([currentFailure, ""])
    AssertViewerState(color.timestamp = "2026-09-07T09:45:20", "legacy timestamp parsed")
    AssertViewerState(NewerAutomationDiagnosticEvent(oldCaption, color).source = "COLOR_RESET_FAILURE", "current failure beats stale Caption")
    AssertViewerState(InStr(color.summary, "resultCode=ANCHOR_NOT_READY"), "failure code retained")
    AssertViewerState(InStr(color.summary, "readinessElapsedMs=406"), "failure timing retained")
    AssertViewerState(!InStr(color.summary, "SENSITIVE_FIXTURE"), "unlisted content omitted")
    newerCapture := {action: "ViewerCapture", timestamp: "2026-09-07T09:46:00", source: "AUTOMATION"}
    AssertViewerState(NewerAutomationDiagnosticEvent(newerCapture, color).action = "ViewerCapture", "old color failure cannot hide new capture")
    missing := FindRecentColorResetFailureEvent([])
    AssertViewerState(NewerAutomationDiagnosticEvent(oldCaption, missing).action = "ReportImageCaption", "missing legacy file does not replace event")
}
