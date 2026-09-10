class AutomationDiagnosticDefaults {
    static SchemaVersion := 1
    static LogDirectoryName := "logs"
    static LogFileName := "automation-events.log"
    static MaxFileBytes := 1048576
    static RotatedFileCount := 3
    static DiagnosticWindowMs := 600000
    static SnapshotScanLineCount := 240
    static SnapshotRecentSummaryCount := 12
    static SnapshotFailureSummaryCount := 4
    static SnapshotDetailedEventCount := 30
    static SnapshotViewerFailureCount := 12
}

class AutomationDiagnosticSession {
    static SessionId := ""
    static NextOperationId := 0
    static DiagnosticUntilTick := 0
    static FirstOperationPending := true
    static SeenTargetProcesses := Map()
    static TargetKeys := Map()
    static TargetGenerations := Map()

    static EnsureStarted() {
        if this.SessionId != ""
            return this.SessionId
        this.SessionId := FormatTime(, "yyyyMMdd-HHmmss") "-"
            . Format("{:04X}", Random(0, 65535))
        return this.SessionId
    }

    static NewOperationId() {
        this.EnsureStarted()
        this.NextOperationId += 1
        return this.NextOperationId
    }

    static ConsumeFirstSessionUse() {
        firstUse := this.FirstOperationPending
        this.FirstOperationPending := false
        return firstUse
    }

    static ObserveTarget(action, targetPid, targetHwnd) {
        pidKey := String(targetPid)
        firstTargetProcessUse := targetPid > 0
            && !this.SeenTargetProcesses.Has(pidKey)
        if targetPid > 0
            this.SeenTargetProcesses[pidKey] := true

        actionKey := String(action)
        targetKey := targetPid ":" targetHwnd
        generation := this.TargetGenerations.Has(actionKey)
            ? this.TargetGenerations[actionKey]
            : 0
        if !this.TargetKeys.Has(actionKey)
            || this.TargetKeys[actionKey] != targetKey {
            generation += 1
            this.TargetKeys[actionKey] := targetKey
            this.TargetGenerations[actionKey] := generation
        }
        return {
            firstTargetProcessUse: firstTargetProcessUse,
            targetGeneration: generation
        }
    }

    static DetailedModeActive() {
        return this.DiagnosticUntilTick > 0
            && A_TickCount < this.DiagnosticUntilTick
    }

    static EnableDetailedMode(durationMs := 0) {
        if durationMs <= 0
            durationMs := AutomationDiagnosticDefaults.DiagnosticWindowMs
        this.DiagnosticUntilTick := A_TickCount + durationMs
        return this.DiagnosticUntilTick
    }
}

class AutomationDiagnosticOperation {
    __New(action) {
        this.Action := String(action)
        this.OperationId := AutomationDiagnosticSession.NewOperationId()
        this.SessionId := AutomationDiagnosticSession.SessionId
        this.StartTick := A_TickCount
        this.StartTimestamp := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
        this.FirstSessionUse :=
            AutomationDiagnosticSession.ConsumeFirstSessionUse()
        this.FirstTargetProcessUse := false
        this.TargetGeneration := 0
        this.CacheHit := false
        this.RecoveryAttempted := false
        this.Fields := Map()
        this.Stages := []
        this.Completed := false
        this.Stage("OPERATION_STARTED")
    }

    Stage(name) {
        if this.Completed
            return
        this.Stages.Push({
            name: String(name),
            tickOffsetMs: A_TickCount - this.StartTick
        })
    }

    SetField(name, value) {
        if this.Completed
            return
        if AutomationDiagnosticFieldAllowed(this.Action, name)
            this.Fields[String(name)] := value
    }

    SetCacheHit(cacheHit) {
        this.CacheHit := cacheHit = true
    }

    MarkRecoveryAttempted() {
        this.RecoveryAttempted := true
    }

    ObserveTarget(targetPid, targetHwnd) {
        observation := AutomationDiagnosticSession.ObserveTarget(
            this.Action,
            targetPid,
            targetHwnd
        )
        this.FirstTargetProcessUse :=
            observation.firstTargetProcessUse
        this.TargetGeneration := observation.targetGeneration
    }

    Complete(automationResult, resultCode) {
        if this.Completed
            return false
        this.Stage("OPERATION_COMPLETED")
        this.Completed := true
        elapsedMs := A_TickCount - this.StartTick
        detailed := this.FirstSessionUse
            || this.FirstTargetProcessUse
            || this.RecoveryAttempted
            || automationResult != "COMPLETED"
            || AutomationDiagnosticSession.DetailedModeActive()
        summary := FormatAutomationDiagnosticSummary(
            this,
            automationResult,
            resultCode,
            elapsedMs,
            detailed
        )
        lines := [summary]
        if detailed {
            for stage in this.Stages
                lines.Push(FormatAutomationDiagnosticStage(this, stage))
        }
        return WriteAutomationDiagnosticLines(lines)
    }
}

BeginAutomationDiagnosticOperation(action) {
    return AutomationDiagnosticOperation(action)
}

AutomationDiagnosticFieldAllowed(action, fieldName) {
    if action = "ViewerTool" || action = "ViewerCapture" || action = "ViewerClear" {
        static viewerFields := Map(
            "viewer.command", true,
            "viewer.foregroundHwnd", true,
            "viewer.focusHwnd", true,
            "viewer.keysBefore", true,
            "viewer.keysAfter", true,
            "viewer.releaseMs", true,
            "viewer.targetHwnd", true,
            "viewer.parentHwnd", true,
            "viewer.controlId", true,
            "viewer.candidateCount", true,
            "viewer.dispatchResult", true,
            "viewer.effectState", true,
            "viewer.errorType", true
        )
        return viewerFields.Has(String(fieldName))
    }
    static allowedByAction := Map(
        "ReportImageCaption",
        Map(
            "caption.capturePath", true,
            "caption.copyState", true,
            "caption.freshDiscoveryMs", true,
            "caption.activationMs", true,
            "caption.preSaveSettlePath", true,
            "caption.preSaveSettleMs", true,
            "caption.pasteToSaveMs", true,
            "caption.advanceGatePath", true,
            "caption.advanceGateMs", true,
            "caption.interAdvanceMs", true,
            "caption.saveToAdvanceMs", true,
            "caption.saveDispatchResult", true,
            "caption.persistenceState", true,
            "caption.advanceDispatchResult", true,
            "caption.targetCandidateCount", true
        )
    )
    actionKey := String(action)
    return allowedByAction.Has(actionKey)
        && allowedByAction[actionKey].Has(String(fieldName))
}

FormatAutomationDiagnosticSummary(
    operation,
    automationResult,
    resultCode,
    elapsedMs,
    detailed
) {
    fields := [
        "schema=" AutomationDiagnosticDefaults.SchemaVersion,
        "recordType=operation-summary",
        "timestamp=" AutomationDiagnosticSafeValue(operation.StartTimestamp),
        "tickCount=" AutomationDiagnosticSafeValue(operation.StartTick),
        "sessionId=" AutomationDiagnosticSafeValue(operation.SessionId),
        "operationId=" AutomationDiagnosticSafeValue(operation.OperationId),
        "appVersion=" AutomationDiagnosticSafeValue(AppMetadata.Version),
        "sourceRevision=" AutomationDiagnosticSafeValue(AppMetadata.SourceRevision),
        "action=" AutomationDiagnosticSafeValue(operation.Action),
        "automationResult=" AutomationDiagnosticSafeValue(automationResult),
        "resultCode=" AutomationDiagnosticSafeValue(resultCode),
        "firstSessionUse=" AutomationDiagnosticBoolean(operation.FirstSessionUse),
        "firstTargetProcessUse=" AutomationDiagnosticBoolean(operation.FirstTargetProcessUse),
        "targetGeneration=" AutomationDiagnosticSafeValue(operation.TargetGeneration),
        "cacheHit=" AutomationDiagnosticBoolean(operation.CacheHit),
        "detailedTrace=" AutomationDiagnosticBoolean(detailed),
        "stages=" AutomationDiagnosticStageList(operation.Stages),
        "elapsedMs=" AutomationDiagnosticSafeValue(elapsedMs)
    ]
    for name, value in operation.Fields
        fields.Push(name "=" AutomationDiagnosticSafeValue(value))
    return JoinAutomationDiagnosticFields(fields)
}

FormatAutomationDiagnosticStage(operation, stage) {
    return JoinAutomationDiagnosticFields([
        "schema=" AutomationDiagnosticDefaults.SchemaVersion,
        "recordType=stage-event",
        "timestamp=" AutomationDiagnosticSafeValue(operation.StartTimestamp),
        "sessionId=" AutomationDiagnosticSafeValue(operation.SessionId),
        "operationId=" AutomationDiagnosticSafeValue(operation.OperationId),
        "action=" AutomationDiagnosticSafeValue(operation.Action),
        "stage=" AutomationDiagnosticSafeValue(stage.name),
        "tickOffsetMs=" AutomationDiagnosticSafeValue(stage.tickOffsetMs)
    ])
}

AutomationDiagnosticStageList(stages) {
    output := ""
    for stage in stages
        output .= (output = "" ? "" : ">")
            . AutomationDiagnosticSafeValue(stage.name)
    return output
}

AutomationDiagnosticBoolean(value) {
    return value = true ? "true" : "false"
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

DefaultAutomationDiagnosticLogPath() {
    configPath := ReportAssistantConfig.Path()
    SplitPath configPath, , &configDirectory
    return configDirectory "\" AutomationDiagnosticDefaults.LogDirectoryName "\" AutomationDiagnosticDefaults.LogFileName
}

WriteAutomationDiagnosticLines(lines, logPath := "") {
    try {
        if logPath = ""
            logPath := DefaultAutomationDiagnosticLogPath()
        SplitPath logPath, , &logDirectory
        if !DirExist(logDirectory)
            DirCreate logDirectory
        RotateAutomationDiagnosticLog(logPath)
        block := ""
        for line in lines
            block .= AutomationDiagnosticSafeLine(line) "`r`n"
        FileAppend block, logPath, "UTF-8"
        return true
    } catch {
        return false
    }
}

AutomationDiagnosticSafeLine(line) {
    return StrReplace(StrReplace(String(line), "`r", ""), "`n", " ")
}

RotateAutomationDiagnosticLog(logPath) {
    if !FileExist(logPath)
        return
    try size := FileGetSize(logPath)
    catch
        return
    if size < AutomationDiagnosticDefaults.MaxFileBytes
        return
    Loop AutomationDiagnosticDefaults.RotatedFileCount - 1 {
        index := AutomationDiagnosticDefaults.RotatedFileCount - A_Index
        sourcePath := logPath "." index
        targetPath := logPath "." (index + 1)
        if FileExist(sourcePath)
            try FileMove sourcePath, targetPath, true
    }
    try FileMove logPath, logPath ".1", true
}

EnableAutomationDiagnosticsForTenMinutes(*) {
    AutomationDiagnosticSession.EnableDetailedMode()
    Flash("详细诊断已开启 10 分钟，重启后自动关闭", 1800)
}

CopyAutomationDiagnosticInformation(*) {
    snapshot := BuildAutomationDiagnosticSnapshot()
    try {
        A_Clipboard := snapshot
        if ClipWait(0.5) {
            Flash("诊断信息已复制", 1200)
            return true
        }
    }
    Flash("诊断信息复制失败", 1500)
    return false
}

BuildAutomationDiagnosticSnapshot(logPath := "", viewerFailureLogPath := "") {
    AutomationDiagnosticSession.EnsureStarted()
    if logPath = "" {
        try logPath := DefaultAutomationDiagnosticLogPath()
        catch
            logPath := ""
    }
    recentLines := ReadRecentAutomationDiagnosticLines(
        logPath,
        AutomationDiagnosticDefaults.SnapshotScanLineCount
    )
    if viewerFailureLogPath = "" {
        try viewerFailureLogPath := DefaultMxNMViewerFailureLogPath()
        catch
            viewerFailureLogPath := ""
    }
    recentViewerFailures := ReadRecentAutomationDiagnosticLines(
        viewerFailureLogPath,
        AutomationDiagnosticDefaults.SnapshotScanLineCount
    )
    automationEvent := FindRecentAutomationDiagnosticEvent(recentLines)
    viewerEvent := FindRecentViewerFailureEvent(recentViewerFailures)
    recentEvent := NewerAutomationDiagnosticEvent(
        automationEvent,
        viewerEvent
    )
    recentAction := recentEvent.action
    recommendation := AutomationDiagnosticRecommendation(recentAction)
    snapshotEvents := SelectAutomationDiagnosticSnapshotLines(
        recentLines,
        recentAction
    )
    snapshotViewerFailures := SelectViewerFailureSnapshotLines(
        recentViewerFailures,
        recommendation
    )
    lines := [
        "AutomationDiagnosticsSnapshot=1",
        "Timestamp=" AutomationDiagnosticSafeValue(FormatTime(, "yyyy-MM-ddTHH:mm:ss")),
        "SessionId=" AutomationDiagnosticSafeValue(AutomationDiagnosticSession.SessionId),
        "AppVersion=" AutomationDiagnosticSafeValue(AppMetadata.Version),
        "SourceRevision=" AutomationDiagnosticSafeValue(AppMetadata.SourceRevision),
        "A_OSVersion=" AutomationDiagnosticSafeValue(A_OSVersion),
        "A_AhkVersion=" AutomationDiagnosticSafeValue(A_AhkVersion),
        "A_PtrSize=" AutomationDiagnosticSafeValue(A_PtrSize),
        "A_ScreenDPI=" AutomationDiagnosticSafeValue(A_ScreenDPI),
        "VirtualScreen=" SysGet(76) "," SysGet(77) ","
            SysGet(78) "," SysGet(79),
        "DetailedModeActive=" AutomationDiagnosticBoolean(AutomationDiagnosticSession.DetailedModeActive()),
        "RecentEventSource=" AutomationDiagnosticSafeValue(recentEvent.source),
        "RecentRelevantAction=" AutomationDiagnosticSafeValue(recentAction),
        "RecommendedDiagnostic=" recommendation,
        "PrivacyContract=NO_PATIENT_TEXT_NO_CLIPBOARD_CONTENT_NO_WINDOW_TITLES"
    ]
    if recommendation = "VIEWER_CONTEXT" {
        for line in BuildCurrentMxNMContextTargetCacheSnapshot()
            lines.Push(line)
    }
    lines.Push("RecentEventsBegin")
    for line in snapshotEvents
        lines.Push(line)
    lines.Push("RecentEventsEnd")
    lines.Push("RecentViewerFailuresBegin")
    for line in snapshotViewerFailures
        lines.Push(line)
    lines.Push("RecentViewerFailuresEnd")
    ; Montage checkpoints are independent of the latest screenshot/action.
    ; Keep only this assistant session so old runs cannot masquerade as new.
    lines.Push("RecentMontageProgressBegin")
    try {
        montageLines := ReadRecentAutomationDiagnosticLines(
            DefaultMxNMMontageProgressLogPath(), 30
        )
        for line in montageLines {
            if AutomationDiagnosticLineField(line, "sessionId", "")
                = AutomationDiagnosticSession.SessionId
                lines.Push(line)
        }
    }
    lines.Push("RecentMontageProgressEnd")
    output := ""
    for line in lines
        output .= (output = "" ? "" : "`r`n") line
    return output
}

SelectAutomationDiagnosticSnapshotLines(lines, recentAction) {
    if recentAction != "ReportImageCaption" {
        matches := []
        for line in lines {
            action := AutomationDiagnosticLineField(line, "action", "NONE")
            if recentAction = "NONE" || action = recentAction
                matches.Push(line)
        }
        output := []
        startIndex := Max(
            1,
            matches.Length
                - AutomationDiagnosticDefaults.SnapshotDetailedEventCount
                + 1
        )
        Loop matches.Length - startIndex + 1
            output.Push(matches[startIndex + A_Index - 1])
        return output
    }

    summaries := []
    failureKeys := Map()
    for line in lines {
        if !InStr(line, "recordType=operation-summary")
            continue
        action := AutomationDiagnosticLineField(line, "action", "NONE")
        if recentAction != "NONE" && action != recentAction
            continue
        summaries.Push(line)
        if AutomationDiagnosticLineField(
            line,
            "automationResult",
            ""
        ) != "COMPLETED" {
            failureKeys[line] := true
        }
    }

    selected := Map()
    recentStart := Max(
        1,
        summaries.Length
            - AutomationDiagnosticDefaults.SnapshotRecentSummaryCount
            + 1
    )
    Loop summaries.Length - recentStart + 1
        selected[summaries[recentStart + A_Index - 1]] := true

    failureCount := 0
    Loop summaries.Length {
        line := summaries[summaries.Length - A_Index + 1]
        if !failureKeys.Has(line)
            continue
        selected[line] := true
        failureCount += 1
        if failureCount
            >= AutomationDiagnosticDefaults.SnapshotFailureSummaryCount {
            break
        }
    }

    output := []
    for line in summaries {
        if selected.Has(line)
            output.Push(line)
    }
    return output
}

SelectViewerFailureSnapshotLines(lines, recommendation) {
    if recommendation = "REPORT_IMAGE_CAPTION"
        return []
    matches := []
    for line in lines {
        action := AutomationDiagnosticLineField(line, "action", "")
        if action = ""
            continue
        if recommendation != "GENERAL_SUPPORT"
            && AutomationDiagnosticRecommendation(action) != recommendation {
            continue
        }
        matches.Push(line)
    }
    output := []
    startIndex := Max(
        1,
        matches.Length
            - AutomationDiagnosticDefaults.SnapshotViewerFailureCount
            + 1
    )
    Loop matches.Length - startIndex + 1
        output.Push(matches[startIndex + A_Index - 1])
    return output
}

BuildCurrentMxNMContextTargetCacheSnapshot() {
    lines := ["CurrentContextTargetCacheBegin"]
    try session := MxNMContextTargetSessionProvider.CachedSession
    catch
        session := 0
    if !IsObject(session) {
        lines.Push("CachePresent=false")
        lines.Push("CurrentContextTargetCacheEnd")
        return lines
    }

    surfaceHwnd := session.HasOwnProp("surfaceHwnd")
        ? session.surfaceHwnd
        : 0
    storedRect := session.HasOwnProp("surfaceClientRect")
        ? session.surfaceClientRect
        : 0
    storedPoint := session.HasOwnProp("safePointScreen")
        ? session.safePointScreen
        : 0
    surfaceExists := false
    surfaceVisible := false
    liveRect := 0
    if surfaceHwnd {
        try surfaceExists := DllCall(
            "User32\IsWindow",
            "Ptr", surfaceHwnd,
            "Int"
        ) != 0
        catch
            surfaceExists := false
        if surfaceExists {
            try surfaceVisible := DllCall(
                "User32\IsWindowVisible",
                "Ptr", surfaceHwnd,
                "Int"
            ) != 0
            catch
                surfaceVisible := false
            try liveRect := MxNMTargetClientRectScreen(surfaceHwnd)
            catch
                liveRect := 0
        }
    }
    lines.Push("CachePresent=true")
    lines.Push("CacheGeneration=" AutomationDiagnosticSafeValue(
        session.HasOwnProp("generation") ? session.generation : 0
    ))
    lines.Push("CachePid=" AutomationDiagnosticSafeValue(
        session.HasOwnProp("pid") ? session.pid : 0
    ))
    lines.Push("CacheRootHwnd=" AutomationDiagnosticSafeValue(
        session.HasOwnProp("rootHwnd") ? session.rootHwnd : 0
    ))
    lines.Push("CacheSurfaceHwnd=" AutomationDiagnosticSafeValue(surfaceHwnd))
    lines.Push("CacheDiscoveryMethod=" AutomationDiagnosticSafeValue(
        session.HasOwnProp("discoveryMethod")
            ? session.discoveryMethod
            : ""
    ))
    lines.Push("CacheStoredSurfaceRect="
        FormatAutomationDiagnosticRect(storedRect))
    lines.Push("CacheLiveSurfaceRect="
        FormatAutomationDiagnosticRect(liveRect))
    lines.Push("CacheStoredScreenPoint="
        FormatAutomationDiagnosticPoint(storedPoint))
    lines.Push("CacheSurfaceExists="
        AutomationDiagnosticBoolean(surfaceExists))
    lines.Push("CacheSurfaceVisible="
        AutomationDiagnosticBoolean(surfaceVisible))
    lines.Push("CacheRectUnchanged=" AutomationDiagnosticBoolean(
        AutomationDiagnosticRectsEqual(storedRect, liveRect)
    ))
    lines.Push("CachePointInsideLiveSurface=" AutomationDiagnosticBoolean(
        AutomationDiagnosticPointInsideRect(storedPoint, liveRect)
    ))
    lines.Push("CachePointInLiveLeftHalf=" AutomationDiagnosticBoolean(
        AutomationDiagnosticPointInLeftHalf(storedPoint, liveRect)
    ))
    lines.Push("CurrentContextTargetCacheEnd")
    return lines
}

FormatAutomationDiagnosticPoint(point) {
    if !IsObject(point)
        return ""
    return (
        AutomationDiagnosticSafeValue(point.x)
        . ","
        . AutomationDiagnosticSafeValue(point.y)
    )
}

FormatAutomationDiagnosticRect(rect) {
    if !IsObject(rect)
        return ""
    return (
        AutomationDiagnosticSafeValue(rect.left)
        . ","
        . AutomationDiagnosticSafeValue(rect.top)
        . ","
        . AutomationDiagnosticSafeValue(rect.right)
        . ","
        . AutomationDiagnosticSafeValue(rect.bottom)
    )
}

AutomationDiagnosticRectsEqual(first, second) {
    return IsObject(first)
        && IsObject(second)
        && first.left = second.left
        && first.top = second.top
        && first.right = second.right
        && first.bottom = second.bottom
}

AutomationDiagnosticPointInsideRect(point, rect) {
    return IsObject(point)
        && IsObject(rect)
        && point.x >= rect.left
        && point.x < rect.right
        && point.y >= rect.top
        && point.y < rect.bottom
}

AutomationDiagnosticPointInLeftHalf(point, rect) {
    if !AutomationDiagnosticPointInsideRect(point, rect)
        return false
    midpointX := rect.left + Floor((rect.right - rect.left) / 2)
    return point.x < midpointX
}

ReadRecentAutomationDiagnosticLines(logPath, maxLines) {
    if logPath = "" || !FileExist(logPath)
        return []
    try text := FileRead(logPath, "UTF-8")
    catch
        return []
    allLines := StrSplit(StrReplace(text, "`r", ""), "`n")
    output := []
    startIndex := Max(1, allLines.Length - maxLines + 1)
    Loop allLines.Length - startIndex + 1 {
        line := allLines[startIndex + A_Index - 1]
        if line != ""
            output.Push(AutomationDiagnosticSafeLine(line))
    }
    return output
}

FindRecentAutomationDiagnosticAction(lines) {
    return FindRecentAutomationDiagnosticEvent(lines).action
}

FindRecentAutomationDiagnosticEvent(lines) {
    Loop lines.Length {
        line := lines[lines.Length - A_Index + 1]
        if !InStr(line, "recordType=operation-summary")
            continue
        action := AutomationDiagnosticLineField(line, "action", "NONE")
        timestamp := AutomationDiagnosticLineField(
            line,
            "timestamp",
            ""
        )
        return {action: action, timestamp: timestamp, source: "AUTOMATION"}
    }
    return {action: "NONE", timestamp: "", source: "NONE"}
}

FindRecentViewerFailureEvent(lines) {
    Loop lines.Length {
        line := lines[lines.Length - A_Index + 1]
        action := AutomationDiagnosticLineField(line, "action", "")
        if action = ""
            continue
        timestamp := AutomationDiagnosticLineField(
            line,
            "timestamp",
            ""
        )
        return {action: action, timestamp: timestamp, source: "VIEWER_FAILURE"}
    }
    return {action: "NONE", timestamp: "", source: "NONE"}
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

AutomationDiagnosticLineField(line, fieldName, fallback := "") {
    pattern := "(?:^|\|)" fieldName "=([^|]*)"
    if RegExMatch(line, pattern, &match)
        return match[1]
    return fallback
}

AutomationDiagnosticRecommendation(action) {
    if action = "ReportImageCaption"
        return "REPORT_IMAGE_CAPTION"
    if InStr(action, "Viewer")
        || InStr(action, "Measurement")
        || InStr(action, "Context")
        || InStr(action, "Annotation")
        return "VIEWER_CONTEXT"
    if InStr(action, "Montage")
        return "MXNM_MONTAGE"
    return "GENERAL_SUPPORT"
}
