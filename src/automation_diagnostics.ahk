class AutomationDiagnosticDefaults {
    static SchemaVersion := 1
    static LogDirectoryName := "logs"
    static LogFileName := "automation-events.log"
    static MaxFileBytes := 1048576
    static RotatedFileCount := 3
    static DiagnosticWindowMs := 600000
    static SnapshotLineCount := 60
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
    static allowedByAction := Map(
        "ReportImageCaption",
        Map(
            "caption.capturePath", true,
            "caption.freshDiscoveryMs", true,
            "caption.activationMs", true,
            "caption.pasteToSaveMs", true,
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
        AutomationDiagnosticDefaults.SnapshotLineCount
    )
    if viewerFailureLogPath = "" {
        try viewerFailureLogPath := DefaultMxNMViewerFailureLogPath()
        catch
            viewerFailureLogPath := ""
    }
    recentViewerFailures := ReadRecentAutomationDiagnosticLines(
        viewerFailureLogPath,
        AutomationDiagnosticDefaults.SnapshotLineCount
    )
    automationEvent := FindRecentAutomationDiagnosticEvent(recentLines)
    viewerEvent := FindRecentViewerFailureEvent(recentViewerFailures)
    recentEvent := NewerAutomationDiagnosticEvent(
        automationEvent,
        viewerEvent
    )
    recentAction := recentEvent.action
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
        "RecommendedDiagnostic=" AutomationDiagnosticRecommendation(recentAction),
        "PrivacyContract=NO_PATIENT_TEXT_NO_CLIPBOARD_CONTENT_NO_WINDOW_TITLES",
        "RecentEventsBegin"
    ]
    for line in recentLines
        lines.Push(line)
    lines.Push("RecentEventsEnd")
    lines.Push("RecentViewerFailuresBegin")
    for line in recentViewerFailures
        lines.Push(line)
    lines.Push("RecentViewerFailuresEnd")
    output := ""
    for line in lines
        output .= (output = "" ? "" : "`r`n") line
    return output
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
