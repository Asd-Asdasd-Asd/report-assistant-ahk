class MxNMMeasurementProvider {
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
        viewerExe := MeasurementOption(
            options,
            "viewerExe",
            MxNMConfigGeometryDefaults.ViewerExe
        )
        return MxNMContextTargetSessionProvider.Resolve(
            viewerExe,
            options
        )
    }

    static PrepareTargetPlan(options := 0) {
        return this.ResolveTarget(options).ok
    }

    static InvalidateTargetSession() {
        MxNMContextTargetSessionProvider.Invalidate()
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
    result.context["targetSessionCacheHit"] := target.sessionCacheHit
    result.context["targetSessionGeneration"] := target.sessionGeneration
    result.context["targetSessionRootHwnd"] := target.sessionRootHwnd
    result.context["targetSessionSurfaceHwnd"] :=
        target.sessionSurfaceHwnd
    result.context["targetSessionCandidateCount"] :=
        target.sessionCandidateCount
    result.context["targetSessionPointProbeCount"] :=
        target.sessionPointProbeCount
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

MakeMxNMTargetFailureMeasurement(
    target,
    requestedType := MeasurementType.SUVMAX,
    targetResolutionMs := 0,
    totalReadMs := 0
) {
    failureReason := target.configCode = MxNMConfigGeometryCode.VIEWER_NOT_FOUND
        || target.code = MxNMContextTargetSessionCode.VIEWER_NOT_FOUND
        ? MeasurementFailureReason.VIEWER_NOT_FOUND
        : MeasurementFailureReason.IMAGE_POINT_UNAVAILABLE
    context := Map(
        "targetCode", target.code,
        "targetConfigCode", target.configCode,
        "targetActionHwnd", 0,
        "targetActionPid", 0,
        "targetSessionCandidateCount", target.sessionCandidateCount,
        "targetSessionPointProbeCount", target.sessionPointProbeCount,
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
