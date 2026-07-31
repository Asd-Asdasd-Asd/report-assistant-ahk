class MxNMMeasurementTargetCode {
    static READY_FOR_FIELD_VALIDATION := "READY_FOR_FIELD_VALIDATION"
    static CONFIG_GEOMETRY_UNAVAILABLE := "CONFIG_GEOMETRY_UNAVAILABLE"
    static LAYOUT_SCHEMA_INVALID := "LAYOUT_SCHEMA_INVALID"
    static LAYOUT_SAFE_POINT_NOT_FOUND := "LAYOUT_SAFE_POINT_NOT_FOUND"
    static RUNTIME_FRAME_NOT_UNIQUE := "RUNTIME_FRAME_NOT_UNIQUE"
    static ACTION_WINDOW_INVALID := "ACTION_WINDOW_INVALID"
    static POINT_OUT_OF_BOUNDS := "POINT_OUT_OF_BOUNDS"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MxNMMeasurementTargetResolver {
    static BuildPlan(viewerExe := "", configPaths := 0) {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        return BuildMxNMMeasurementTargetPlan(viewerExe, configPaths)
    }

    static Resolve(plan, viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        return ResolveMxNMMeasurementTargetFromPlan(plan, viewerExe)
    }
}

BuildMxNMMeasurementTargetPlan(viewerExe, configPaths := 0) {
    plan := MakeMxNMMeasurementTargetPlan()
    try {
        if !IsObject(configPaths)
            configPaths := ResolveMxNMConfigPathsFromViewer(viewerExe)
        configResult := MxNMConfigGeometryProvider.LoadStaticConfig(
            viewerExe,
            configPaths
        )
        plan.configCode := configResult.code
        if !configResult.ok
            return plan
        plan.configReady := true
        if !configResult.mainGeometry.frameSizeResolved
            || !configResult.mainGeometry.imagePositionResolved
            || !configResult.mainGeometry.imageSizeResolved {
            return plan
        }

        layoutResult := ParseMxNMDeclaredLayoutModels(
            configResult.layoutEntries,
            configResult.mainGeometry
        )
        plan.layoutModelCount := layoutResult.modelCount
        if !layoutResult.ok {
            plan.code := MxNMMeasurementTargetCode.LAYOUT_SCHEMA_INVALID
            return plan
        }
        plan.layoutReady := true

        safePointResult := FindMxNMCrossLayoutSafePoint(
            layoutResult.models,
            configResult.mainGeometry.imageWidth,
            configResult.mainGeometry.imageHeight
        )
        if !safePointResult.ok {
            plan.code :=
                MxNMMeasurementTargetCode.LAYOUT_SAFE_POINT_NOT_FOUND
            return plan
        }
        plan.viewerExe := viewerExe
        plan.viewerProcessPath := configResult.viewerProcessPath
        plan.mainConfigSha256 := configResult.mainConfigSha256
        plan.layoutConfigSha256 := configResult.layoutConfigSha256
        plan.mainGeometry := configResult.mainGeometry
        plan.logicalPoint := safePointResult.point
        plan.minimumLogicalClearance :=
            safePointResult.minimumClearance
        plan.minimumRequiredClearance :=
            safePointResult.minimumRequiredClearance
        viewerToolPlan := BuildMxNMViewerToolCommandPlan(
            viewerExe,
            configPaths
        )
        if viewerToolPlan.ok
            plan.viewerToolPlan := viewerToolPlan
        plan.ok := true
        plan.code := MxNMMeasurementTargetCode.READY_FOR_FIELD_VALIDATION
        return plan
    } catch {
        plan.code := MxNMMeasurementTargetCode.UNEXPECTED_ERROR
        return plan
    }
}

MakeMxNMMeasurementTargetPlan() {
    return {
        ok: false,
        code: MxNMMeasurementTargetCode.CONFIG_GEOMETRY_UNAVAILABLE,
        configCode: "",
        configReady: false,
        layoutReady: false,
        layoutModelCount: 0,
        viewerExe: "",
        viewerProcessPath: "",
        mainConfigSha256: "",
        layoutConfigSha256: "",
        mainGeometry: 0,
        logicalPoint: 0,
        minimumLogicalClearance: 0,
        minimumRequiredClearance: 0,
        viewerToolPlan: 0
    }
}

ResolveMxNMMeasurementTargetFromPlan(plan, viewerExe) {
    result := MakeMxNMMeasurementTargetResult()
    try {
        if IsObject(plan) && plan.HasOwnProp("configCode")
            result.configCode := plan.configCode
        if !IsReusableMxNMMeasurementTargetPlan(plan, viewerExe)
            return result
        result.configReady := true
        result.layoutReady := true
        result.layoutModelCount := plan.layoutModelCount
        result.logicalPoint := plan.logicalPoint
        result.minimumLogicalClearance := plan.minimumLogicalClearance
        result.minimumRequiredClearance := plan.minimumRequiredClearance

        if !WinExist("ahk_exe " viewerExe) {
            result.configCode := MxNMConfigGeometryCode.VIEWER_NOT_FOUND
            return result
        }
        try foregroundHwnd := WinExist("A")
        catch
            foregroundHwnd := 0
        viewerWindows := CaptureMxNMViewerWindowGeometry(
            viewerExe,
            plan.viewerProcessPath
        )
        toolAnchor := ResolveMxNMMeasurementToolAnchor(
            plan,
            viewerWindows
        )
        result.runtimeToolAnchorResolved := toolAnchor.ok
        result.runtimeToolAnchorHwnd := toolAnchor.frameHwnd
        runtimeTarget := ResolveMxNMRuntimeImageTarget(
            plan,
            viewerWindows
        )
        if !runtimeTarget.ok && toolAnchor.ok {
            runtimeTarget :=
                ResolveMxNMRuntimeImageTargetFromToolAnchor(
                    plan,
                    viewerWindows,
                    toolAnchor,
                    foregroundHwnd
                )
            result.runtimeToolAnchorFallbackCode :=
                runtimeTarget.fallbackCode
            result.runtimeToolAnchorUsed := runtimeTarget.ok
        }
        result.runtimeFrameCandidateCount :=
            runtimeTarget.candidateCount
        result.runtimeFrameOwnerFamilyCount :=
            runtimeTarget.ownerFamilyCount
        if !runtimeTarget.ok {
            result.code := MxNMMeasurementTargetCode.RUNTIME_FRAME_NOT_UNIQUE
            result.configCode :=
                MxNMConfigGeometryCode.RUNTIME_FRAME_NOT_UNIQUE
            return result
        }
        result.runtimeFrameResolved := true
        result.mappedImageRectResolved := true
        result.imageRect := runtimeTarget.imageRect
        result.screenPoint := runtimeTarget.screenPoint

        actionWindowResult := result.runtimeToolAnchorUsed
            && runtimeTarget.HasOwnProp("actionHwnd")
            && runtimeTarget.actionHwnd
            ? ResolveMxNMActionWindowFromAnchor(
                viewerExe,
                result.screenPoint,
                runtimeTarget.frame.hwnd,
                runtimeTarget.actionHwnd
            )
            : ResolveMxNMActionWindowFromPoint(
                viewerExe,
                result.screenPoint,
                runtimeTarget.frame.hwnd
            )
        if !actionWindowResult.ok {
            result.code := actionWindowResult.code
            return result
        }
        result.actionHwnd := actionWindowResult.hwnd
        result.actionPid := actionWindowResult.pid
        result.actionClientPoint := actionWindowResult.clientPoint
        result.ok := true
        result.code :=
            MxNMMeasurementTargetCode.READY_FOR_FIELD_VALIDATION
        return result
    } catch {
        result.code := MxNMMeasurementTargetCode.UNEXPECTED_ERROR
        return result
    }
}

ResolveMxNMMeasurementToolAnchor(plan, viewerWindows) {
    failure := {
        ok: false,
        frameHwnd: 0,
        actionRootHwnd: 0,
        panelHwnd: 0
    }
    if !IsObject(plan)
        || !plan.HasOwnProp("viewerToolPlan")
        || !IsObject(plan.viewerToolPlan)
        || !plan.viewerToolPlan.ok {
        return failure
    }
    controlSet := ResolveMxNMViewerToolControlSet(
        plan.viewerToolPlan,
        viewerWindows
    )
    if !controlSet.ok
        || !controlSet.frameHwnd
        || !controlSet.actionRootHwnd {
        return failure
    }
    return {
        ok: true,
        frameHwnd: controlSet.frameHwnd,
        actionRootHwnd: controlSet.actionRootHwnd,
        panelHwnd: controlSet.panelHwnd
    }
}

ResolveMxNMRuntimeImageTarget(
    plan,
    viewerWindows
) {
    failure := {
        ok: false,
        candidateCount: 0,
        ownerFamilyCount: 0,
        frame: 0,
        imageRect: 0,
        screenPoint: 0
    }
    if !IsObject(plan)
        || !IsObject(plan.mainGeometry)
        || !IsObject(plan.logicalPoint)
        || viewerWindows.Length = 0 {
        return failure
    }
    candidates := []
    runtimeFrames := BuildMxNMRuntimeOwnerFrameCandidates(
        viewerWindows
    )
    for candidateFrame in runtimeFrames {
        mappedImage := MapMxNMLogicalImageRectToRuntime(
            plan.mainGeometry,
            candidateFrame
        )
        if !mappedImage.ok
            continue
        screenPoint := MapMxNMLogicalPointToRuntimeRect(
            plan.logicalPoint,
            plan.mainGeometry,
            mappedImage.rect
        )
        if !MxNMPointInsideRect(screenPoint, mappedImage.rect)
            continue
        rootOwnerHwnd := ResolveMxNMRootOwnerFromPoint(
            screenPoint
        )
        if !rootOwnerHwnd
            || rootOwnerHwnd != candidateFrame.hwnd {
            continue
        }
        candidates.Push({
            frame: candidateFrame,
            imageRect: mappedImage.rect,
            screenPoint: screenPoint
        })
    }
    failure.candidateCount := candidates.Length
    selected := SelectMxNMRuntimeImageTargetByOwnerFamily(
        candidates,
        viewerWindows
    )
    failure.ownerFamilyCount := selected.ownerFamilyCount
    if !selected.ok
        return failure
    return {
        ok: true,
        candidateCount: candidates.Length,
        ownerFamilyCount: selected.ownerFamilyCount,
        frame: selected.candidate.frame,
        imageRect: selected.candidate.imageRect,
        screenPoint: selected.candidate.screenPoint
    }
}

ResolveMxNMRuntimeImageTargetFromToolAnchor(
    plan,
    viewerWindows,
    toolAnchor,
    foregroundHwnd := 0
) {
    failure := {
        ok: false,
        candidateCount: 0,
        ownerFamilyCount: 0,
        frame: 0,
        imageRect: 0,
        screenPoint: 0,
        actionHwnd: 0,
        fallbackCode: "ANCHOR_INVALID"
    }
    if !IsObject(plan)
        || !IsObject(plan.mainGeometry)
        || !IsObject(plan.logicalPoint)
        || !IsObject(toolAnchor)
        || !toolAnchor.ok
        || !toolAnchor.frameHwnd
        || !toolAnchor.actionRootHwnd {
        return failure
    }
    framePid := MxNMTargetWindowPid(toolAnchor.frameHwnd)
    if !framePid
        || MxNMTargetWindowPid(toolAnchor.actionRootHwnd)
            != framePid
        || MxNMTargetWindowPid(toolAnchor.panelHwnd)
            != framePid {
        failure.fallbackCode := "ANCHOR_IDENTITY_INVALID"
        return failure
    }
    ownerFrame := CaptureMxNMRuntimeOwnerFrame(
        toolAnchor.frameHwnd
    )
    if !IsObject(ownerFrame) {
        failure.fallbackCode := "ANCHOR_FRAME_INVALID"
        return failure
    }
    surfaceResult := ResolveMxNMRuntimeImageSurfaceFromToolAnchor(
        viewerWindows,
        toolAnchor,
        ownerFrame,
        foregroundHwnd
    )
    failure.candidateCount := surfaceResult.candidateCount
    if !surfaceResult.ok {
        failure.fallbackCode := surfaceResult.code
        return failure
    }
    actionFrame := surfaceResult.frame
    mappedImage := MapMxNMLogicalImageRectToRuntime(
        plan.mainGeometry,
        actionFrame
    )
    if !mappedImage.ok {
        failure.fallbackCode := "ANCHOR_IMAGE_MAPPING_INVALID"
        return failure
    }
    screenPoint := MapMxNMLogicalPointToRuntimeRect(
        plan.logicalPoint,
        plan.mainGeometry,
        mappedImage.rect
    )
    if !MxNMPointInsideRect(screenPoint, mappedImage.rect)
        || !MxNMPointInsideRuntimeFrameClient(
            screenPoint,
            actionFrame
        ) {
        failure.fallbackCode := "ANCHOR_POINT_OUT_OF_BOUNDS"
        return failure
    }
    return {
        ok: true,
        candidateCount: surfaceResult.candidateCount,
        ownerFamilyCount: CountMxNMRuntimeOwnerFamily(
            viewerWindows,
            toolAnchor.frameHwnd
        ),
        frame: ownerFrame,
        imageRect: mappedImage.rect,
        screenPoint: screenPoint,
        actionHwnd: actionFrame.hwnd,
        fallbackCode: surfaceResult.code
    }
}

ResolveMxNMRuntimeImageSurfaceFromToolAnchor(
    viewerWindows,
    toolAnchor,
    ownerFrame,
    foregroundHwnd := 0
) {
    failure := {
        ok: false,
        code: "IMAGE_SURFACE_NOT_UNIQUE",
        candidateCount: 0,
        frame: 0
    }
    if !IsObject(viewerWindows)
        || !IsObject(toolAnchor)
        || !IsObject(ownerFrame)
        || ownerFrame.clientWidth <= 0
        || ownerFrame.clientHeight <= 0 {
        return failure
    }
    ownerArea := ownerFrame.clientWidth * ownerFrame.clientHeight
    minimumArea := Max(40000, Round(ownerArea * 0.10))
    candidates := []
    foregroundCandidate := 0
    for viewerWindow in viewerWindows {
        hwnd := viewerWindow.hwnd
        if !hwnd
            || hwnd = toolAnchor.frameHwnd
            || hwnd = toolAnchor.actionRootHwnd
            || hwnd = toolAnchor.panelHwnd
            || MxNMTargetWindowPid(hwnd)
                != MxNMTargetWindowPid(toolAnchor.frameHwnd)
            || ResolveMxNMRootOwnerHwnd(hwnd)
                != toolAnchor.frameHwnd
            || MxNMTargetParentHwnd(hwnd)
                != toolAnchor.frameHwnd
            || StrLower(MxNMViewerToolWindowClass(hwnd))
                != "#32770"
            || !DllCall(
                "User32\IsWindowVisible",
                "Ptr", hwnd,
                "Int"
            )
            || !DllCall(
                "User32\IsWindowEnabled",
                "Ptr", hwnd,
                "Int"
            )
            || viewerWindow.clientWidth < 200
            || viewerWindow.clientHeight < 200 {
            continue
        }
        area := viewerWindow.clientWidth
            * viewerWindow.clientHeight
        if area < minimumArea
            continue
        candidate := {
            frame: viewerWindow,
            area: area
        }
        candidates.Push(candidate)
        if hwnd = foregroundHwnd
            foregroundCandidate := candidate
    }
    failure.candidateCount := candidates.Length
    if IsObject(foregroundCandidate) {
        return {
            ok: true,
            code: "READY_FOREGROUND_IMAGE_CLIENT",
            candidateCount: candidates.Length,
            frame: foregroundCandidate.frame
        }
    }
    if candidates.Length = 0
        return failure
    best := candidates[1]
    secondArea := 0
    for candidate in candidates {
        if candidate.area > best.area {
            secondArea := best.area
            best := candidate
        } else if candidate.frame.hwnd != best.frame.hwnd {
            secondArea := Max(secondArea, candidate.area)
        }
    }
    if secondArea > 0 && best.area < secondArea * 1.25 {
        failure.code := "IMAGE_SURFACE_NOT_UNIQUE"
        return failure
    }
    return {
        ok: true,
        code: "READY_LARGEST_IMAGE_CLIENT",
        candidateCount: candidates.Length,
        frame: best.frame
    }
}

MxNMTargetParentHwnd(hwnd) {
    try return DllCall(
        "User32\GetParent",
        "Ptr", hwnd,
        "Ptr"
    )
    catch
        return 0
}

BuildMxNMRuntimeOwnerFrameCandidates(viewerWindows) {
    frames := []
    seen := Map()
    for viewerWindow in viewerWindows {
        ownerHwnd := ResolveMxNMRootOwnerHwnd(viewerWindow.hwnd)
        if !ownerHwnd || seen.Has(ownerHwnd)
            continue
        viewerPid := MxNMTargetWindowPid(viewerWindow.hwnd)
        if !viewerPid || MxNMTargetWindowPid(ownerHwnd) != viewerPid
            continue
        if ResolveMxNMRootOwnerHwnd(ownerHwnd) != ownerHwnd
            continue
        ownerFrame := CaptureMxNMRuntimeOwnerFrame(ownerHwnd)
        if !IsObject(ownerFrame)
            continue
        seen[ownerHwnd] := true
        frames.Push(ownerFrame)
    }
    return frames
}

CaptureMxNMRuntimeOwnerFrame(hwnd) {
    windowRect := Buffer(16, 0)
    if !DllCall(
        "User32\GetWindowRect",
        "Ptr", hwnd,
        "Ptr", windowRect.Ptr,
        "Int"
    ) {
        return 0
    }
    windowX := NumGet(windowRect, 0, "Int")
    windowY := NumGet(windowRect, 4, "Int")
    windowWidth := NumGet(windowRect, 8, "Int") - windowX
    windowHeight := NumGet(windowRect, 12, "Int") - windowY
    if windowWidth <= 0 || windowHeight <= 0
        return 0
    clientRect := MxNMTargetClientRectScreen(hwnd)
    if !IsObject(clientRect)
        || clientRect.right <= clientRect.left
        || clientRect.bottom <= clientRect.top {
        return 0
    }
    return {
        hwnd: hwnd,
        windowX: windowX,
        windowY: windowY,
        windowWidth: windowWidth,
        windowHeight: windowHeight,
        clientX: clientRect.left,
        clientY: clientRect.top,
        clientWidth: clientRect.right - clientRect.left,
        clientHeight: clientRect.bottom - clientRect.top
    }
}

SelectMxNMRuntimeImageTargetByOwnerFamily(
    candidates,
    viewerWindows
) {
    failure := {
        ok: false,
        ownerFamilyCount: 0,
        candidate: 0
    }
    if candidates.Length = 0
        return failure
    if candidates.Length = 1 {
        return {
            ok: true,
            ownerFamilyCount: CountMxNMRuntimeOwnerFamily(
                viewerWindows,
                candidates[1].frame.hwnd
            ),
            candidate: candidates[1]
        }
    }

    bestScore := -1
    bestCount := 0
    bestCandidate := 0
    for candidate in candidates {
        score := CountMxNMRuntimeOwnerFamily(
            viewerWindows,
            candidate.frame.hwnd
        )
        if score > bestScore {
            bestScore := score
            bestCount := 1
            bestCandidate := candidate
        } else if score = bestScore {
            bestCount += 1
        }
    }
    failure.ownerFamilyCount := Max(0, bestScore)
    if bestCount != 1 || bestScore < 2
        return failure
    return {
        ok: true,
        ownerFamilyCount: bestScore,
        candidate: bestCandidate
    }
}

CountMxNMRuntimeOwnerFamily(viewerWindows, frameHwnd) {
    count := 0
    seen := Map()
    for viewerWindow in viewerWindows {
        if seen.Has(viewerWindow.hwnd)
            continue
        seen[viewerWindow.hwnd] := true
        if ResolveMxNMRootOwnerHwnd(viewerWindow.hwnd)
            = frameHwnd {
            count += 1
        }
    }
    return count
}

MxNMPointInsideRuntimeFrameClient(point, frame) {
    return IsObject(point)
        && IsObject(frame)
        && point.x >= frame.clientX
        && point.x < frame.clientX + frame.clientWidth
        && point.y >= frame.clientY
        && point.y < frame.clientY + frame.clientHeight
}

ResolveMxNMRootOwnerFromPoint(screenPoint) {
    packedPoint := ((Round(screenPoint.y) & 0xFFFFFFFF) << 32)
        | (Round(screenPoint.x) & 0xFFFFFFFF)
    try pointHwnd := DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch
        pointHwnd := 0
    if !pointHwnd
        return 0
    return ResolveMxNMRootOwnerHwnd(pointHwnd)
}

ResolveMxNMRootOwnerHwnd(hwnd) {
    if !hwnd
        return 0
    try return DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", 3,
        "Ptr"
    )
    catch
        return 0
}

MxNMTargetWindowPid(hwnd) {
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

IsReusableMxNMMeasurementTargetPlan(plan, viewerExe) {
    return IsObject(plan)
        && plan.ok
        && StrLower(plan.viewerExe) = StrLower(viewerExe)
        && plan.viewerProcessPath != ""
        && IsObject(plan.mainGeometry)
        && IsObject(plan.logicalPoint)
}

MakeMxNMMeasurementTargetResult() {
    return {
        ok: false,
        code: MxNMMeasurementTargetCode.CONFIG_GEOMETRY_UNAVAILABLE,
        configCode: "",
        configReady: false,
        runtimeFrameResolved: false,
        runtimeFrameCandidateCount: 0,
        runtimeFrameOwnerFamilyCount: 0,
        runtimeToolAnchorResolved: false,
        runtimeToolAnchorHwnd: 0,
        runtimeToolAnchorUsed: false,
        runtimeToolAnchorFallbackCode: "",
        mappedImageRectResolved: false,
        layoutReady: false,
        layoutModelCount: 0,
        minimumLogicalClearance: 0,
        minimumRequiredClearance: 0,
        logicalPoint: 0,
        imageRect: 0,
        screenPoint: 0,
        actionHwnd: 0,
        actionPid: 0,
        actionClientPoint: 0
    }
}

ParseMxNMDeclaredLayoutModels(layoutEntries, mainGeometry) {
    failure := {
        ok: false,
        modelCount: 0,
        models: []
    }
    if !mainGeometry.imageSizeResolved
        return failure

    declaredCount := FindMxNMGeometryAuditNumber(
        layoutEntries,
        "ShowModelGroup",
        "ShowModelSize"
    )
    if !MxNMTargetPositiveInteger(declaredCount)
        return failure
    modelCount := Round(declaredCount.value)
    if modelCount > 100
        return failure

    clippingTolerance := Max(
        1,
        Ceil(
            Max(mainGeometry.imageWidth, mainGeometry.imageHeight)
            * 0.01
        )
    )
    models := []
    loop modelCount {
        modelIndex := A_Index
        section := "ShowModel" modelIndex
        paneCountResult := FindMxNMGeometryAuditNumber(
            layoutEntries,
            section,
            "LowWndSize"
        )
        if !MxNMTargetPositiveInteger(paneCountResult)
            return failure
        paneCount := Round(paneCountResult.value)
        if paneCount > 100
            return failure

        panes := []
        loop paneCount {
            paneIndex := A_Index
            leftResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndLeft_" paneIndex
            )
            topResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndTop_" paneIndex
            )
            widthResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndWidth_" paneIndex
            )
            heightResult := FindMxNMGeometryAuditNumber(
                layoutEntries,
                section,
                "LowWndHeight_" paneIndex
            )
            if !MxNMTargetInteger(leftResult)
                || !MxNMTargetInteger(topResult)
                || !MxNMTargetPositiveInteger(widthResult)
                || !MxNMTargetPositiveInteger(heightResult) {
                return failure
            }
            rawLeft := Round(leftResult.value)
            rawTop := Round(topResult.value)
            rawRight := rawLeft + Round(widthResult.value)
            rawBottom := rawTop + Round(heightResult.value)
            if rawLeft < -clippingTolerance
                || rawTop < -clippingTolerance
                || rawRight
                    > mainGeometry.imageWidth + clippingTolerance
                || rawBottom
                    > mainGeometry.imageHeight + clippingTolerance {
                return failure
            }
            pane := {
                left: Max(0, rawLeft),
                top: Max(0, rawTop),
                right: Min(mainGeometry.imageWidth, rawRight),
                bottom: Min(mainGeometry.imageHeight, rawBottom)
            }
            if pane.right <= pane.left || pane.bottom <= pane.top
                return failure
            panes.Push(pane)
        }
        models.Push({
            index: modelIndex,
            panes: panes
        })
    }
    return {
        ok: models.Length = modelCount,
        modelCount: modelCount,
        models: models
    }
}

MxNMTargetInteger(numberResult) {
    return numberResult.found
        && numberResult.value = Round(numberResult.value)
}

MxNMTargetPositiveInteger(numberResult) {
    return MxNMTargetInteger(numberResult)
        && numberResult.value > 0
}

FindMxNMCrossLayoutSafePoint(models, imageWidth, imageHeight) {
    minimumRequiredClearance :=
        Min(imageWidth, imageHeight) * 0.05
    candidateMap := Map()
    candidates := []
    for model in models {
        for pane in model.panes {
            candidate := {
                x: Round((pane.left + pane.right) / 2),
                y: Round((pane.top + pane.bottom) / 2)
            }
            key := candidate.x "," candidate.y
            if !candidateMap.Has(key) {
                candidateMap[key] := true
                candidates.Push(candidate)
            }
        }
    }

    bestPoint := 0
    bestClearance := -1
    for candidate in candidates {
        candidateClearance := MxNMPointClearanceAcrossLayouts(
            candidate,
            models
        )
        if candidateClearance < 0
            continue
        if candidateClearance > bestClearance
            || (candidateClearance = bestClearance
                && MxNMPointComesBefore(candidate, bestPoint)) {
            bestPoint := candidate
            bestClearance := candidateClearance
        }
    }
    if !IsObject(bestPoint)
        || bestClearance < minimumRequiredClearance {
        return {
            ok: false,
            point: 0,
            minimumClearance: Max(0, bestClearance),
            minimumRequiredClearance: minimumRequiredClearance
        }
    }
    return {
        ok: true,
        point: bestPoint,
        minimumClearance: bestClearance,
        minimumRequiredClearance: minimumRequiredClearance
    }
}

MxNMPointClearanceAcrossLayouts(point, models) {
    minimumClearance := 0x7FFFFFFF
    for model in models {
        bestModelClearance := -1
        for pane in model.panes {
            if !MxNMPointStrictlyInsideRect(point, pane)
                continue
            clearance := Min(
                point.x - pane.left,
                pane.right - point.x,
                point.y - pane.top,
                pane.bottom - point.y
            )
            bestModelClearance := Max(
                bestModelClearance,
                clearance
            )
        }
        if bestModelClearance < 0
            return -1
        minimumClearance := Min(
            minimumClearance,
            bestModelClearance
        )
    }
    return minimumClearance
}

MxNMPointComesBefore(candidate, currentPoint) {
    if !IsObject(currentPoint)
        return true
    return candidate.y < currentPoint.y
        || (candidate.y = currentPoint.y
            && candidate.x < currentPoint.x)
}

MxNMPointStrictlyInsideRect(point, rect) {
    return point.x > rect.left
        && point.x < rect.right
        && point.y > rect.top
        && point.y < rect.bottom
}

MapMxNMLogicalPointToRuntimeRect(point, mainGeometry, runtimeRect) {
    return {
        x: runtimeRect.left + Round(
            point.x
            * (runtimeRect.right - runtimeRect.left)
            / mainGeometry.imageWidth
        ),
        y: runtimeRect.top + Round(
            point.y
            * (runtimeRect.bottom - runtimeRect.top)
            / mainGeometry.imageHeight
        )
    }
}

MxNMPointInsideRect(point, rect) {
    return IsObject(point)
        && IsObject(rect)
        && point.x >= rect.left
        && point.x < rect.right
        && point.y >= rect.top
        && point.y < rect.bottom
}

ResolveMxNMActionWindowFromPoint(
    viewerExe,
    screenPoint,
    runtimeFrameHwnd
) {
    packedPoint := ((Round(screenPoint.y) & 0xFFFFFFFF) << 32)
        | (Round(screenPoint.x) & 0xFFFFFFFF)
    try pointHwnd := DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch {
        pointHwnd := 0
    }
    if !pointHwnd {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.ACTION_WINDOW_INVALID
        }
    }
    try rootHwnd := DllCall(
        "User32\GetAncestor",
        "Ptr", pointHwnd,
        "UInt", 2,
        "Ptr"
    )
    catch {
        rootHwnd := 0
    }
    if !rootHwnd
        rootHwnd := pointHwnd
    rootOwnerHwnd := ResolveMxNMRootOwnerHwnd(pointHwnd)
    if !rootOwnerHwnd
        rootOwnerHwnd := rootHwnd

    return ValidateMxNMActionWindow(
        viewerExe,
        screenPoint,
        runtimeFrameHwnd,
        rootHwnd,
        rootOwnerHwnd
    )
}

ResolveMxNMActionWindowFromAnchor(
    viewerExe,
    screenPoint,
    runtimeFrameHwnd,
    actionRootHwnd
) {
    pointHwnd := ResolveMxNMWindowFromScreenPoint(screenPoint)
    if !pointHwnd
        || !MxNMTargetWindowIsSameOrDescendant(
            pointHwnd,
            actionRootHwnd
        ) {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.ACTION_WINDOW_INVALID
        }
    }
    return ValidateMxNMActionWindow(
        viewerExe,
        screenPoint,
        runtimeFrameHwnd,
        pointHwnd,
        ResolveMxNMRootOwnerHwnd(pointHwnd)
    )
}

ResolveMxNMWindowFromScreenPoint(screenPoint) {
    packedPoint := ((Round(screenPoint.y) & 0xFFFFFFFF) << 32)
        | (Round(screenPoint.x) & 0xFFFFFFFF)
    try return DllCall(
        "User32\WindowFromPoint",
        "Int64", packedPoint,
        "Ptr"
    )
    catch
        return 0
}

MxNMTargetWindowIsSameOrDescendant(hwnd, ancestorHwnd) {
    if !hwnd || !ancestorHwnd
        return false
    seen := Map()
    while hwnd && !seen.Has(hwnd) {
        if hwnd = ancestorHwnd
            return true
        seen[hwnd] := true
        hwnd := MxNMTargetParentHwnd(hwnd)
    }
    return false
}

ValidateMxNMActionWindow(
    viewerExe,
    screenPoint,
    runtimeFrameHwnd,
    rootHwnd,
    rootOwnerHwnd
) {
    try processName := WinGetProcessName("ahk_id " rootHwnd)
    catch {
        processName := ""
    }
    try actionPid := WinGetPID("ahk_id " rootHwnd)
    catch {
        actionPid := 0
    }
    runtimePid := MxNMTargetWindowPid(runtimeFrameHwnd)
    if StrLower(processName) != StrLower(viewerExe)
        || !actionPid
        || actionPid != runtimePid
        || rootOwnerHwnd != runtimeFrameHwnd {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.ACTION_WINDOW_INVALID
        }
    }
    clientRect := MxNMTargetClientRectScreen(rootHwnd)
    if !IsObject(clientRect)
        || !MxNMPointInsideRect(screenPoint, clientRect) {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.POINT_OUT_OF_BOUNDS
        }
    }
    clientPoint := MxNMTargetScreenToClient(
        rootHwnd,
        screenPoint
    )
    if !IsObject(clientPoint) {
        return {
            ok: false,
            code: MxNMMeasurementTargetCode.POINT_OUT_OF_BOUNDS
        }
    }
    return {
        ok: true,
        code: MxNMMeasurementTargetCode.READY_FOR_FIELD_VALIDATION,
        hwnd: rootHwnd,
        pid: actionPid,
        clientPoint: clientPoint
    }
}

MxNMTargetScreenToClient(hwnd, screenPoint) {
    pointBuffer := Buffer(8, 0)
    NumPut("Int", screenPoint.x, pointBuffer, 0)
    NumPut("Int", screenPoint.y, pointBuffer, 4)
    if !DllCall(
        "User32\ScreenToClient",
        "Ptr", hwnd,
        "Ptr", pointBuffer.Ptr,
        "Int"
    ) {
        return 0
    }
    return {
        x: NumGet(pointBuffer, 0, "Int"),
        y: NumGet(pointBuffer, 4, "Int")
    }
}

MxNMTargetClientRectScreen(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall(
        "User32\GetClientRect",
        "Ptr", hwnd,
        "Ptr", rectBuffer.Ptr,
        "Int"
    ) {
        return 0
    }
    topLeft := Buffer(8, 0)
    bottomRight := Buffer(8, 0)
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
    return {
        left: NumGet(topLeft, 0, "Int"),
        top: NumGet(topLeft, 4, "Int"),
        right: NumGet(bottomRight, 0, "Int"),
        bottom: NumGet(bottomRight, 4, "Int")
    }
}
