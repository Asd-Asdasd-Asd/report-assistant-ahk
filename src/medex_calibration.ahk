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
            "MedEx 校准`n环境检查失败：" contextResult.reason .
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
    if environment {
        builtinResult := ValidateCandidateGRuntimeProfile(environment)
        if builtinResult.ok
            options := Map()
    }
    if !options {
        profile := LoadValidatedMedExMachineProfile()
        if profile
            options := BuildMedExMachineProfileOptions(profile)
    }
    if !options {
        ShowMedExCalibrationRequired()
        return {ok: false, options: 0}
    }
    contextResult := CollectMedExCalibrationContext(options)
    if !contextResult.ok {
        ShowMedExCalibrationRequired(contextResult.reason)
        return {ok: false, options: 0}
    }
    return {ok: true, options: options}
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
        return {ok: false, reason: "未检测到前台窗口", context: Map()}
    try process := WinGetProcessName("ahk_id " hwnd)
    catch
        return {ok: false, reason: "无法读取前台进程", context: Map()}
    if !MedExProcessNameIsApproved(process, MedExColorResetDefaults.ProvisionalProcessNames)
        return {ok: false, reason: "前台不是已批准的 MedEx 进程", context: Map()}

    environmentContext := Map()
    CollectMedExEnvironmentContext(hwnd, environmentContext)
    if MedExContextValue(environmentContext, "dpi", "UNKNOWN") != 96
        return {ok: false, reason: "仅支持 Windows 缩放 100% (DPI 96)", context: Map()}
    global UIA
    if !IsSet(UIA)
        return {ok: false, reason: "UIA 不可用", context: Map()}
    try windowElement := UIA.ElementFromHandle(hwnd)
    catch
        return {ok: false, reason: "无法连接 MedEx UIA", context: Map()}
    try regionElements := windowElement.FindElements({
        Type: "Text",
        Name: CandidateGRelativeMouseProfile.RegionAnchorName
    })
    catch
        return {ok: false, reason: "无法查找 检查所见 anchor", context: Map()}
    conversion := UiaTextElementsToAnchors(regionElements, false)
    textAnchors := conversion.anchors
    if textAnchors.Length > 1 {
        try textAnchors := CollectMedExTextAnchorSnapshot(windowElement, false).anchors
        catch
            return {ok: false, reason: "anchor 重复且无法完成校验", context: Map()}
    }
    clientRect := GetClientRectScreenMap(hwnd)
    layoutOptions := BuildCandidateGRuntimeLayoutOptions(options)
    if Type(options) = "Map" && options.Has("validateInteractionPoints")
        layoutOptions["validateInteractionPoints"] := options["validateInteractionPoints"]
    rowResult := ResolveCandidateGToolbarRow(textAnchors, clientRect, layoutOptions)
    if !rowResult.ok
        return {ok: false, reason: "检查所见 anchor 不唯一或位置不合理", context: Map()}
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
    return {ok: true, reason: "ok", context: context}
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
