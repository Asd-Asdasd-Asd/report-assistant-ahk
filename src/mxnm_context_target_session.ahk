class MxNMContextTargetSessionCode {
    static READY := "CONTEXT_SESSION_READY"
    static VIEWER_NOT_FOUND := "CONTEXT_VIEWER_NOT_FOUND"
    static DISCOVERY_FAILED := "CONTEXT_SURFACE_DISCOVERY_FAILED"
    static FAST_VALIDATION_FAILED := "CONTEXT_FAST_VALIDATION_FAILED"
    static UNEXPECTED_ERROR := "CONTEXT_SESSION_UNEXPECTED_ERROR"
}

class MxNMContextTargetSessionProvider {
    static CachedSession := 0
    static Generation := 0

    static Resolve(viewerExe := "", options := 0) {
        try return this.ResolveInternal(viewerExe, options)
        catch {
            this.CachedSession := 0
            return MakeMxNMContextTargetFailure(
                MxNMContextTargetSessionCode.UNEXPECTED_ERROR
            )
        }
    }

    static ResolveInternal(viewerExe := "", options := 0) {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        forceRefresh := MeasurementOption(
            options,
            "forceTargetPlanRefresh",
            MeasurementOption(options, "forceTargetRefresh", false)
        )
        if !forceRefresh && IsObject(this.CachedSession) {
            fastResult := ValidateMxNMContextTargetSession(
                this.CachedSession,
                viewerExe,
                options
            )
            if fastResult.ok
                return BuildMxNMContextTargetResult(
                    this.CachedSession,
                    fastResult,
                    true
                )
        }

        this.CachedSession := 0
        discovery := DiscoverMxNMContextTargetSession(
            viewerExe,
            options,
            this.Generation + 1
        )
        if !discovery.ok
            return MakeMxNMContextTargetFailure(
                discovery.code,
                discovery
            )
        this.Generation += 1
        discovery.session.generation := this.Generation
        this.CachedSession := discovery.session

        retryResult := ValidateMxNMContextTargetSession(
            this.CachedSession,
            viewerExe,
            options
        )
        if retryResult.ok
            return BuildMxNMContextTargetResult(
                this.CachedSession,
                retryResult,
                false
            )
        this.CachedSession := 0
        return MakeMxNMContextTargetFailure(
            MxNMContextTargetSessionCode.FAST_VALIDATION_FAILED
        )
    }

    static Invalidate() {
        this.CachedSession := 0
    }
}

DiscoverMxNMContextTargetSession(viewerExe, options, generation) {
    identity := ResolveMxNMContextViewerIdentity(viewerExe, options)
    if !identity.ok {
        return {
            ok: false,
            code: identity.code,
            session: 0
        }
    }
    surfaceResult := DiscoverMxNMContextSurface(identity)
    if !surfaceResult.ok {
        return {
            ok: false,
            code: MxNMContextTargetSessionCode.DISCOVERY_FAILED,
            session: 0,
            candidateCount: surfaceResult.candidateCount,
            pointProbeCount: surfaceResult.pointProbeCount
        }
    }
    point := surfaceResult.point
    surfaceRect := surfaceResult.surfaceRect
    return {
        ok: true,
        code: MxNMContextTargetSessionCode.READY,
        session: {
            viewerExe: viewerExe,
            processPath: identity.processPath,
            pid: identity.pid,
            rootHwnd: identity.rootHwnd,
            surfaceHwnd: surfaceResult.surfaceHwnd,
            surfaceClientRect: surfaceRect,
            safePointNormalized: {
                x: (point.x - surfaceRect.left)
                    / (surfaceRect.right - surfaceRect.left),
                y: (point.y - surfaceRect.top)
                    / (surfaceRect.bottom - surfaceRect.top)
            },
            safePointScreen: point,
            discoveryMethod: surfaceResult.discoveryMethod,
            generation: generation,
            candidateCount: surfaceResult.candidateCount,
            pointProbeCount: surfaceResult.pointProbeCount
        }
    }
}

ResolveMxNMContextViewerIdentity(viewerExe, options := 0) {
    expectedHwnd := MeasurementOption(options, "expectedViewerHwnd", 0)
    expectedPid := MeasurementOption(options, "expectedViewerPid", 0)
    if expectedHwnd {
        expectedIdentity := CaptureMxNMContextViewerIdentity(
            expectedHwnd,
            viewerExe
        )
        if expectedIdentity.ok
            && (!expectedPid || expectedIdentity.pid = expectedPid) {
            expectedIdentity.discoveryMethod := "EXPECTED_WINDOW_ROOT"
            return expectedIdentity
        }
    }

    try foregroundHwnd := WinExist("A")
    catch
        foregroundHwnd := 0
    foregroundIdentity := CaptureMxNMContextViewerIdentity(
        foregroundHwnd,
        viewerExe
    )
    if foregroundIdentity.ok {
        foregroundIdentity.discoveryMethod := "FOREGROUND_VIEWER_ROOT"
        return foregroundIdentity
    }

    try viewerWindows := WinGetList("ahk_exe " viewerExe)
    catch
        viewerWindows := []
    identities := Map()
    for hwnd in viewerWindows {
        identity := CaptureMxNMContextViewerIdentity(hwnd, viewerExe)
        if !identity.ok
            continue
        key := String(identity.rootHwnd)
        if !identities.Has(key)
            identities[key] := identity
    }
    if identities.Count = 0 {
        return {
            ok: false,
            code: MxNMContextTargetSessionCode.VIEWER_NOT_FOUND,
            pid: 0,
            rootHwnd: 0,
            processPath: ""
        }
    }

    best := 0
    bestArea := -1
    for _, identity in identities {
        rootRect := MxNMTargetClientRectScreen(identity.rootHwnd)
        area := IsObject(rootRect)
            ? Max(0, rootRect.right - rootRect.left)
                * Max(0, rootRect.bottom - rootRect.top)
            : 0
        if area > bestArea {
            best := identity
            bestArea := area
        }
    }
    best.discoveryMethod := "LARGEST_VISIBLE_VIEWER_ROOT"
    return best
}

CaptureMxNMContextViewerIdentity(hwnd, viewerExe) {
    failure := {
        ok: false,
        code: MxNMContextTargetSessionCode.VIEWER_NOT_FOUND,
        pid: 0,
        rootHwnd: 0,
        processPath: "",
        discoveryMethod: ""
    }
    if !hwnd || !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        return failure
    try processName := WinGetProcessName("ahk_id " hwnd)
    catch
        processName := ""
    if StrLower(processName) != StrLower(viewerExe)
        return failure
    try pid := WinGetPID("ahk_id " hwnd)
    catch
        pid := 0
    try processPath := WinGetProcessPath("ahk_id " hwnd)
    catch
        processPath := ""
    rootHwnd := ResolveMxNMRootOwnerHwnd(hwnd)
    if !pid || !rootHwnd || processPath = ""
        return failure
    if MxNMTargetWindowPid(rootHwnd) != pid
        return failure
    failure.ok := true
    failure.code := MxNMContextTargetSessionCode.READY
    failure.pid := pid
    failure.rootHwnd := rootHwnd
    failure.processPath := processPath
    return failure
}

DiscoverMxNMContextSurface(identity) {
    failure := {
        ok: false,
        surfaceHwnd: 0,
        surfaceRect: 0,
        point: 0,
        actionHwnd: 0,
        candidateCount: 0,
        pointProbeCount: 0,
        discoveryMethod: ""
    }
    rootRect := MxNMTargetClientRectScreen(identity.rootHwnd)
    if !IsObject(rootRect)
        return failure
    candidates := []
    seen := Map()
    cursor := GetMxNMContextCursorScreenPoint()
    callback := CallbackCreate(
        CollectMxNMContextSurfaceCandidate.Bind(
            identity,
            rootRect,
            cursor,
            seen,
            candidates
        ),
        "Fast",
        2
    )
    try {
        try topLevelWindows := WinGetList("ahk_pid " identity.pid)
        catch
            topLevelWindows := [identity.rootHwnd]
        if topLevelWindows.Length = 0
            topLevelWindows := [identity.rootHwnd]
        for topHwnd in topLevelWindows {
            if ResolveMxNMRootOwnerHwnd(topHwnd)
                != identity.rootHwnd {
                continue
            }
            CollectMxNMContextSurfaceCandidate(
                identity,
                rootRect,
                cursor,
                seen,
                candidates,
                topHwnd
            )
            DllCall(
                "User32\EnumChildWindows",
                "Ptr", topHwnd,
                "Ptr", callback,
                "Ptr", 0,
                "Int"
            )
        }
    } finally CallbackFree(callback)
    failure.candidateCount := candidates.Length

    tried := Map()
    totalProbeCount := 0
    while tried.Count < candidates.Length {
        best := 0
        for candidate in candidates {
            key := String(candidate.hwnd)
            if tried.Has(key)
                continue
            if !IsObject(best)
                || candidate.score > best.score
                || (candidate.score = best.score
                    && candidate.area > best.area) {
                best := candidate
            }
        }
        if !IsObject(best)
            break
        tried[String(best.hwnd)] := true
        pointResult := FindMxNMContextSurfaceSafePoint(
            best,
            identity
        )
        totalProbeCount += pointResult.probeCount
        if !pointResult.ok
            continue
        return {
            ok: true,
            surfaceHwnd: best.hwnd,
            surfaceRect: best.rect,
            point: pointResult.point,
            actionHwnd: pointResult.actionHwnd,
            candidateCount: candidates.Length,
            pointProbeCount: totalProbeCount,
            discoveryMethod: "RUNTIME_SURFACE_SCORE_"
                pointResult.discoveryMethod
        }
    }
    failure.pointProbeCount := totalProbeCount
    return failure
}

CollectMxNMContextSurfaceCandidate(
    identity,
    rootRect,
    cursor,
    seen,
    candidates,
    hwnd,
    *
) {
    if !hwnd || seen.Has(hwnd)
        return true
    seen[hwnd] := true
    if !DllCall("User32\IsWindow", "Ptr", hwnd, "Int")
        || !DllCall("User32\IsWindowVisible", "Ptr", hwnd, "Int")
        || MxNMTargetWindowPid(hwnd) != identity.pid
        || ResolveMxNMRootOwnerHwnd(hwnd) != identity.rootHwnd {
        return true
    }
    rect := MxNMTargetClientRectScreen(hwnd)
    if !IsObject(rect)
        return true
    width := rect.right - rect.left
    height := rect.bottom - rect.top
    if width <= 0 || height <= 0
        return true
    visibleArea := MxNMContextVisibleScreenArea(rect)
    if visibleArea <= 0
        return true
    rootArea := Max(
        1,
        (rootRect.right - rootRect.left)
            * (rootRect.bottom - rootRect.top)
    )
    area := width * height
    score := Round(1000 * Min(1, area / rootArea))
    if width >= 240 && height >= 160
        score += 250
    aspectBalance := Min(width, height) / Max(width, height)
    score += aspectBalance >= 0.18 ? 100 : -500
    if hwnd = identity.rootHwnd
        score -= 600
    className := MxNMContextWindowClass(hwnd)
    if StrLower(className) = "#32770"
        score += 60
    if MxNMContextRectContainsPoint(rect, cursor)
        score += 500
    if MxNMContextClassLooksLikeToolChrome(className)
        score -= 800
    depth := MxNMContextWindowDepth(hwnd, identity.rootHwnd)
    score -= Min(200, depth * 20)
    candidates.Push({
        hwnd: hwnd,
        rect: rect,
        width: width,
        height: height,
        area: area,
        score: score,
        className: className,
        depth: depth
    })
    return true
}

FindMxNMContextSurfaceSafePoint(candidate, identity) {
    preferred := [
        {x: 0.65, y: 0.35},
        {x: 0.75, y: 0.25},
        {x: 0.25, y: 0.25},
        {x: 0.75, y: 0.75},
        {x: 0.25, y: 0.75}
    ]
    tried := Map()
    probeCount := 0
    for normalized in preferred {
        key := normalized.x "," normalized.y
        tried[key] := true
        probeCount += 1
        validated := ValidateMxNMContextSurfacePoint(
            candidate,
            identity,
            normalized
        )
        if validated.ok {
            validated.probeCount := probeCount
            validated.discoveryMethod := "PREFERRED_POINT"
            return validated
        }
    }
    denseRatios := [0.20, 0.35, 0.50, 0.65, 0.80]
    for yRatio in denseRatios {
        for xRatio in denseRatios {
            key := xRatio "," yRatio
            if tried.Has(key)
                continue
            probeCount += 1
            validated := ValidateMxNMContextSurfacePoint(
                candidate,
                identity,
                {x: xRatio, y: yRatio}
            )
            if validated.ok {
                validated.probeCount := probeCount
                validated.discoveryMethod := "DENSE_POINT"
                return validated
            }
        }
    }
    return {
        ok: false,
        point: 0,
        actionHwnd: 0,
        probeCount: probeCount,
        discoveryMethod: "NO_POINT"
    }
}

ValidateMxNMContextSurfacePoint(candidate, identity, normalized) {
    point := MxNMContextPointFromNormalized(candidate.rect, normalized)
    minimumClearance := Max(
        6,
        Min(16, Round(Min(candidate.width, candidate.height) * 0.01))
    )
    if MxNMPointClearanceInsideRect(point, candidate.rect)
        < minimumClearance {
        return {ok: false, point: 0, actionHwnd: 0}
    }
    actionHwnd := ResolveMxNMWindowFromScreenPoint(point)
    if !actionHwnd
        || !MxNMTargetWindowIsSameOrDescendant(
            actionHwnd,
            candidate.hwnd
        )
        || MxNMTargetWindowPid(actionHwnd) != identity.pid
        || ResolveMxNMRootOwnerHwnd(actionHwnd)
            != identity.rootHwnd {
        return {ok: false, point: 0, actionHwnd: 0}
    }
    actionRect := MxNMTargetClientRectScreen(actionHwnd)
    if !IsObject(actionRect)
        || !MxNMPointInsideRect(point, actionRect) {
        return {ok: false, point: 0, actionHwnd: 0}
    }
    return {ok: true, point: point, actionHwnd: actionHwnd}
}

ValidateMxNMContextTargetSession(session, viewerExe, options := 0) {
    failure := {
        ok: false,
        screenPoint: 0,
        actionHwnd: 0,
        actionPid: 0,
        actionClientPoint: 0
    }
    if !IsObject(session)
        || StrLower(session.viewerExe) != StrLower(viewerExe)
        || !session.rootHwnd
        || !session.surfaceHwnd
        || !DllCall("User32\IsWindow", "Ptr", session.rootHwnd, "Int")
        || !DllCall("User32\IsWindow", "Ptr", session.surfaceHwnd, "Int")
        || !DllCall(
            "User32\IsWindowVisible",
            "Ptr", session.surfaceHwnd,
            "Int"
        ) {
        return failure
    }
    if MxNMTargetWindowPid(session.rootHwnd) != session.pid
        || MxNMTargetWindowPid(session.surfaceHwnd) != session.pid
        || ResolveMxNMRootOwnerHwnd(session.surfaceHwnd)
            != session.rootHwnd {
        return failure
    }
    try currentPath := WinGetProcessPath("ahk_id " session.rootHwnd)
    catch
        currentPath := ""
    if currentPath = ""
        || StrLower(currentPath) != StrLower(session.processPath) {
        return failure
    }

    expectedPid := MeasurementOption(options, "expectedViewerPid", 0)
    expectedHwnd := MeasurementOption(options, "expectedViewerHwnd", 0)
    if expectedPid && expectedPid != session.pid
        return failure
    if expectedHwnd {
        expectedIdentity := CaptureMxNMContextViewerIdentity(
            expectedHwnd,
            viewerExe
        )
        if !expectedIdentity.ok
            || expectedIdentity.pid != session.pid
            || expectedIdentity.rootHwnd != session.rootHwnd {
            return failure
        }
    }

    try foregroundHwnd := WinExist("A")
    catch
        foregroundHwnd := 0
    foregroundIdentity := CaptureMxNMContextViewerIdentity(
        foregroundHwnd,
        viewerExe
    )
    if foregroundIdentity.ok
        && (foregroundIdentity.pid != session.pid
            || foregroundIdentity.rootHwnd != session.rootHwnd) {
        return failure
    }

    surfaceRect := MxNMTargetClientRectScreen(session.surfaceHwnd)
    if !IsObject(surfaceRect)
        || surfaceRect.right <= surfaceRect.left
        || surfaceRect.bottom <= surfaceRect.top {
        return failure
    }
    candidate := {
        hwnd: session.surfaceHwnd,
        rect: surfaceRect,
        width: surfaceRect.right - surfaceRect.left,
        height: surfaceRect.bottom - surfaceRect.top
    }
    validated := ValidateMxNMContextSurfacePoint(
        candidate,
        {
            pid: session.pid,
            rootHwnd: session.rootHwnd
        },
        session.safePointNormalized
    )
    if !validated.ok
        return failure
    clientPoint := MxNMTargetScreenToClient(
        validated.actionHwnd,
        validated.point
    )
    if !IsObject(clientPoint)
        return failure
    session.surfaceClientRect := surfaceRect
    session.safePointScreen := validated.point
    return {
        ok: true,
        screenPoint: validated.point,
        actionHwnd: validated.actionHwnd,
        actionPid: session.pid,
        actionClientPoint: clientPoint
    }
}

BuildMxNMContextTargetResult(session, validation, cacheHit) {
    result := MakeMxNMContextTargetFailure(
        MxNMContextTargetSessionCode.READY
    )
    result.ok := true
    result.code := MxNMContextTargetSessionCode.READY
    result.configCode := MxNMContextTargetSessionCode.READY
    result.screenPoint := validation.screenPoint
    result.actionHwnd := validation.actionHwnd
    result.actionPid := validation.actionPid
    result.actionClientPoint := validation.actionClientPoint
    result.runtimePointSource := session.discoveryMethod
    result.sessionCacheHit := cacheHit = true
    result.sessionGeneration := session.generation
    result.sessionRootHwnd := session.rootHwnd
    result.sessionSurfaceHwnd := session.surfaceHwnd
    result.sessionCandidateCount := session.candidateCount
    result.sessionPointProbeCount := session.pointProbeCount
    return result
}

MakeMxNMContextTargetFailure(code, details := 0) {
    result := {
        ok: false,
        code: String(code),
        configCode: String(code),
        configReady: false,
        runtimeFrameResolved: false,
        layoutCode: "NOT_REQUIRED",
        layoutReady: false,
        layoutModelCount: 0,
        runtimeFrameCandidateCount: 0,
        runtimeFrameOwnerFamilyCount: 0,
        runtimeToolAnchorResolved: false,
        runtimeToolAnchorHwnd: 0,
        runtimeToolAnchorUsed: false,
        runtimeToolAnchorFallbackCode: "NOT_REQUIRED",
        runtimeSurfaceSelectionCode: "",
        runtimePointSource: "",
        mappedImageRectResolved: false,
        runtimeSurfaceFallbackEligible: false,
        minimumLogicalClearance: 0,
        minimumRequiredClearance: 0,
        logicalPoint: 0,
        imageRect: 0,
        screenPoint: 0,
        actionHwnd: 0,
        actionPid: 0,
        actionClientPoint: 0,
        sessionCacheHit: false,
        sessionGeneration: 0,
        sessionRootHwnd: 0,
        sessionSurfaceHwnd: 0,
        sessionCandidateCount: 0,
        sessionPointProbeCount: 0
    }
    if IsObject(details) {
        if details.HasOwnProp("candidateCount")
            result.sessionCandidateCount := details.candidateCount
        if details.HasOwnProp("pointProbeCount")
            result.sessionPointProbeCount := details.pointProbeCount
    }
    return result
}

MxNMContextPointFromNormalized(rect, normalized) {
    return {
        x: rect.left + Round(
            (rect.right - rect.left) * normalized.x
        ),
        y: rect.top + Round(
            (rect.bottom - rect.top) * normalized.y
        )
    }
}

GetMxNMContextCursorScreenPoint() {
    buffer := Buffer(8, 0)
    if DllCall("User32\GetCursorPos", "Ptr", buffer.Ptr, "Int") {
        return {
            x: NumGet(buffer, 0, "Int"),
            y: NumGet(buffer, 4, "Int")
        }
    }
    return {x: -2147483648, y: -2147483648}
}

MxNMContextRectContainsPoint(rect, point) {
    return IsObject(rect)
        && IsObject(point)
        && point.x >= rect.left
        && point.x < rect.right
        && point.y >= rect.top
        && point.y < rect.bottom
}

MxNMContextVisibleScreenArea(rect) {
    left := SysGet(76)
    top := SysGet(77)
    right := left + SysGet(78)
    bottom := top + SysGet(79)
    width := Max(0, Min(rect.right, right) - Max(rect.left, left))
    height := Max(0, Min(rect.bottom, bottom) - Max(rect.top, top))
    return width * height
}

MxNMContextClassLooksLikeToolChrome(className) {
    normalized := StrLower(String(className))
    return normalized = "button"
        || normalized = "toolbarwindow32"
        || normalized = "msctls_statusbar32"
        || normalized = "rebarwindow32"
}

MxNMContextWindowClass(hwnd) {
    if !hwnd
        return ""
    buffer := Buffer(512 * 2, 0)
    try length := DllCall(
        "User32\GetClassNameW",
        "Ptr", hwnd,
        "Ptr", buffer.Ptr,
        "Int", 512,
        "Int"
    )
    catch
        return ""
    return length > 0 ? StrGet(buffer, length, "UTF-16") : ""
}

MxNMContextWindowDepth(hwnd, rootHwnd) {
    if hwnd = rootHwnd
        return 0
    depth := 0
    seen := Map()
    while hwnd && !seen.Has(hwnd) && depth < 32 {
        seen[hwnd] := true
        hwnd := MxNMTargetParentHwnd(hwnd)
        depth += 1
        if hwnd = rootHwnd
            return depth
    }
    return 32
}
