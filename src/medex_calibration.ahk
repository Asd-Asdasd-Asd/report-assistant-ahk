class MedExCalibrationStage {
    static IDLE := "Idle"
    static WAIT_ARROW := "WaitArrow"
    static WAIT_BLACK := "WaitBlack"
}

class MedExCalibrationDefaults {
    static HotkeyName := "Ctrl+Alt+F8"
    static ToolTipId := 19
    static BlackLookupTimeoutMs := 1200
    static BlackLookupPollIntervalMs := 60
    static MenuCloseValidationDelayMs := 60
    static AnchorReadyTimeoutMs := 400
    static AnchorReadyPollIntervalMs := 40
}

class MedExRedResetPreflightCode {
    static OK := "PREFLIGHT_OK"
    static UIA_INITIALIZING := "UIA_INITIALIZING"
    static ANCHOR_NOT_READY := "ANCHOR_NOT_READY"
    static NEED_CALIBRATION := "NEED_CALIBRATION"
    static UNSUPPORTED_PROFILE := "UNSUPPORTED_PROFILE"
    static UIA_UNAVAILABLE := "UIA_UNAVAILABLE"
    static FOREGROUND_CHANGED := "FOREGROUND_CHANGED"
}

global MEDEX_CALIBRATION_SESSION := 0

MedExCalibrationActive(*) {
    global MEDEX_CALIBRATION_SESSION
    return Type(MEDEX_CALIBRATION_SESSION) = "Map"
        && MEDEX_CALIBRATION_SESSION.Has("stage")
        && MEDEX_CALIBRATION_SESSION["stage"] != MedExCalibrationStage.IDLE
}

AdvanceMedExCalibration(*) {
    global MEDEX_CALIBRATION_SESSION
    if !MedExCalibrationActive()
        return BeginMedExCalibration()
    stage := MEDEX_CALIBRATION_SESSION["stage"]
    if stage = MedExCalibrationStage.WAIT_ARROW
        return CaptureMedExCalibrationArrow()
    if stage = MedExCalibrationStage.WAIT_BLACK
        return CaptureMedExCalibrationBlack()
    return CancelMedExCalibration("invalidState")
}

BeginMedExCalibration() {
    global MEDEX_CALIBRATION_SESSION
    SetTimer ClearMedExCalibrationToolTip, 0
    ClearMedExCalibrationToolTip()
    ShowMedExCalibrationToolTip("MedEx 校准`n正在检查环境…")
    contextResult := CollectMedExCalibrationContext(
        Map("validateInteractionPoints", false)
    )
    if !contextResult.ok {
        ShowMedExCalibrationToolTip(
            "MedEx 校准`n环境检查失败：" .
            MedExRedResetPreflightReasonMessage(contextResult.code) .
            "`n请保持 MedEx 前台、DPI 100%，然后重试。",
            contextResult.context
        )
        return false
    }
    context := contextResult.context
    logPath := StartMedExCalibrationLog(context)
    MEDEX_CALIBRATION_SESSION := Map(
        "stage", MedExCalibrationStage.WAIT_ARROW,
        "hwnd", context["hwnd"],
        "process", context["process"],
        "clientRect", context["clientRect"],
        "regionRect", context["regionRect"],
        "windowElement", context["windowElement"],
        "dpi", context["dpi"],
        "displayScaling", context["displayScaling"],
        "logPath", logPath
    )
    AppendMedExCalibrationLog("waitArrow")
    ShowMedExCalibrationToolTip(
        "MedEx 校准 1/2`n请把鼠标移动到字体颜色箭头中心，" .
        "`n再次按 " MedExCalibrationDefaults.HotkeyName "。`nEsc 取消",
        context
    )
    return true
}

CaptureMedExCalibrationArrow() {
    global MEDEX_CALIBRATION_SESSION
    session := MEDEX_CALIBRATION_SESSION
    if !MedExCalibrationTargetStillValid(session)
        return FailMedExCalibration("MedEx 前台窗口已改变，请重新开始。", "foregroundChanged")

    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseX, &mouseY
    regionRect := session["regionRect"]
    arrowOffsetX := Round(mouseX - regionRect["r"])
    arrowOffsetY := Round(mouseY - RectCenterY(regionRect))
    arrowPoint := Map("x", mouseX, "y", mouseY)
    if !ValidMedExCalibrationArrow(
        arrowOffsetX,
        arrowOffsetY,
        arrowPoint,
        session["clientRect"],
        regionRect
    ) {
        AppendMedExCalibrationLog("invalidArrow")
        ShowMedExCalibrationToolTip(
            "MedEx 校准 1/2`n箭头位置不合理，请重新指向箭头中心。" .
            "`n再次按 " MedExCalibrationDefaults.HotkeyName "。`nEsc 取消",
            session
        )
        return false
    }
    session["arrowOffsetX"] := arrowOffsetX
    session["arrowOffsetY"] := arrowOffsetY
    session["arrowPoint"] := arrowPoint
    AppendMedExCalibrationLog(
        "arrowCaptured ArrowOffsetX=" arrowOffsetX .
        " ArrowOffsetY=" arrowOffsetY
    )
    ShowMedExCalibrationToolTip("MedEx 校准`n正在自动验证颜色菜单…", session)

    try Click arrowPoint["x"], arrowPoint["y"]
    catch
        return FailMedExCalibration("无法点击颜色箭头，请重新开始。", "arrowClickFailed")
    menuLookup := WaitForMedExColorMenu(
        session["hwnd"],
        session["windowElement"],
        MedExCalibrationDefaults.BlackLookupTimeoutMs,
        MedExCalibrationDefaults.BlackLookupPollIntervalMs
    )
    if menuLookup["foregroundChanged"]
        return FailMedExCalibration("MedEx 前台窗口已改变，请重新开始。", "foregroundChangedDuringLookup")
    blackItem := menuLookup["blackItem"]
    if blackItem {
        try blackRect := UiaRectangleToMap(blackItem.BoundingRectangle)
        catch {
            blackRect := 0
        }
        if IsValidRect(blackRect) {
            blackPoint := Map(
                "x", Round((blackRect["l"] + blackRect["r"]) / 2),
                "y", Round((blackRect["t"] + blackRect["b"]) / 2)
            )
            if TryCompleteMedExCalibration(blackPoint, "uia")
                return true
        }
    }

    session["stage"] := MedExCalibrationStage.WAIT_BLACK
    AppendMedExCalibrationLog("uiaBlackFallback")
    ShowMedExCalibrationToolTip(
        "MedEx 校准 2/2`n未能自动确认黑色方块。" .
        "`n请确认颜色菜单已展开，把鼠标移到黑色方块中心，" .
        "`n再次按 " MedExCalibrationDefaults.HotkeyName "。`nEsc 取消",
        session
    )
    return false
}

CaptureMedExCalibrationBlack() {
    global MEDEX_CALIBRATION_SESSION
    if !MedExCalibrationTargetStillValid(MEDEX_CALIBRATION_SESSION)
        return FailMedExCalibration("MedEx 前台窗口已改变，请重新开始。", "foregroundChanged")
    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseX, &mouseY
    ShowMedExCalibrationToolTip("MedEx 校准`n正在验证黑色方块…", MEDEX_CALIBRATION_SESSION)
    return TryCompleteMedExCalibration(Map("x", mouseX, "y", mouseY), "manual")
}

TryCompleteMedExCalibration(blackPoint, source) {
    global MEDEX_CALIBRATION_SESSION
    session := MEDEX_CALIBRATION_SESSION
    arrowPoint := session["arrowPoint"]
    blackOffsetX := Round(blackPoint["x"] - arrowPoint["x"])
    blackOffsetY := Round(blackPoint["y"] - arrowPoint["y"])
    if !ValidMedExCalibrationBlack(
        blackOffsetX,
        blackOffsetY,
        blackPoint,
        session["clientRect"]
    ) {
        AppendMedExCalibrationLog("invalidBlack source=" source)
        if source = "uia"
            return false
        ShowMedExCalibrationToolTip(
            "MedEx 校准 2/2`n黑色方块位置不合理，请重新定位。" .
            "`n再次按 " MedExCalibrationDefaults.HotkeyName "。`nEsc 取消",
            session
        )
        return false
    }

    profile := Map(
        "schemaVersion", MedExMachineProfileDefaults.SchemaVersion,
        "status", MedExMachineProfileDefaults.Status,
        "dpi", session["dpi"],
        "displayScaling", session["displayScaling"],
        "arrowOffsetX", session["arrowOffsetX"],
        "arrowOffsetY", session["arrowOffsetY"],
        "blackOffsetX", blackOffsetX,
        "blackOffsetY", blackOffsetY,
        "validatedAt", FormatTime(, "yyyy-MM-ddTHH:mm:ss")
    )
    options := BuildMedExMachineProfileOptions(profile)
    signature := SampleAndEvaluateCandidateGPopupSignature(arrowPoint, options)
    if !signature["matched"] {
        AppendMedExCalibrationLog("popupSignatureFailed source=" source " reason=" signature["reason"])
        if source = "uia"
            return false
        ShowMedExCalibrationToolTip(
            "MedEx 校准 2/2`n未检测到正确的颜色菜单或黑色方块。" .
            "`n请保持菜单展开后重新定位。`nEsc 取消",
            session
        )
        return false
    }
    if !MedExCalibrationTargetStillValid(session)
        return FailMedExCalibration("MedEx 前台窗口已改变，请重新开始。", "foregroundChangedBeforeBlackClick")
    try Click blackPoint["x"], blackPoint["y"]
    catch
        return FailMedExCalibration("无法点击黑色方块，请重新开始。", "blackClickFailed")
    Sleep MedExCalibrationDefaults.MenuCloseValidationDelayMs
    if !MedExCalibrationTargetStillValid(session)
        return FailMedExCalibration("MedEx 前台窗口已改变，请重新开始。", "foregroundChangedAfterBlackClick")
    closedSignature := SampleAndEvaluateCandidateGPopupSignature(arrowPoint, options)
    if closedSignature["matched"] {
        AppendMedExCalibrationLog("menuCloseValidationFailed")
        ShowMedExCalibrationToolTip(
            "MedEx 校准失败`n颜色菜单没有正确关闭，请按 Esc 后重试。",
            session
        )
        return false
    }
    if !SaveValidatedMedExMachineProfile(profile)
        return FailMedExCalibration("无法保存 machine-profile.ini。", "profileWriteFailed")

    AppendMedExCalibrationLog(
        "completed source=" source " BlackOffsetX=" blackOffsetX .
        " BlackOffsetY=" blackOffsetY
    )
    profilePath := MedExMachineProfilePath()
    logPath := session["logPath"]
    MEDEX_CALIBRATION_SESSION := 0
    completionMessage := "校准完成`n此电脑已启用红字恢复。`n请正常输入一次 " Chr(59) "red 进行测试。`n配置：" profilePath "`n日志：" logPath
    ShowMedExCalibrationToolTip(completionMessage, session)
    SetTimer ClearMedExCalibrationToolTip, -8000
    return true
}

CancelMedExCalibration(reason := "cancelled") {
    global MEDEX_CALIBRATION_SESSION
    if MedExCalibrationActive()
        AppendMedExCalibrationLog(reason)
    session := MEDEX_CALIBRATION_SESSION
    MEDEX_CALIBRATION_SESSION := 0
    ShowMedExCalibrationToolTip("MedEx 校准已取消。", session)
    SetTimer ClearMedExCalibrationToolTip, -2000
    return true
}

FailMedExCalibration(message, reason) {
    global MEDEX_CALIBRATION_SESSION
    AppendMedExCalibrationLog("failed reason=" reason)
    session := MEDEX_CALIBRATION_SESSION
    MEDEX_CALIBRATION_SESSION := 0
    ShowMedExCalibrationToolTip("MedEx 校准失败`n" message, session)
    SetTimer ClearMedExCalibrationToolTip, -5000
    return false
}

PrepareMedExRedReset() {
    options := 0
    environment := CollectCurrentMedExProfileEnvironment()
    if !environment {
        result := MakeMedExRedResetPreflightResult(
            false,
            MedExRedResetPreflightCode.UNSUPPORTED_PROFILE,
            "environmentUnavailable"
        )
        FinishMedExRedResetPreflightFailure(result)
        return {ok: false, options: 0, code: result.code}
    }
    builtinResult := ValidateCandidateGRuntimeProfile(environment)
    if builtinResult.ok
        options := Map()
    if !options {
        profile := LoadValidatedMedExMachineProfile()
        if profile
            options := BuildMedExMachineProfileOptions(profile)
    }
    if !options {
        unsupportedReason := MedExContextValue(
            builtinResult.context,
            "unsupportedProfileReason",
            "profileMismatch"
        )
        code := MedExProfileMismatchNeedsCalibration(unsupportedReason)
            ? MedExRedResetPreflightCode.NEED_CALIBRATION
            : MedExRedResetPreflightCode.UNSUPPORTED_PROFILE
        result := MakeMedExRedResetPreflightResult(
            false,
            code,
            unsupportedReason,
            builtinResult.context
        )
        FinishMedExRedResetPreflightFailure(result)
        return {ok: false, options: 0, code: result.code}
    }
    contextResult := CollectMedExCalibrationContext(options)
    if !contextResult.ok {
        result := MakeMedExRedResetPreflightResult(
            false,
            contextResult.code,
            contextResult.reason,
            contextResult.context
        )
        FinishMedExRedResetPreflightFailure(result)
        return {ok: false, options: 0, code: result.code}
    }
    return {
        ok: true,
        options: options,
        code: MedExRedResetPreflightCode.OK
    }
}

MedExProfileMismatchNeedsCalibration(reason) {
    return reason = "screenWidthMismatch"
        || reason = "screenHeightMismatch"
}

MakeMedExRedResetPreflightResult(ok, code, reason, context := 0) {
    if Type(context) != "Map"
        context := Map()
    context["timestamp"] := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
    context["appVersion"] := AppMetadata.Version
    context["preflightStage"] := "redResetReadiness"
    context["readinessReason"] := reason
    return MakeColorResetResult(ok, code, context)
}

FinishMedExRedResetPreflightFailure(result) {
    try WriteMedExColorResetFailureDiagnostic(result)
    catch as err
        OutputDebug "MedEx red-reset preflight diagnostic failed: " Type(err)

    if result.code = MedExRedResetPreflightCode.NEED_CALIBRATION {
        ShowMedExCalibrationRequired()
        return
    }
    if result.code = MedExRedResetPreflightCode.UIA_INITIALIZING
        || result.code = MedExRedResetPreflightCode.ANCHOR_NOT_READY {
        ShowMedExRedResetPreflightStopped(
            "MedEx 界面尚未准备好，请稍后重新输入快捷语。"
        )
        return
    }
    if result.code = MedExRedResetPreflightCode.FOREGROUND_CHANGED {
        ShowMedExRedResetPreflightStopped(
            "MedEx 前台窗口已经改变，请返回报告编辑器后重试。"
        )
        return
    }
    if result.code = MedExRedResetPreflightCode.UIA_UNAVAILABLE {
        ShowMedExRedResetPreflightStopped(
            "当前无法连接 MedEx 界面，请重新加载程序后重试。"
        )
        return
    }
    ShowMedExRedResetPreflightStopped(
        "当前显示环境暂不支持红字恢复。"
    )
}

MedExRedResetPreflightReasonMessage(code) {
    if code = MedExRedResetPreflightCode.UIA_INITIALIZING
        || code = MedExRedResetPreflightCode.ANCHOR_NOT_READY
        return "MedEx 界面尚未准备好"
    if code = MedExRedResetPreflightCode.NEED_CALIBRATION
        return "此电脑尚未完成布局校准"
    if code = MedExRedResetPreflightCode.UIA_UNAVAILABLE
        return "无法连接 MedEx 界面"
    if code = MedExRedResetPreflightCode.FOREGROUND_CHANGED
        return "前台 MedEx 窗口已经改变"
    return "当前显示环境不受支持"
}

CollectCurrentMedExProfileEnvironment() {
    hwnd := WinExist("A")
    if !hwnd
        return 0
    try process := WinGetProcessName("ahk_id " hwnd)
    catch
        return 0
    if !MedExProcessNameIsApproved(process, MedExColorResetDefaults.ProvisionalProcessNames)
        return 0
    context := Map()
    CollectMedExEnvironmentContext(hwnd, context)
    return Map(
        "medExVersion", MedExContextValue(context, "medExVersion", "UNKNOWN"),
        "screenWidth", A_ScreenWidth,
        "screenHeight", A_ScreenHeight,
        "dpi", MedExContextValue(context, "dpi", "UNKNOWN"),
        "displayScaling", MedExContextValue(context, "displayScaling", "UNKNOWN")
    )
}

CollectMedExCalibrationContext(options := 0) {
    hwnd := WinExist("A")
    if !hwnd
        return {
            ok: false,
            code: MedExRedResetPreflightCode.FOREGROUND_CHANGED,
            reason: "noForegroundWindow",
            context: Map()
        }
    try process := WinGetProcessName("ahk_id " hwnd)
    catch
        return {
            ok: false,
            code: MedExRedResetPreflightCode.FOREGROUND_CHANGED,
            reason: "processLookupFailed",
            context: Map()
        }
    if !MedExProcessNameIsApproved(process, MedExColorResetDefaults.ProvisionalProcessNames)
        return {
            ok: false,
            code: MedExRedResetPreflightCode.FOREGROUND_CHANGED,
            reason: "wrongForegroundProcess",
            context: Map()
        }

    environmentContext := Map()
    CollectMedExEnvironmentContext(hwnd, environmentContext)
    if MedExContextValue(environmentContext, "dpi", "UNKNOWN") != 96
        return {
            ok: false,
            code: MedExRedResetPreflightCode.UNSUPPORTED_PROFILE,
            reason: "dpiMismatch",
            context: environmentContext
        }
    global UIA
    if !IsSet(UIA)
        return {
            ok: false,
            code: MedExRedResetPreflightCode.UIA_UNAVAILABLE,
            reason: "uiaNotIncluded",
            context: environmentContext
        }

    readiness := WaitForMedExCalibrationAnchor(hwnd, process)
    if !readiness.ok
        return readiness
    windowElement := readiness.context["windowElement"]
    textAnchors := readiness.context["textAnchors"]
    if textAnchors.Length > 1 {
        try textAnchors := CollectMedExTextAnchorSnapshot(windowElement, false).anchors
        catch
            return {
                ok: false,
                code: MedExRedResetPreflightCode.UNSUPPORTED_PROFILE,
                reason: "ambiguousAnchorSnapshotFailed",
                context: readiness.context
            }
    }
    clientRect := GetClientRectScreenMap(hwnd)
    layoutOptions := BuildCandidateGRuntimeLayoutOptions(options)
    if Type(options) = "Map" && options.Has("validateInteractionPoints")
        layoutOptions["validateInteractionPoints"] := options["validateInteractionPoints"]
    rowResult := ResolveCandidateGToolbarRow(textAnchors, clientRect, layoutOptions)
    if !rowResult.ok
        return {
            ok: false,
            code: MedExRedResetPreflightCode.UNSUPPORTED_PROFILE,
            reason: "anchorGeometryUnsupported",
            context: readiness.context
        }
    context := Map(
        "hwnd", hwnd,
        "process", process,
        "clientRect", clientRect,
        "windowRect", GetWindowRectMap(hwnd),
        "regionRect", rowResult.context["regionAnchorRect"],
        "windowElement", windowElement,
        "dpi", environmentContext["dpi"],
        "displayScaling", environmentContext["displayScaling"],
        "medExVersion", MedExContextValue(environmentContext, "medExVersion", "UNKNOWN"),
        "resolution", A_ScreenWidth "x" A_ScreenHeight
    )
    MergeContext(context, readiness.context)
    context.Delete("textAnchors")
    return {
        ok: true,
        code: MedExRedResetPreflightCode.OK,
        reason: "ok",
        context: context
    }
}

WaitForMedExCalibrationAnchor(hwnd, process) {
    startedAt := A_TickCount
    context := Map(
        "foregroundProcess", process,
        "foregroundWindowHandle", Format("0x{:X}", hwnd),
        "uiaActivationAttempted", true,
        "uiaRootReacquireCount", 0,
        "exactAnchorQueryCount", 0,
        "exactAnchorCandidateCount", 0,
        "readinessElapsedMs", 0
    )
    try UIA.ActivateChromiumAccessibility(hwnd, false, 0)
    catch {
        context["readinessElapsedMs"] := A_TickCount - startedAt
        return {
            ok: false,
            code: MedExRedResetPreflightCode.UIA_INITIALIZING,
            reason: "chromiumActivationFailed",
            context: context
        }
    }

    deadline := startedAt + MedExCalibrationDefaults.AnchorReadyTimeoutMs
    rootAcquired := false
    exactQuerySucceeded := false
    Loop {
        if !MedExForegroundTargetMatches(hwnd, process) {
            context["readinessElapsedMs"] := A_TickCount - startedAt
            return {
                ok: false,
                code: MedExRedResetPreflightCode.FOREGROUND_CHANGED,
                reason: "foregroundChangedDuringReadiness",
                context: context
            }
        }

        windowElement := 0
        try {
            windowElement := UIA.ElementFromHandle(hwnd, , false)
            rootAcquired := true
            context["uiaRootReacquireCount"] += 1
        }
        if windowElement {
            try {
                context["exactAnchorQueryCount"] += 1
                regionElements := windowElement.FindElements({
                    Type: "Text",
                    Name: CandidateGRelativeMouseProfile.RegionAnchorName
                })
                exactQuerySucceeded := true
                conversion := UiaTextElementsToAnchors(regionElements, false)
                textAnchors := conversion.anchors
                context["exactAnchorCandidateCount"] := textAnchors.Length
                if textAnchors.Length > 0 {
                    context["windowElement"] := windowElement
                    context["textAnchors"] := textAnchors
                    context["readinessElapsedMs"] := A_TickCount - startedAt
                    return {
                        ok: true,
                        code: MedExRedResetPreflightCode.OK,
                        reason: "exactAnchorReady",
                        context: context
                    }
                }
            }
        }

        if A_TickCount >= deadline
            break
        Sleep MedExCalibrationDefaults.AnchorReadyPollIntervalMs
    }

    context["readinessElapsedMs"] := A_TickCount - startedAt
    if rootAcquired && exactQuerySucceeded {
        return {
            ok: false,
            code: MedExRedResetPreflightCode.ANCHOR_NOT_READY,
            reason: "exactAnchorNotReady",
            context: context
        }
    }
    return {
        ok: false,
        code: MedExRedResetPreflightCode.UIA_INITIALIZING,
        reason: "uiaRootNotReady",
        context: context
    }
}

ValidMedExCalibrationArrow(offsetX, offsetY, point, clientRect, regionRect) {
    return offsetX >= MedExMachineProfileDefaults.ArrowOffsetXMin
        && offsetX <= MedExMachineProfileDefaults.ArrowOffsetXMax
        && Abs(offsetY) <= MedExMachineProfileDefaults.ArrowOffsetYAbsMax
        && RectContainsPoint(clientRect, point)
        && point["y"] >= regionRect["t"] - MedExMachineProfileDefaults.ArrowOffsetYAbsMax
        && point["y"] <= regionRect["b"] + MedExMachineProfileDefaults.ArrowOffsetYAbsMax
}

ValidMedExCalibrationBlack(offsetX, offsetY, point, clientRect) {
    return Abs(offsetX) <= MedExMachineProfileDefaults.BlackOffsetAbsMax
        && Abs(offsetY) <= MedExMachineProfileDefaults.BlackOffsetAbsMax
        && RectContainsPoint(clientRect, point)
}

MedExCalibrationTargetStillValid(session) {
    if Type(session) != "Map" || !session.Has("hwnd") || !session.Has("process")
        return false
    return MedExForegroundTargetMatches(session["hwnd"], session["process"])
}

ShowMedExCalibrationRequired(reason := "此电脑尚未通过布局校准") {
    context := Map("clientRect", GetSafeMedExForegroundClientRect())
    ShowMedExCalibrationToolTip(
        "红字恢复已停止`n" reason .
        "`n未插入任何正文或红字。" .
        "`n请按 " MedExCalibrationDefaults.HotkeyName " 开始校准。",
        context
    )
    SetTimer ClearMedExCalibrationToolTip, -6000
}

ShowMedExRedResetPreflightStopped(reason) {
    context := Map("clientRect", GetSafeMedExForegroundClientRect())
    ShowMedExCalibrationToolTip(
        "红字恢复已停止`n" reason .
        "`n未插入任何正文或红字。",
        context
    )
    SetTimer ClearMedExCalibrationToolTip, -5000
}

ShowMedExCalibrationToolTip(message, context := 0) {
    rect := 0
    if Type(context) = "Map" {
        if context.Has("clientRect")
            rect := context["clientRect"]
        else if context.Has("hwnd")
            try rect := GetClientRectScreenMap(context["hwnd"])
    }
    if !IsValidRect(rect)
        rect := MakeRect(0, 0, A_ScreenWidth, A_ScreenHeight)
    x := Max(rect["l"] + 10, rect["r"] - 430)
    y := Max(rect["t"] + 20, rect["b"] - 170)
    CoordMode "ToolTip", "Screen"
    ToolTip message, x, y, MedExCalibrationDefaults.ToolTipId
}

ClearMedExCalibrationToolTip(*) {
    ToolTip , , , MedExCalibrationDefaults.ToolTipId
}

GetSafeMedExForegroundClientRect() {
    hwnd := WinExist("A")
    if hwnd {
        try return GetClientRectScreenMap(hwnd)
    }
    return MakeRect(0, 0, A_ScreenWidth, A_ScreenHeight)
}

StartMedExCalibrationLog(context) {
    try {
        configPath := ReportAssistantConfig.Path()
        SplitPath configPath, , &configDirectory
        logDirectory := configDirectory "\logs"
        DirCreate logDirectory
        timestamp := FormatTime(A_Now, "yyyyMMdd-HHmmss")
        logPath := ""
        Loop 100 {
            suffix := A_Index = 1 ? "" : "-" A_Index
            candidatePath := logDirectory "\calibration-" timestamp suffix ".txt"
            if !FileExist(candidatePath) {
                logPath := candidatePath
                break
            }
        }
        if logPath = ""
            throw Error("A unique calibration log path was unavailable")
        clientRect := context["clientRect"]
        windowRect := context["windowRect"]
        regionRect := context["regionRect"]
        FileAppend(
            "Timestamp=" FormatTime(, "yyyy-MM-ddTHH:mm:ss") "`r`n" .
            "Event=started`r`n" .
            "Resolution=" context["resolution"] "`r`n" .
            "Dpi=" context["dpi"] "`r`n" .
            "DisplayScaling=" context["displayScaling"] "`r`n" .
            "MedExVersion=" context["medExVersion"] "`r`n" .
            "WindowRect=" windowRect["l"] "," windowRect["t"] "," windowRect["r"] "," windowRect["b"] "`r`n" .
            "ClientRect=" clientRect["l"] "," clientRect["t"] "," clientRect["r"] "," clientRect["b"] "`r`n" .
            "RegionAnchorRect=" regionRect["l"] "," regionRect["t"] "," regionRect["r"] "," regionRect["b"] "`r`n",
            logPath,
            "UTF-8"
        )
        return logPath
    } catch {
        return ""
    }
}

AppendMedExCalibrationLog(message) {
    global MEDEX_CALIBRATION_SESSION
    if Type(MEDEX_CALIBRATION_SESSION) != "Map"
        return
    logPath := MedExMachineProfileValue(MEDEX_CALIBRATION_SESSION, "logPath", "")
    if logPath = ""
        return
    try FileAppend(
        "Timestamp=" FormatTime(, "yyyy-MM-ddTHH:mm:ss") .
        " Event=" message "`r`n",
        logPath,
        "UTF-8"
    )
}
