#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include ..\..\src\mxnm_config_geometry_provider.ahk
#Include ..\..\src\mxnm_viewer_tool_commands.ahk
#Include ..\..\src\mxnm_measurement_target_resolver.ahk

global MXNM_CONTEXT_DIAGNOSTIC_VERSION := "1.0"
global MXNM_CONTEXT_DIAGNOSTIC_BUSY := false

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
DetectHiddenWindows true

^!F8::RunMxNMContextMenuReceiverDiagnostic()

RunMxNMContextMenuReceiverDiagnostic() {
    global MXNM_CONTEXT_DIAGNOSTIC_BUSY
    if MXNM_CONTEXT_DIAGNOSTIC_BUSY {
        ToolTip "诊断正在运行。"
        SetTimer (() => ToolTip()), -1500
        return
    }
    MXNM_CONTEXT_DIAGNOSTIC_BUSY := true
    try {
        MouseGetPos &manualX, &manualY
        foregroundBefore := WinExist("A")
        report := BuildMxNMContextMenuReceiverDiagnostic(
            {x: manualX, y: manualY},
            foregroundBefore
        )
        A_Clipboard := report
        copied := ClipWait(2)
        foregroundAfter := WinExist("A")
        report .=
            "ForegroundAfter=" foregroundAfter "`r`n" .
            "ForegroundUnchanged=" .
                MxNMContextDiagnosticBool(
                    foregroundBefore = foregroundAfter
                ) "`r`n"
        A_Clipboard := report
        ClipWait 2
        MsgBox(
            copied
                ? "Viewer 右键诊断完成。结果已复制到剪贴板。"
                : "Viewer 右键诊断完成，但剪贴板写入未确认。",
            "MedEx Viewer 诊断",
            "Iconi"
        )
    } catch as err {
        failure :=
            "Test=MxNMContextMenuReceiverDiagnostic`r`n" .
            "DiagnosticVersion=" MXNM_CONTEXT_DIAGNOSTIC_VERSION "`r`n" .
            "FatalErrorType=" Type(err) "`r`n" .
            "FatalErrorMessage=" err.Message "`r`n"
        A_Clipboard := failure
        ClipWait 2
        MsgBox(
            "诊断发生异常；异常摘要已复制到剪贴板。",
            "MedEx Viewer 诊断",
            "Iconx"
        )
    } finally {
        MXNM_CONTEXT_DIAGNOSTIC_BUSY := false
    }
}

BuildMxNMContextMenuReceiverDiagnostic(manualPoint, foregroundBefore) {
    global MXNM_CONTEXT_DIAGNOSTIC_VERSION
    viewerExe := MxNMConfigGeometryDefaults.ViewerExe
    startedAt := A_TickCount
    report :=
        "Test=MxNMContextMenuReceiverDiagnostic`r`n" .
        "DiagnosticVersion=" MXNM_CONTEXT_DIAGNOSTIC_VERSION "`r`n" .
        "InteractionMode=NON_DESTRUCTIVE_POPUP_PROBE`r`n" .
        "CommandDispatch=DISABLED`r`n" .
        "RawWindowTextCaptured=false`r`n" .
        "Timestamp=" FormatTime(, "yyyy-MM-ddTHH:mm:ss") "`r`n" .
        "A_OSVersion=" A_OSVersion "`r`n" .
        "A_PtrSize=" A_PtrSize "`r`n" .
        "A_ScreenDPI=" A_ScreenDPI "`r`n" .
        "VirtualScreen=" .
            SysGet(76) "," SysGet(77) "," .
            SysGet(78) "," SysGet(79) "`r`n" .
        "ForegroundBefore=" foregroundBefore "`r`n" .
        "ManualPoint=" MxNMContextDiagnosticPoint(manualPoint) "`r`n"

    plan := BuildMxNMMeasurementTargetPlan(viewerExe)
    report .=
        "PlanOk=" MxNMContextDiagnosticBool(plan.ok) "`r`n" .
        "PlanCode=" plan.code "`r`n" .
        "PlanConfigCode=" plan.configCode "`r`n" .
        "PlanLayoutModelCount=" plan.layoutModelCount "`r`n"

    viewerWindows := []
    if plan.viewerProcessPath != "" {
        viewerWindows := CaptureMxNMViewerWindowGeometry(
            viewerExe,
            plan.viewerProcessPath
        )
    }
    report .= "ViewerWindowCount=" viewerWindows.Length "`r`n"

    toolAnchor := ResolveMxNMMeasurementToolAnchor(
        plan,
        viewerWindows
    )
    report .=
        "ToolAnchorOk=" .
            MxNMContextDiagnosticBool(toolAnchor.ok) "`r`n" .
        "ToolFrameHwnd=" toolAnchor.frameHwnd "`r`n" .
        "ToolActionRootHwnd=" toolAnchor.actionRootHwnd "`r`n" .
        "ToolPanelHwnd=" toolAnchor.panelHwnd "`r`n"

    target := MxNMMeasurementTargetResolver.Resolve(
        plan,
        viewerExe
    )
    report .= FormatMxNMContextDiagnosticTarget(target)

    expectedPid := toolAnchor.ok
        ? MxNMContextDiagnosticPid(toolAnchor.frameHwnd)
        : target.actionPid
    expectedOwner := toolAnchor.ok
        ? toolAnchor.frameHwnd
        : (
            target.actionHwnd
                ? ResolveMxNMRootOwnerHwnd(target.actionHwnd)
                : 0
        )
    report .=
        "ExpectedPid=" expectedPid "`r`n" .
        "ExpectedOwnerHwnd=" expectedOwner "`r`n"

    points := [
        {label: "manual", point: manualPoint}
    ]
    if IsObject(target.screenPoint)
        && (
            target.screenPoint.x != manualPoint.x
            || target.screenPoint.y != manualPoint.y
        ) {
        points.Push({
            label: "automatic",
            point: target.screenPoint
        })
    }

    for pointEntry in points {
        point := pointEntry.point
        label := pointEntry.label
        report .=
            "PointBegin=" label "`r`n" .
            "PointScreen=" MxNMContextDiagnosticPoint(point) "`r`n" .
            FormatMxNMContextDiagnosticPointChain(
                label,
                point,
                expectedPid
            )
        candidates := CollectMxNMContextDiagnosticCandidates(
            point,
            expectedPid,
            expectedOwner,
            toolAnchor,
            target
        )
        report .=
            "CandidateCount=" candidates.Length "`r`n"
        probeLimit := Min(24, candidates.Length)
        loop probeLimit {
            candidate := candidates[A_Index]
            report .= FormatMxNMContextDiagnosticCandidate(
                A_Index,
                candidate
            )
            probe := ProbeMxNMContextDiagnosticCandidate(
                candidate,
                point,
                expectedPid,
                expectedOwner
            )
            report .= FormatMxNMContextDiagnosticProbe(
                A_Index,
                probe
            )
        }
        report .=
            "ProbeCount=" probeLimit "`r`n" .
            "PointEnd=" label "`r`n"
    }
    report .=
        "ElapsedMs=" (A_TickCount - startedAt) "`r`n" .
        "EndOfReport=true`r`n"
    return report
}

FormatMxNMContextDiagnosticTarget(target) {
    return
        "TargetOk=" MxNMContextDiagnosticBool(target.ok) "`r`n" .
        "TargetCode=" target.code "`r`n" .
        "TargetConfigCode=" target.configCode "`r`n" .
        "RuntimeFrameCandidateCount=" .
            target.runtimeFrameCandidateCount "`r`n" .
        "RuntimeFrameOwnerFamilyCount=" .
            target.runtimeFrameOwnerFamilyCount "`r`n" .
        "RuntimeToolAnchorResolved=" .
            MxNMContextDiagnosticBool(
                target.runtimeToolAnchorResolved
            ) "`r`n" .
        "RuntimeToolAnchorUsed=" .
            MxNMContextDiagnosticBool(
                target.runtimeToolAnchorUsed
            ) "`r`n" .
        "RuntimeToolAnchorFallbackCode=" .
            target.runtimeToolAnchorFallbackCode "`r`n" .
        "TargetImageRect=" .
            MxNMContextDiagnosticRect(target.imageRect) "`r`n" .
        "TargetScreenPoint=" .
            MxNMContextDiagnosticPoint(target.screenPoint) "`r`n" .
        "TargetActionHwnd=" target.actionHwnd "`r`n" .
        "TargetActionPid=" target.actionPid "`r`n" .
        "TargetActionClientPoint=" .
            MxNMContextDiagnosticPoint(
                target.actionClientPoint
            ) "`r`n"
}

FormatMxNMContextDiagnosticPointChain(
    label,
    point,
    expectedPid
) {
    output := ""
    hwnd := MxNMContextDiagnosticWindowFromPoint(point)
    seen := Map()
    depth := 0
    while hwnd && !seen.Has(hwnd) && depth < 16 {
        seen[hwnd] := true
        pid := MxNMContextDiagnosticPid(hwnd)
        output .=
            "PointChain." label "." depth ".Hwnd=" hwnd "`r`n" .
            "PointChain." label "." depth ".PidMatches=" .
                MxNMContextDiagnosticBool(pid = expectedPid) "`r`n" .
            "PointChain." label "." depth ".Class=" .
                MxNMViewerToolWindowClass(hwnd) "`r`n" .
            "PointChain." label "." depth ".Parent=" .
                MxNMContextDiagnosticParent(hwnd) "`r`n" .
            "PointChain." label "." depth ".Root=" .
                MxNMViewerToolGetRootHwnd(hwnd) "`r`n" .
            "PointChain." label "." depth ".RootOwner=" .
                MxNMViewerToolGetRootOwnerHwnd(hwnd) "`r`n" .
            "PointChain." label "." depth ".ClientRect=" .
                MxNMContextDiagnosticRect(
                    MxNMTargetClientRectScreen(hwnd)
                ) "`r`n"
        hwnd := MxNMContextDiagnosticParent(hwnd)
        depth += 1
    }
    return output
}

CollectMxNMContextDiagnosticCandidates(
    point,
    expectedPid,
    expectedOwner,
    toolAnchor,
    target
) {
    candidatesByHwnd := Map()
    pointHwnd := MxNMContextDiagnosticWindowFromPoint(point)
    hwnd := pointHwnd
    depth := 0
    while hwnd && depth < 16 {
        AddMxNMContextDiagnosticCandidate(
            candidatesByHwnd,
            hwnd,
            "point-chain",
            point,
            expectedPid,
            expectedOwner,
            depth
        )
        parent := MxNMContextDiagnosticParent(hwnd)
        if !parent || parent = hwnd
            break
        hwnd := parent
        depth += 1
    }

    if toolAnchor.ok {
        AddMxNMContextDiagnosticCandidate(
            candidatesByHwnd,
            toolAnchor.actionRootHwnd,
            "tool-action-root",
            point,
            expectedPid,
            expectedOwner,
            0
        )
        AddMxNMContextDiagnosticCandidate(
            candidatesByHwnd,
            toolAnchor.frameHwnd,
            "tool-frame",
            point,
            expectedPid,
            expectedOwner,
            0
        )
        EnumerateMxNMContextDiagnosticDescendants(
            toolAnchor.actionRootHwnd,
            "action-descendant",
            point,
            expectedPid,
            expectedOwner,
            candidatesByHwnd
        )
        if toolAnchor.frameHwnd != toolAnchor.actionRootHwnd {
            EnumerateMxNMContextDiagnosticDescendants(
                toolAnchor.frameHwnd,
                "frame-descendant",
                point,
                expectedPid,
                expectedOwner,
                candidatesByHwnd
            )
        }
    }
    if target.actionHwnd {
        AddMxNMContextDiagnosticCandidate(
            candidatesByHwnd,
            target.actionHwnd,
            "current-target",
            point,
            expectedPid,
            expectedOwner,
            0
        )
    }

    candidates := []
    for _, candidate in candidatesByHwnd
        candidates.Push(candidate)
    SortMxNMContextDiagnosticCandidates(candidates)
    return candidates
}

EnumerateMxNMContextDiagnosticDescendants(
    rootHwnd,
    source,
    point,
    expectedPid,
    expectedOwner,
    candidatesByHwnd
) {
    if !rootHwnd
        return
    callback := CallbackCreate(
        AddMxNMContextDiagnosticDescendant.Bind(
            source,
            point,
            expectedPid,
            expectedOwner,
            candidatesByHwnd
        ),
        "Fast",
        2
    )
    try DllCall(
        "User32\EnumChildWindows",
        "Ptr", rootHwnd,
        "Ptr", callback,
        "Ptr", 0,
        "Int"
    )
    finally CallbackFree(callback)
}

AddMxNMContextDiagnosticDescendant(
    source,
    point,
    expectedPid,
    expectedOwner,
    candidatesByHwnd,
    hwnd,
    *
) {
    AddMxNMContextDiagnosticCandidate(
        candidatesByHwnd,
        hwnd,
        source,
        point,
        expectedPid,
        expectedOwner,
        MxNMContextDiagnosticDepth(hwnd)
    )
    return true
}

AddMxNMContextDiagnosticCandidate(
    candidatesByHwnd,
    hwnd,
    source,
    point,
    expectedPid,
    expectedOwner,
    depth
) {
    if !hwnd
        return
    if candidatesByHwnd.Has(hwnd) {
        existing := candidatesByHwnd[hwnd]
        if !InStr("," existing.sources ",", "," source ",")
            existing.sources .= "," source
        return
    }
    pid := MxNMContextDiagnosticPid(hwnd)
    rootOwner := MxNMViewerToolGetRootOwnerHwnd(hwnd)
    clientRect := MxNMTargetClientRectScreen(hwnd)
    if pid != expectedPid
        || !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")
        || !DllCall("User32\IsWindowEnabled", "Ptr", hwnd, "Int")
        || !IsObject(clientRect)
        || !MxNMPointInsideRect(point, clientRect) {
        return
    }
    area := Max(
        0,
        (clientRect.right - clientRect.left)
        * (clientRect.bottom - clientRect.top)
    )
    candidatesByHwnd[hwnd] := {
        hwnd: hwnd,
        sources: source,
        pid: pid,
        className: MxNMViewerToolWindowClass(hwnd),
        parentHwnd: MxNMContextDiagnosticParent(hwnd),
        rootHwnd: MxNMViewerToolGetRootHwnd(hwnd),
        rootOwnerHwnd: rootOwner,
        ownerMatches: rootOwner = expectedOwner,
        clientRect: clientRect,
        depth: depth,
        area: area
    }
}

SortMxNMContextDiagnosticCandidates(candidates) {
    index := 2
    while index <= candidates.Length {
        candidate := candidates[index]
        insertAt := index
        while insertAt > 1
            && MxNMContextDiagnosticCandidateBefore(
                candidate,
                candidates[insertAt - 1]
            ) {
            candidates[insertAt] := candidates[insertAt - 1]
            insertAt -= 1
        }
        candidates[insertAt] := candidate
        index += 1
    }
}

MxNMContextDiagnosticCandidateBefore(left, right) {
    if left.area != right.area
        return left.area < right.area
    if left.depth != right.depth
        return left.depth > right.depth
    return left.hwnd < right.hwnd
}

FormatMxNMContextDiagnosticCandidate(index, candidate) {
    prefix := "Candidate." index "."
    return
        prefix "Hwnd=" candidate.hwnd "`r`n" .
        prefix "Sources=" candidate.sources "`r`n" .
        prefix "Class=" candidate.className "`r`n" .
        prefix "Parent=" candidate.parentHwnd "`r`n" .
        prefix "Root=" candidate.rootHwnd "`r`n" .
        prefix "RootOwner=" candidate.rootOwnerHwnd "`r`n" .
        prefix "OwnerMatches=" .
            MxNMContextDiagnosticBool(
                candidate.ownerMatches
            ) "`r`n" .
        prefix "Depth=" candidate.depth "`r`n" .
        prefix "ClientRect=" .
            MxNMContextDiagnosticRect(candidate.clientRect) "`r`n" .
        prefix "ClientArea=" candidate.area "`r`n"
}

ProbeMxNMContextDiagnosticCandidate(
    candidate,
    screenPoint,
    expectedPid,
    expectedOwner
) {
    result := {
        downSent: false,
        upSent: false,
        newWindows: [],
        elapsedMs: 0
    }
    before := SnapshotMxNMContextDiagnosticWindows(expectedPid)
    clientPoint := MxNMTargetScreenToClient(
        candidate.hwnd,
        screenPoint
    )
    if !IsObject(clientPoint)
        return result
    lParam := ((clientPoint.y & 0xFFFF) << 16)
        | (clientPoint.x & 0xFFFF)
    startedAt := A_TickCount
    result.downSent := DllCall(
        "User32\PostMessageW",
        "Ptr", candidate.hwnd,
        "UInt", 0x0204,
        "UPtr", 0x0002,
        "Ptr", lParam,
        "Int"
    ) = true
    result.upSent := DllCall(
        "User32\PostMessageW",
        "Ptr", candidate.hwnd,
        "UInt", 0x0205,
        "UPtr", 0,
        "Ptr", lParam,
        "Int"
    ) = true
    deadline := A_TickCount + 600
    loop {
        result.newWindows := FindNewMxNMContextDiagnosticWindows(
            expectedPid,
            expectedOwner,
            before
        )
        if result.newWindows.Length > 0
            break
        if A_TickCount >= deadline
            break
        Sleep 20
    }
    result.elapsedMs := A_TickCount - startedAt
    for popup in result.newWindows {
        if popup.hwnd = candidate.hwnd
            || popup.hwnd = candidate.rootHwnd {
            popup.safeToClose := false
        }
        if popup.safeToClose {
            DllCall(
                "User32\PostMessageW",
                "Ptr", popup.hwnd,
                "UInt", 0x0010,
                "UPtr", 0,
                "Ptr", 0,
                "Int"
            )
        }
    }
    if result.newWindows.Length > 0
        Sleep 80
    return result
}

SnapshotMxNMContextDiagnosticWindows(expectedPid) {
    snapshot := Map()
    try windows := WinGetList()
    catch
        windows := []
    for hwnd in windows {
        if MxNMContextDiagnosticPid(hwnd) != expectedPid
            continue
        flags := MxNMContextDiagnosticKnownCommandFlags(hwnd)
        snapshot[hwnd] := {
            visible: DllCall(
                "User32\IsWindowVisible",
                "Ptr", hwnd,
                "Int"
            ) = true,
            rect: MxNMViewerToolWindowRectScreen(hwnd),
            controlCount: flags.controlCount,
            hasDeleteAll: flags.hasDeleteAll,
            hasSuvMax: flags.hasSuvMax,
            hasLineAxes: flags.hasLineAxes
        }
    }
    return snapshot
}

FindNewMxNMContextDiagnosticWindows(
    expectedPid,
    expectedOwner,
    snapshot
) {
    matches := []
    try windows := WinGetList()
    catch
        windows := []
    for hwnd in windows {
        if MxNMContextDiagnosticPid(hwnd) != expectedPid
            continue
        rootOwner := MxNMViewerToolGetRootOwnerHwnd(hwnd)
        owner := MxNMContextDiagnosticOwner(hwnd)
        flags := MxNMContextDiagnosticKnownCommandFlags(hwnd)
        className := MxNMViewerToolWindowClass(hwnd)
        visible := DllCall(
            "User32\IsWindowVisible",
            "Ptr", hwnd,
            "Int"
        ) = true
        rect := MxNMViewerToolWindowRectScreen(hwnd)
        discovery := "NEW_HANDLE"
        if snapshot.Has(hwnd) {
            before := snapshot[hwnd]
            if !MxNMContextDiagnosticWindowStateChanged(
                before,
                visible,
                rect,
                flags,
                className
            ) {
                continue
            }
            discovery := "STATE_CHANGED"
        }
        matches.Push({
            hwnd: hwnd,
            discovery: discovery,
            className: className,
            ownerHwnd: owner,
            rootOwnerHwnd: rootOwner,
            ownerMatches: rootOwner = expectedOwner
                || owner = expectedOwner,
            rect: rect,
            visible: visible,
            safeToClose: hwnd != expectedOwner
                && (
                    discovery = "NEW_HANDLE"
                    || StrLower(className) = "#32770"
                    || StrLower(className) = "#32768"
                    || flags.hasDeleteAll
                    || flags.hasSuvMax
                    || flags.hasLineAxes
                ),
            controlCount: flags.controlCount,
            hasDeleteAll: flags.hasDeleteAll,
            hasSuvMax: flags.hasSuvMax,
            hasLineAxes: flags.hasLineAxes
        })
    }
    return matches
}

MxNMContextDiagnosticWindowStateChanged(
    before,
    visible,
    rect,
    flags,
    className
) {
    if before.visible != visible
        return true
    if before.hasDeleteAll != flags.hasDeleteAll
        || before.hasSuvMax != flags.hasSuvMax
        || before.hasLineAxes != flags.hasLineAxes {
        return true
    }
    if StrLower(className) = "#32770"
        || StrLower(className) = "#32768" {
        return before.controlCount != flags.controlCount
            || MxNMContextDiagnosticRect(before.rect)
                != MxNMContextDiagnosticRect(rect)
    }
    return false
}

MxNMContextDiagnosticKnownCommandFlags(hwnd) {
    result := {
        controlCount: 0,
        hasDeleteAll: false,
        hasSuvMax: false,
        hasLineAxes: false
    }
    try controls := WinGetControlsHwnd("ahk_id " hwnd)
    catch
        controls := []
    result.controlCount := controls.Length
    for controlHwnd in controls {
        try text := ControlGetText(controlHwnd)
        catch
            text := ""
        if text = "删除全部标注"
            result.hasDeleteAll := true
        else if text = "复制SUVMax值"
            result.hasSuvMax := true
        else if text = "复制直线测量值"
            result.hasLineAxes := true
    }
    return result
}

FormatMxNMContextDiagnosticProbe(index, probe) {
    prefix := "Probe." index "."
    output :=
        prefix "RightDownSent=" .
            MxNMContextDiagnosticBool(probe.downSent) "`r`n" .
        prefix "RightUpSent=" .
            MxNMContextDiagnosticBool(probe.upSent) "`r`n" .
        prefix "ElapsedMs=" probe.elapsedMs "`r`n" .
        prefix "NewWindowCount=" probe.newWindows.Length "`r`n"
    popupIndex := 0
    for popup in probe.newWindows {
        popupIndex += 1
        popupPrefix := prefix "NewWindow." popupIndex "."
        output .=
            popupPrefix "Hwnd=" popup.hwnd "`r`n" .
            popupPrefix "Discovery=" popup.discovery "`r`n" .
            popupPrefix "Class=" popup.className "`r`n" .
            popupPrefix "Owner=" popup.ownerHwnd "`r`n" .
            popupPrefix "RootOwner=" popup.rootOwnerHwnd "`r`n" .
            popupPrefix "OwnerMatches=" .
                MxNMContextDiagnosticBool(
                    popup.ownerMatches
                ) "`r`n" .
            popupPrefix "Rect=" .
                MxNMContextDiagnosticRect(popup.rect) "`r`n" .
            popupPrefix "Visible=" .
                MxNMContextDiagnosticBool(popup.visible) "`r`n" .
            popupPrefix "SafeToClose=" .
                MxNMContextDiagnosticBool(
                    popup.safeToClose
                ) "`r`n" .
            popupPrefix "ControlCount=" .
                popup.controlCount "`r`n" .
            popupPrefix "HasDeleteAll=" .
                MxNMContextDiagnosticBool(
                    popup.hasDeleteAll
                ) "`r`n" .
            popupPrefix "HasSuvMax=" .
                MxNMContextDiagnosticBool(
                    popup.hasSuvMax
                ) "`r`n" .
            popupPrefix "HasLineAxes=" .
                MxNMContextDiagnosticBool(
                    popup.hasLineAxes
                ) "`r`n"
    }
    return output
}

MxNMContextDiagnosticWindowFromPoint(point) {
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

MxNMContextDiagnosticParent(hwnd) {
    try return DllCall(
        "User32\GetParent",
        "Ptr", hwnd,
        "Ptr"
    )
    catch
        return 0
}

MxNMContextDiagnosticOwner(hwnd) {
    try return DllCall(
        "User32\GetWindow",
        "Ptr", hwnd,
        "UInt", 4,
        "Ptr"
    )
    catch
        return 0
}

MxNMContextDiagnosticPid(hwnd) {
    try return WinGetPID("ahk_id " hwnd)
    catch
        return 0
}

MxNMContextDiagnosticDepth(hwnd) {
    depth := 0
    seen := Map()
    while hwnd && !seen.Has(hwnd) && depth < 32 {
        seen[hwnd] := true
        hwnd := MxNMContextDiagnosticParent(hwnd)
        if hwnd
            depth += 1
    }
    return depth
}

MxNMContextDiagnosticBool(value) {
    return value ? "true" : "false"
}

MxNMContextDiagnosticPoint(point) {
    return IsObject(point) ? point.x "," point.y : ""
}

MxNMContextDiagnosticRect(rect) {
    if !IsObject(rect)
        return ""
    return
        rect.left "," rect.top "," .
        rect.right "," rect.bottom
}
