class MxNMViewerToolCommand {
    static Arrow := 21043
    static Length := 21048
    static Suv3D := 21193
    static BuiltInRowCount := 3
    static ButtonCenterX := 17
    static ButtonCenterY := 17
    static ButtonPitch := 38

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
    static BUTTON_ID_MISMATCH := "BUTTON_ID_MISMATCH"
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
            runtimeFrame := ResolveMxNMRuntimeFrame(viewerWindows)
            if !runtimeFrame.ok {
                code := viewerWindows.Length = 0
                    ? MxNMViewerToolCode.VIEWER_NOT_FOUND
                    : MxNMViewerToolCode.VIEWER_NOT_UNIQUE
                return MakeMxNMViewerToolResult(false, code)
            }
            if !DllCall(
                "User32\IsWindow",
                "Ptr", runtimeFrame.frame.hwnd,
                "Int"
            ) {
                return MakeMxNMViewerToolResult(
                    false,
                    MxNMViewerToolCode.VIEWER_NOT_FOUND
                )
            }

            command := plan.commands[commandKey]
            buttonOffset := {
                x: MxNMViewerToolCommand.ButtonCenterX,
                y: (
                    MxNMViewerToolCommand.BuiltInRowCount
                    + command.row - 1
                ) * MxNMViewerToolCommand.ButtonPitch
                + MxNMViewerToolCommand.ButtonCenterY
            }
            screenPoint := MapMxNMViewerToolPointToRuntimeFrame(
                {x: plan.padX, y: plan.padY},
                buttonOffset,
                plan.mainGeometry,
                runtimeFrame.frame
            )
            target := ResolveMxNMViewerToolButtonTarget(
                screenPoint,
                runtimeFrame.frame.hwnd,
                command.commandId
            )
            if !target.ok {
                result := MakeMxNMViewerToolResult(false, target.code)
                result.commandId := command.commandId
                result.commandRow := command.row
                result.commandColumn := command.column
                result.viewerHwnd := runtimeFrame.frame.hwnd
                result.screenPoint := screenPoint
                if target.HasOwnProp("hwnd")
                    result.buttonHwnd := target.hwnd
                if target.HasOwnProp("rootHwnd")
                    result.buttonRootHwnd := target.rootHwnd
                if target.HasOwnProp("parentHwnd")
                    result.buttonParentHwnd := target.parentHwnd
                if target.HasOwnProp("controlId")
                    result.runtimeControlId := target.controlId
                return result
            }
            dispatched := DispatchMxNMViewerToolButton(target)
            if !dispatched {
                result := MakeMxNMViewerToolResult(
                    false,
                    MxNMViewerToolCode.DISPATCH_FAILED
                )
                result.commandId := command.commandId
                result.commandRow := command.row
                result.commandColumn := command.column
                result.viewerHwnd := runtimeFrame.frame.hwnd
                result.buttonHwnd := target.hwnd
                result.buttonParentHwnd := target.parentHwnd
                result.buttonRootHwnd := target.rootHwnd
                result.runtimeControlId := target.controlId
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
            result.viewerHwnd := runtimeFrame.frame.hwnd
            result.buttonHwnd := target.hwnd
            result.buttonParentHwnd := target.parentHwnd
            result.buttonRootHwnd := target.rootHwnd
            result.runtimeControlId := target.controlId
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
        runtimeControlId: 0,
        screenPoint: 0
    }
}

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

ResolveMxNMViewerToolButtonTarget(
    screenPoint,
    runtimeFrameHwnd,
    expectedControlId
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
            code: MxNMViewerToolCode.BUTTON_TARGET_INVALID
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
    try parentHwnd := DllCall(
        "User32\GetParent",
        "Ptr", pointHwnd,
        "Ptr"
    )
    catch {
        parentHwnd := 0
    }
    try pointPid := WinGetPID("ahk_id " rootHwnd)
    catch {
        pointPid := 0
    }
    try runtimePid := WinGetPID("ahk_id " runtimeFrameHwnd)
    catch {
        runtimePid := 0
    }
    clientRect := MxNMViewerToolClientRectScreen(rootHwnd)
    if !rootHwnd || !parentHwnd || !pointPid || pointPid != runtimePid
        || !IsObject(clientRect)
        || screenPoint.x < clientRect.left
        || screenPoint.x >= clientRect.right
        || screenPoint.y < clientRect.top
        || screenPoint.y >= clientRect.bottom {
        return {
            ok: false,
            code: MxNMViewerToolCode.BUTTON_TARGET_INVALID,
            hwnd: pointHwnd,
            parentHwnd: parentHwnd,
            rootHwnd: rootHwnd
        }
    }
    try parentPid := WinGetPID("ahk_id " parentHwnd)
    catch {
        parentPid := 0
    }
    if !parentPid || parentPid != runtimePid {
        return {
            ok: false,
            code: MxNMViewerToolCode.BUTTON_TARGET_INVALID,
            hwnd: pointHwnd,
            parentHwnd: parentHwnd,
            rootHwnd: rootHwnd
        }
    }
    try controlId := DllCall(
        "User32\GetDlgCtrlID",
        "Ptr", pointHwnd,
        "Int"
    )
    catch {
        controlId := 0
    }
    if controlId != expectedControlId {
        return {
            ok: false,
            code: MxNMViewerToolCode.BUTTON_ID_MISMATCH,
            hwnd: pointHwnd,
            parentHwnd: parentHwnd,
            rootHwnd: rootHwnd,
            controlId: controlId
        }
    }
    return {
        ok: true,
        code: MxNMViewerToolCode.READY,
        hwnd: pointHwnd,
        parentHwnd: parentHwnd,
        rootHwnd: rootHwnd,
        controlId: controlId
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

MxNMViewerToolClientRectScreen(hwnd) {
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
