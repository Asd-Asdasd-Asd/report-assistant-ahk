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
    static BUTTON_SET_NOT_UNIQUE := "BUTTON_SET_NOT_UNIQUE"
    static BUTTON_LAYOUT_INVALID := "BUTTON_LAYOUT_INVALID"
    static DISPATCH_FAILED := "DISPATCH_FAILED"
    static BUSY := "BUSY"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MxNMViewerToolCommandProvider {
    static CachedPlan := 0
    static Busy := false

    static PrepareAtStartup(viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        if this.PrepareFromPathCache(viewerExe)
            return true
        if !WinExist("ahk_exe " viewerExe)
            return false
        return this.ResolvePlan(viewerExe).ok
    }

    static PrepareFromPathCache(viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        cache := LoadValidatedMxNMConfigPathCache()
        if !IsObject(cache)
            || StrLower(cache["viewerExe"]) != StrLower(viewerExe) {
            return false
        }
        plan := BuildMxNMViewerToolCommandPlan(
            viewerExe,
            cache["configPaths"]
        )
        if !plan.ok
            return false
        this.CachedPlan := plan
        return true
    }

    static ResolvePlan(viewerExe := "") {
        if viewerExe = ""
            viewerExe := MxNMConfigGeometryDefaults.ViewerExe
        if IsReusableMxNMViewerToolCommandPlan(this.CachedPlan, viewerExe)
            return this.CachedPlan

        configPaths := ResolveMxNMConfigPathsFromViewer(viewerExe)
        plan := BuildMxNMViewerToolCommandPlan(viewerExe, configPaths)
        if plan.ok {
            this.CachedPlan := plan
            SaveValidatedMxNMConfigPathCache(viewerExe, configPaths)
        }
        return plan
    }

    static Invoke(commandName, viewerExe := "") {
        if this.Busy
            return MakeMxNMViewerToolResult(false, MxNMViewerToolCode.BUSY)
        this.Busy := true
        try {
            if !MedExViewerToolForegroundActive()
                return MakeMxNMViewerToolResult(
                    false,
                    MxNMViewerToolCode.WRONG_FOREGROUND
                )
            if viewerExe = ""
                viewerExe := MxNMConfigGeometryDefaults.ViewerExe
            plan := this.ResolvePlan(viewerExe)
            if !plan.ok
                return MakeMxNMViewerToolResult(false, plan.code)
            commandKey := StrLower(String(commandName))
            if !plan.commands.Has(commandKey) {
                return MakeMxNMViewerToolResult(
                    false,
                    MxNMViewerToolCode.COMMAND_UNKNOWN
                )
            }

            viewerWindows := CaptureMxNMViewerWindowGeometry(
                viewerExe,
                plan.viewerProcessPath
            )
            if viewerWindows.Length = 0 {
                return MakeMxNMViewerToolResult(
                    false,
                    MxNMViewerToolCode.VIEWER_NOT_FOUND
                )
            }

            command := plan.commands[commandKey]
            controlSet := ResolveMxNMViewerToolControlSet(
                plan,
                viewerWindows
            )
            if !controlSet.ok {
                result := MakeMxNMViewerToolResult(
                    false,
                    controlSet.code
                )
                result.commandId := command.commandId
                result.commandRow := command.row
                result.commandColumn := command.column
                result.viewerHwnd := controlSet.frameHwnd
                result.buttonPanelHwnd := controlSet.panelHwnd
                result.runtimeCandidateCount :=
                    controlSet.candidateCount
                return result
            }
            target := controlSet.controls[commandKey]
            screenPoint := MxNMViewerToolRectCenter(target.rect)
            dispatched := DispatchMxNMViewerToolButton(target)
            if !dispatched {
                result := MakeMxNMViewerToolResult(
                    false,
                    MxNMViewerToolCode.DISPATCH_FAILED
                )
                result.commandId := command.commandId
                result.commandRow := command.row
                result.commandColumn := command.column
                result.viewerHwnd := controlSet.frame.hwnd
                result.buttonHwnd := target.hwnd
                result.buttonParentHwnd := target.parentHwnd
                result.buttonRootHwnd := target.rootHwnd
                result.buttonPanelHwnd := controlSet.panelHwnd
                result.runtimeControlId := target.controlId
                result.runtimeCandidateCount :=
                    controlSet.candidateCount
                result.screenPoint := screenPoint
                return result
            }
            result := MakeMxNMViewerToolResult(
                true,
                MxNMViewerToolCode.READY
            )
            result.commandId := command.commandId
            result.commandRow := command.row
            result.commandColumn := command.column
            result.viewerHwnd := controlSet.frame.hwnd
            result.buttonHwnd := target.hwnd
            result.buttonParentHwnd := target.parentHwnd
            result.buttonRootHwnd := target.rootHwnd
            result.buttonPanelHwnd := controlSet.panelHwnd
            result.runtimeControlId := target.controlId
            result.runtimeCandidateCount :=
                controlSet.candidateCount
            result.screenPoint := screenPoint
            return result
        } catch {
            return MakeMxNMViewerToolResult(
                false,
                MxNMViewerToolCode.UNEXPECTED_ERROR
            )
        } finally {
            this.Busy := false
        }
    }
}

MedExViewerToolForegroundActive(*) {
    global REPORT_EDITOR_EXE
    global VIEWER_EXE

    try foregroundHwnd := WinExist("A")
    catch
        return false
    if !foregroundHwnd
        return false
    try processName := WinGetProcessName("ahk_id " foregroundHwnd)
    catch
        return false
    return StrLower(processName) = StrLower(REPORT_EDITOR_EXE)
        || StrLower(processName) = StrLower(VIEWER_EXE)
}

BuildMxNMViewerToolCommandPlan(viewerExe, configPaths) {
    failure := MakeMxNMViewerToolCommandPlan(viewerExe)
    if !IsObject(configPaths) || !configPaths.ok
        return failure
    configResult := MxNMConfigGeometryProvider.LoadStaticConfig(
        viewerExe,
        configPaths
    )
    if !configResult.ok || !configResult.mainGeometry.frameSizeResolved
        return failure
    try configText := FileRead(configPaths.mainConfigPath)
    catch
        return failure

    parsed := ParseMxNMSCBtnPadCommands(configText)
    if !parsed.ok {
        failure.code := MxNMViewerToolCode.COMMAND_SCHEMA_INVALID
        return failure
    }
    commands := Map()
    for spec in MxNMViewerToolCommand.Specs() {
        matches := []
        for entry in parsed.entries {
            if entry.commandId = spec.commandId
                matches.Push(entry)
        }
        if matches.Length != 1 {
            failure.code := MxNMViewerToolCode.COMMAND_SCHEMA_INVALID
            return failure
        }
        if matches[1].column != 1 {
            failure.code := MxNMViewerToolCode.COMMAND_SCHEMA_INVALID
            return failure
        }
        commands[spec.id] := {
            label: spec.label,
            commandId: spec.commandId,
            row: matches[1].row,
            column: matches[1].column
        }
    }

    failure.viewerProcessPath := configPaths.viewerProcessPath
    failure.mainConfigSha256 := configResult.mainConfigSha256
    if failure.mainConfigSha256 = ""
        return failure
    failure.commands := commands
    failure.rowCount := parsed.rowCount
    failure.padX := parsed.padX
    failure.padY := parsed.padY
    failure.mainGeometry := configResult.mainGeometry
    failure.ok := true
    failure.code := MxNMViewerToolCode.READY
    return failure
}

ParseMxNMSCBtnPadCommands(configText) {
    currentSection := ""
    rowCountFound := false
    rowCount := 0
    rows := Map()
    padValues := Map()
    for line in StrSplit(String(configText), "`n", "`r") {
        trimmedLine := Trim(line, " `t")
        if RegExMatch(trimmedLine, "^\[([^\]]+)\]$", &sectionMatch) {
            currentSection := sectionMatch[1]
            continue
        }
        if trimmedLine = ""
            || SubStr(trimmedLine, 1, 1) = ";"
            || SubStr(trimmedLine, 1, 1) = "#" {
            continue
        }
        if !RegExMatch(trimmedLine, "^([^=]+)=(.*)$", &entryMatch)
            continue
        key := Trim(entryMatch[1], " `t")
        value := Trim(entryMatch[2], " `t")
        if StrLower(currentSection) = "showsetting"
            && RegExMatch(
                key,
                "i)^SCBtnPadPos([XY])$",
                &padMatch
            ) {
            axis := StrLower(padMatch[1])
            if padValues.Has(axis)
                || !RegExMatch(value, "^-?\d+$") {
                return MakeMxNMSCBtnPadParseFailure()
            }
            padValues[axis] := Integer(value)
            continue
        }
        if StrLower(currentSection) != "scbtnpadsetting"
            continue
        if StrLower(key) = "rownum" {
            if rowCountFound || !RegExMatch(value, "^\d+$")
                return MakeMxNMSCBtnPadParseFailure()
            rowCountFound := true
            rowCount := Integer(value)
            if rowCount < 1 || rowCount > 100
                return MakeMxNMSCBtnPadParseFailure()
            continue
        }
        if !RegExMatch(key, "i)^Row(\d+)$", &rowMatch)
            continue
        rowIndex := Integer(rowMatch[1])
        if rows.Has(rowIndex)
            return MakeMxNMSCBtnPadParseFailure()
        if !RegExMatch(value, "^\d+(?:\s*\|\s*\d+)*$")
            return MakeMxNMSCBtnPadParseFailure()
        commandIds := []
        for rawId in StrSplit(value, "|")
            commandIds.Push(Integer(Trim(rawId, " `t")))
        rows[rowIndex] := commandIds
    }
    if !rowCountFound || rows.Count != rowCount
        || !padValues.Has("x") || !padValues.Has("y")
        return MakeMxNMSCBtnPadParseFailure()

    entries := []
    loop rowCount {
        rowIndex := A_Index
        if !rows.Has(rowIndex)
            return MakeMxNMSCBtnPadParseFailure()
        for column, commandId in rows[rowIndex] {
            entries.Push({
                row: rowIndex,
                column: column,
                commandId: commandId
            })
        }
    }
    return {
        ok: true,
        rowCount: rowCount,
        padX: padValues["x"],
        padY: padValues["y"],
        entries: entries
    }
}

MakeMxNMSCBtnPadParseFailure() {
    return {
        ok: false,
        rowCount: 0,
        padX: 0,
        padY: 0,
        entries: []
    }
}

MakeMxNMViewerToolCommandPlan(viewerExe) {
    return {
        ok: false,
        code: MxNMViewerToolCode.CONFIG_UNAVAILABLE,
        viewerExe: String(viewerExe),
        viewerProcessPath: "",
        mainConfigSha256: "",
        rowCount: 0,
        padX: 0,
        padY: 0,
        mainGeometry: 0,
        commands: Map()
    }
}

IsReusableMxNMViewerToolCommandPlan(plan, viewerExe) {
    return IsObject(plan)
        && plan.ok
        && StrLower(plan.viewerExe) = StrLower(viewerExe)
        && plan.viewerProcessPath != ""
        && IsObject(plan.mainGeometry)
        && Type(plan.commands) = "Map"
        && plan.commands.Count = MxNMViewerToolCommand.Specs().Length
}

MakeMxNMViewerToolResult(ok, code) {
    return {
        ok: ok = true,
        code: String(code),
        commandId: 0,
        commandRow: 0,
        commandColumn: 0,
        viewerHwnd: 0,
        buttonHwnd: 0,
        buttonParentHwnd: 0,
        buttonRootHwnd: 0,
        buttonPanelHwnd: 0,
        runtimeControlId: 0,
        runtimeCandidateCount: 0,
        screenPoint: 0
    }
}

MapMxNMViewerToolPadOriginToRuntimeFrame(
    logicalPadPoint,
    mainGeometry,
    runtimeFrame
) {
    return {
        x: runtimeFrame.windowX + Round(
            logicalPadPoint.x
            * runtimeFrame.windowWidth
            / mainGeometry.frameWidth
        ),
        y: runtimeFrame.windowY + Round(
            logicalPadPoint.y
            * runtimeFrame.windowHeight
            / mainGeometry.frameHeight
        )
    }
}

; Retained only for Checkpoint 1 regression/audit comparison.
MapMxNMViewerToolPointToRuntimeFrame(
    logicalPadPoint,
    buttonOffset,
    mainGeometry,
    runtimeFrame
) {
    return {
        x: runtimeFrame.windowX + Round(
            logicalPadPoint.x
            * runtimeFrame.windowWidth
            / mainGeometry.frameWidth
        ) + buttonOffset.x,
        y: runtimeFrame.windowY + Round(
            logicalPadPoint.y
            * runtimeFrame.windowHeight
            / mainGeometry.frameHeight
        ) + buttonOffset.y
    }
}

ResolveMxNMViewerToolControlSet(plan, viewerWindows) {
    failure := {
        ok: false,
        code: MxNMViewerToolCode.BUTTON_SET_NOT_UNIQUE,
        frameHwnd: 0,
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
        return failure
    }
    runtimePid := processResult.pid

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
        frameHwnd := MxNMViewerToolGetRootOwnerHwnd(
            group.parentHwnd
        )
        runtimeFrame := ResolveMxNMViewerToolFrameGeometry(
            viewerWindows,
            frameHwnd,
            plan.viewerExe,
            plan.viewerProcessPath,
            runtimePid
        )
        if !IsObject(runtimeFrame)
            continue
        padOrigin := MapMxNMViewerToolPadOriginToRuntimeFrame(
            {x: plan.padX, y: plan.padY},
            plan.mainGeometry,
            runtimeFrame
        )
        if !MxNMViewerToolPanelMatchesPadOrigin(
            group.parentHwnd,
            group.parentRect,
            padOrigin,
            runtimeFrame,
            runtimePid
        ) {
            continue
        }
        validGroups.Push({
            frame: runtimeFrame,
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
        frameHwnd: validGroups[1].frame.hwnd,
        frame: validGroups[1].frame,
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
            pid: 0
        }
    }
    for pid, _ in pids {
        return {
            ok: true,
            code: MxNMViewerToolCode.READY,
            pid: pid
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

ResolveMxNMViewerToolFrameGeometry(
    viewerWindows,
    hwnd,
    viewerExe,
    expectedProcessPath,
    runtimePid
) {
    runtimeFrame := FindMxNMViewerToolWindowGeometry(
        viewerWindows,
        hwnd
    )
    if IsObject(runtimeFrame)
        return runtimeFrame
    if !hwnd || !runtimePid
        return 0
    if !DllCall(
        "User32\IsWindow",
        "Ptr", hwnd,
        "Int"
    ) {
        return 0
    }
    ownerPid := 0
    try DllCall(
        "User32\GetWindowThreadProcessId",
        "Ptr", hwnd,
        "UInt*", &ownerPid,
        "UInt"
    )
    catch
        return 0
    if ownerPid != runtimePid
        return 0
    if MxNMViewerToolGetRootOwnerHwnd(hwnd) != hwnd
        return 0
    if !MxNMViewerToolRuntimeProcessMatchesPlan(
        viewerWindows,
        runtimePid,
        viewerExe,
        expectedProcessPath
    ) {
        return 0
    }

    return CaptureMxNMViewerToolWindowGeometry(hwnd)
}

MxNMViewerToolRuntimeProcessMatchesPlan(
    viewerWindows,
    runtimePid,
    viewerExe,
    expectedProcessPath
) {
    normalizedExpectedPath := StrLower(
        NormalizeMxNMConfigPath(expectedProcessPath)
    )
    if !runtimePid || normalizedExpectedPath = ""
        return false
    for viewerWindow in viewerWindows {
        try candidatePid := WinGetPID(
            "ahk_id " viewerWindow.hwnd
        )
        catch
            candidatePid := 0
        if candidatePid != runtimePid
            continue
        try processPath := WinGetProcessPath(
            "ahk_id " viewerWindow.hwnd
        )
        catch
            processPath := ""
        try processName := WinGetProcessName(
            "ahk_id " viewerWindow.hwnd
        )
        catch
            processName := ""
        if StrLower(NormalizeMxNMConfigPath(processPath))
                = normalizedExpectedPath
            && StrLower(processName) = StrLower(viewerExe) {
            return true
        }
    }
    return false
}

CaptureMxNMViewerToolWindowGeometry(hwnd) {
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

    clientRect := Buffer(16, 0)
    if !DllCall(
        "User32\GetClientRect",
        "Ptr", hwnd,
        "Ptr", clientRect.Ptr,
        "Int"
    ) {
        return 0
    }
    clientOrigin := Buffer(8, 0)
    if !DllCall(
        "User32\ClientToScreen",
        "Ptr", hwnd,
        "Ptr", clientOrigin.Ptr,
        "Int"
    ) {
        return 0
    }
    clientWidth := NumGet(clientRect, 8, "Int")
    clientHeight := NumGet(clientRect, 12, "Int")
    if clientWidth <= 0 || clientHeight <= 0
        return 0
    return {
        hwnd: hwnd,
        windowX: windowX,
        windowY: windowY,
        windowWidth: windowWidth,
        windowHeight: windowHeight,
        clientX: NumGet(clientOrigin, 0, "Int"),
        clientY: NumGet(clientOrigin, 4, "Int"),
        clientWidth: clientWidth,
        clientHeight: clientHeight
    }
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
    if !DllCall(
        "User32\IsWindowVisible",
        "Ptr", hwnd,
        "Int"
    ) || !DllCall(
        "User32\IsWindowEnabled",
        "Ptr", hwnd,
        "Int"
    ) {
        return true
    }
    try candidatePid := WinGetPID("ahk_id " hwnd)
    catch
        candidatePid := 0
    if candidatePid != runtimePid
        return true
    className := MxNMViewerToolWindowClass(hwnd)
    if StrLower(className)
        != StrLower(MxNMViewerToolCommand.NativeClassName) {
        return true
    }
    try parentHwnd := DllCall(
        "User32\GetParent",
        "Ptr", hwnd,
        "Ptr"
    )
    catch
        parentHwnd := 0
    if !parentHwnd
        return true
    try parentPid := WinGetPID("ahk_id " parentHwnd)
    catch
        parentPid := 0
    if parentPid != runtimePid
        return true
    rect := MxNMViewerToolWindowRectScreen(hwnd)
    parentRect := MxNMViewerToolWindowRectScreen(parentHwnd)
    if !IsObject(rect)
        || !IsObject(parentRect)
        || !MxNMViewerToolRectInside(rect, parentRect) {
        return true
    }
    candidates.Push({
        hwnd: hwnd,
        parentHwnd: parentHwnd,
        rootHwnd: MxNMViewerToolGetRootHwnd(hwnd),
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
        || !DllCall(
            "User32\IsWindowVisible",
            "Ptr", panelHwnd,
            "Int"
        ) {
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
            || !MxNMViewerToolRectInside(
                control.rect,
                panelRect
            ) {
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

MxNMViewerToolRectInside(innerRect, outerRect) {
    return innerRect.right > innerRect.left
        && innerRect.bottom > innerRect.top
        && outerRect.right > outerRect.left
        && outerRect.bottom > outerRect.top
        && innerRect.left >= outerRect.left
        && innerRect.top >= outerRect.top
        && innerRect.right <= outerRect.right
        && innerRect.bottom <= outerRect.bottom
}

MxNMViewerToolRectCenter(rect) {
    return {
        x: Round((rect.left + rect.right) / 2),
        y: Round((rect.top + rect.bottom) / 2)
    }
}

MxNMViewerToolGetRootHwnd(hwnd) {
    try return DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", 2,
        "Ptr"
    )
    catch
        return 0
}

MxNMViewerToolGetRootOwnerHwnd(hwnd) {
    try return DllCall(
        "User32\GetAncestor",
        "Ptr", hwnd,
        "UInt", 3,
        "Ptr"
    )
    catch
        return 0
}

MxNMViewerToolWindowClass(hwnd) {
    classBuffer := Buffer(512, 0)
    try length := DllCall(
        "User32\GetClassNameW",
        "Ptr", hwnd,
        "Ptr", classBuffer.Ptr,
        "Int", 255,
        "Int"
    )
    catch
        length := 0
    return length > 0
        ? StrGet(classBuffer, length, "UTF-16")
        : ""
}

MxNMViewerToolWindowRectScreen(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall(
        "User32\GetWindowRect",
        "Ptr", hwnd,
        "Ptr", rectBuffer.Ptr,
        "Int"
    ) {
        return 0
    }
    return {
        left: NumGet(rectBuffer, 0, "Int"),
        top: NumGet(rectBuffer, 4, "Int"),
        right: NumGet(rectBuffer, 8, "Int"),
        bottom: NumGet(rectBuffer, 12, "Int")
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
