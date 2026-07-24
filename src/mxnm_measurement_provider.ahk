class MxNMMeasurementProvider {
    static CachedTarget := 0

    static ReadSuvMax(options := 0) {
        return ReadMxNMMeasurementWithTarget(
            BuildSuvMaxMeasurementCommandSpec(),
            options
        )
    }

    static ReadLineAxes(options := 0) {
        return ReadMxNMMeasurementWithTarget(
            BuildLineAxesMeasurementCommandSpec(),
            options
        )
    }

    static ResolveTarget(options := 0) {
        forceRefresh := MeasurementOption(
            options, "forceTargetRefresh", false
        )
        if !forceRefresh && IsReusableMxNMMeasurementTarget(this.CachedTarget)
            return this.CachedTarget

        this.CachedTarget := 0
        target := MxNMMeasurementTargetResolver.Resolve(
            MeasurementOption(
                options,
                "viewerExe",
                MxNMConfigGeometryDefaults.ViewerExe
            )
        )
        if target.ok {
            target.cacheClientRect := MxNMTargetClientRectScreen(
                target.actionHwnd
            )
            if IsObject(target.cacheClientRect)
                this.CachedTarget := target
        }
        return target
    }

    static HasReusableTarget() {
        return IsReusableMxNMMeasurementTarget(this.CachedTarget)
    }

    static WarmTarget() {
        return this.ResolveTarget().ok
    }
}

ReadMxNMMeasurementWithTarget(spec, options := 0) {
    requestedMeasurementType := spec.measurementType
    startedAt := A_TickCount
    targetStartedAt := A_TickCount
    target := MxNMMeasurementProvider.ResolveTarget(options)
    targetResolutionMs := A_TickCount - targetStartedAt
    if !target.ok
        return MakeMxNMTargetFailureMeasurement(
            target,
            requestedMeasurementType,
            targetResolutionMs,
            A_TickCount - startedAt
        )

    providerOptions := CloneMeasurementOptions(options)
    expectedViewerHwnd := MeasurementOption(
        options, "expectedViewerHwnd", 0
    )
    expectedViewerPid := MeasurementOption(
        options, "expectedViewerPid", 0
    )
    if (expectedViewerHwnd && target.actionHwnd != expectedViewerHwnd)
        || (expectedViewerPid && target.actionPid != expectedViewerPid) {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.VIEWER_TARGET_CHANGED,
            Map(
                "targetCode", target.code,
                "targetActionHwnd", target.actionHwnd,
                "targetActionPid", target.actionPid,
                "targetResolutionMs", targetResolutionMs,
                "totalReadMs", A_TickCount - startedAt
            )
        )
    }
    providerOptions["imageScreenPoint"] := target.screenPoint
    providerOptions["expectedViewerHwnd"] := target.actionHwnd
    providerOptions["expectedViewerPid"] := target.actionPid
    result := ContextMeasurementProvider.ReadMeasurement(
        spec,
        providerOptions
    )
    result.context["targetCode"] := target.code
    result.context["targetActionHwnd"] := target.actionHwnd
    result.context["targetActionPid"] := target.actionPid
    result.context["targetScreenX"] := target.screenPoint.x
    result.context["targetScreenY"] := target.screenPoint.y
    result.context["targetResolutionMs"] := targetResolutionMs
    result.context["totalReadMs"] := A_TickCount - startedAt
    return result
}

CloneMeasurementOptions(options := 0) {
    clone := Map()
    if Type(options) = "Map" {
        for key, value in options
            clone[key] := value
    }
    return clone
}

IsReusableMxNMMeasurementTarget(target) {
    if !IsObject(target) || !target.ok
        || !target.actionHwnd || !target.actionPid
        || !target.HasOwnProp("cacheClientRect")
        || !IsObject(target.cacheClientRect)
        return false
    if !WinExist("ahk_id " target.actionHwnd)
        return false
    try currentPid := WinGetPID("ahk_id " target.actionHwnd)
    catch {
        return false
    }
    try processName := WinGetProcessName("ahk_id " target.actionHwnd)
    catch {
        return false
    }
    if currentPid != target.actionPid
        || StrLower(processName) != StrLower(MxNMConfigGeometryDefaults.ViewerExe)
        return false
    currentRect := MxNMTargetClientRectScreen(target.actionHwnd)
    return IsObject(currentRect)
        && MxNMMeasurementRectsEqual(currentRect, target.cacheClientRect)
        && MxNMPointInsideRect(target.screenPoint, currentRect)
}

MxNMMeasurementRectsEqual(leftRect, rightRect) {
    return leftRect.left = rightRect.left
        && leftRect.top = rightRect.top
        && leftRect.right = rightRect.right
        && leftRect.bottom = rightRect.bottom
}

MakeMxNMTargetFailureMeasurement(
    target,
    requestedType := MeasurementType.SUVMAX,
    targetResolutionMs := 0,
    totalReadMs := 0
) {
    failureReason := target.configCode = MxNMConfigGeometryCode.VIEWER_NOT_FOUND
        ? MeasurementFailureReason.VIEWER_NOT_FOUND
        : MeasurementFailureReason.IMAGE_POINT_UNAVAILABLE
    context := Map(
        "targetCode", target.code,
        "targetConfigCode", target.configCode,
        "targetActionHwnd", 0,
        "targetActionPid", 0,
        "targetResolutionMs", targetResolutionMs,
        "totalReadMs", totalReadMs
    )
    return MakeMeasurementResult(
        MeasurementState.AUTOMATION_FAILED,
        requestedType,
        "",
        "",
        MeasurementSource.MXNM_CONTEXT_COMMAND,
        failureReason,
        context
    )
}
