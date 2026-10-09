class ContextMeasurementDefaults {
    static ViewerExe := "MedExNMFusion.exe"
    static SuvMaxCommandText := "复制SUVMax值"
    static LineAxesCommandText := "复制直线测量值"
    static PopupClass := "#32770"
    static PopupTimeoutMs := 1000
    static PopupPollIntervalMs := 20
}

class ContextMeasurementProvider {
    static ReadMeasurement(spec, options := 0) {
        return ReadCurrentMeasurementWithoutFocusSwitch(spec, options)
    }

    static ReadSuvMax(options := 0) {
        return this.ReadMeasurement(BuildSuvMaxMeasurementCommandSpec(), options)
    }

    static ReadLineAxes(options := 0) {
        return this.ReadMeasurement(
            BuildLineAxesMeasurementCommandSpec(),
            options
        )
    }
}

ReadCurrentSuvMaxWithoutFocusSwitch(options := 0) {
    return ContextMeasurementProvider.ReadSuvMax(options)
}

BuildSuvMaxMeasurementCommandSpec() {
    return MeasurementCommandSpec(
        MeasurementType.SUVMAX,
        ContextMeasurementDefaults.SuvMaxCommandText,
        ParseSuvMaxMeasurement
    )
}

BuildLineAxesMeasurementCommandSpec() {
    return MeasurementCommandSpec(
        MeasurementType.LINE_AXES,
        ContextMeasurementDefaults.LineAxesCommandText,
        ParseLineAxesMeasurement,
        true
    )
}

ReadCurrentMeasurementWithoutFocusSwitch(spec, options := 0) {
    if !IsValidMeasurementCommandSpec(spec) {
        requestedMeasurementType := IsObject(spec)
            && spec.HasOwnProp("measurementType")
                ? String(spec.measurementType)
                : ""
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.INVALID_MEASUREMENT_SPEC
        )
    }

    requestedMeasurementType := spec.measurementType
    context := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "viewerExe", MeasurementOption(
            options,
            "viewerExe",
            ContextMeasurementDefaults.ViewerExe
        ),
        "commandText", spec.commandText,
        "measurementType", requestedMeasurementType,
        "focusSwitchAttempted", false,
        "mouseMoveAttempted", false,
        "popupHwnd", 0,
        "popupDiscovery", "",
        "commandControlHwnd", 0,
        "commandRuntimeId", 0,
        "clipboardOwnerHwnd", 0
    )

    viewer := ResolveContextMeasurementViewer(context["viewerExe"], options)
    if !viewer.ok {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            viewer.failureReason,
            context
        )
    }
    context["viewerHwnd"] := viewer.hwnd
    context["viewerPid"] := viewer.pid
    expectedViewerHwnd := MeasurementOption(options, "expectedViewerHwnd", 0)
    expectedViewerPid := MeasurementOption(options, "expectedViewerPid", 0)
    if (expectedViewerHwnd && viewer.hwnd != expectedViewerHwnd)
        || (expectedViewerPid && viewer.pid != expectedViewerPid) {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.VIEWER_TARGET_CHANGED,
            context
        )
    }

    pointResult := ResolveContextMeasurementImagePoint(
        viewer.hwnd,
        options
    )
    if !pointResult.ok {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            pointResult.failureReason,
            context
        )
    }
    context["imageScreenX"] := pointResult.screenPoint.x
    context["imageScreenY"] := pointResult.screenPoint.y
    context["imageClientX"] := pointResult.clientPoint.x
    context["imageClientY"] := pointResult.clientPoint.y

    actionContext := Map(
        "failureReason", MeasurementFailureReason.NONE,
        "popupHwnd", 0,
        "popupDiscovery", "",
        "commandControlHwnd", 0,
        "commandRuntimeId", 0
    )
    captureOptions := CloneContextMeasurementOptions(options)
    captureOptions["acceptEmptyClipboard"] :=
        spec.acceptEmptyClipboard
    try {
        capture := CaptureMeasurementClipboardText(
            () => InvokePreparedMxNMContextCommand(actionContext),
            captureOptions,
            () => PrepareMxNMContextCommand(
                viewer,
                pointResult.clientPoint,
                context["commandText"],
                actionContext,
                options
            )
        )
    } catch as err {
        context["exceptionType"] := Type(err)
        context["exceptionMessage"] := err.Message
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.UNEXPECTED_ERROR,
            context
        )
    } finally {
        if actionContext["popupHwnd"]
            CloseContextMeasurementPopup(actionContext["popupHwnd"])
    }

    MergeContextMeasurementMetadata(context, actionContext, capture)
    if !capture.ok {
        failureReason := capture.failureReason
        if failureReason = MeasurementFailureReason.CLIPBOARD_ACTION_FAILED
            && actionContext["failureReason"] != MeasurementFailureReason.NONE {
            failureReason := actionContext["failureReason"]
        }
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            failureReason,
            context
        )
    }

    try result := spec.parserCallback.Call(capture.rawText)
    catch as err {
        context["parserExceptionType"] := Type(err)
        context["parserExceptionMessage"] := err.Message
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.UNEXPECTED_ERROR,
            context
        )
    }
    if !(result is MeasurementResult)
        || result.measurementType != requestedMeasurementType {
        context["parserResultType"] := Type(result)
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            requestedMeasurementType,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            MeasurementFailureReason.UNEXPECTED_ERROR,
            context
        )
    }
    result.context := context
    return result
}

CloneContextMeasurementOptions(options := 0) {
    clone := Map()
    if Type(options) = "Map" {
        for key, value in options
            clone[key] := value
    }
    return clone
}

ResolveContextMeasurementViewer(viewerExe, options := 0) {
    expectedViewerHwnd := MeasurementOption(
        options,
        "expectedViewerHwnd",
        0
    )
    expectedViewerPid := MeasurementOption(
        options,
        "expectedViewerPid",
        0
    )
    if expectedViewerHwnd {
        expectedViewer := ResolveExpectedContextMeasurementViewer(
            viewerExe,
            expectedViewerHwnd,
            expectedViewerPid
        )
        return expectedViewer
    }

    screenPoint := GetContextMeasurementConfiguredScreenPoint(options)
    if IsContextMeasurementPoint(screenPoint)
        && PointInsideVirtualScreen(screenPoint) {
        pointViewer := ResolveContextMeasurementViewerFromPoint(
            viewerExe,
            screenPoint
        )
        if pointViewer.ok
            return pointViewer
    }

    try windows := WinGetList("ahk_exe " viewerExe)
    catch {
        windows := []
    }
    if windows.Length = 0 {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_NOT_FOUND
        }
    }
    if windows.Length != 1 {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_AMBIGUOUS
        }
    }

    hwnd := windows[1]
    try pid := WinGetPID("ahk_id " hwnd)
    catch {
        pid := 0
    }
    if !pid {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_NOT_FOUND
        }
    }
    return {
        ok: true,
        hwnd: hwnd,
        pid: pid,
        failureReason: MeasurementFailureReason.NONE
    }
}

ResolveExpectedContextMeasurementViewer(
    viewerExe,
    expectedViewerHwnd,
    expectedViewerPid := 0
) {
    if !WinExist("ahk_id " expectedViewerHwnd) {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_NOT_FOUND
        }
    }
    try processName := WinGetProcessName(
        "ahk_id " expectedViewerHwnd
    )
    catch {
        processName := ""
    }
    try pid := WinGetPID("ahk_id " expectedViewerHwnd)
    catch {
        pid := 0
    }
    if StrLower(processName) != StrLower(viewerExe)
        || !pid
        || (expectedViewerPid && pid != expectedViewerPid) {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_TARGET_CHANGED
        }
    }
    return {
        ok: true,
        hwnd: expectedViewerHwnd,
        pid: pid,
        failureReason: MeasurementFailureReason.NONE
    }
}

ResolveContextMeasurementViewerFromPoint(viewerExe, screenPoint) {
    pointHwnd := Win32WindowFromPoint(screenPoint)
    if !pointHwnd {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_NOT_FOUND
        }
    }

    rootHwnd := Win32RootWindow(pointHwnd)
    if !rootHwnd
        rootHwnd := pointHwnd

    try processName := WinGetProcessName("ahk_id " rootHwnd)
    catch {
        processName := ""
    }
    if StrLower(processName) != StrLower(viewerExe) {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_NOT_FOUND
        }
    }

    try pid := WinGetPID("ahk_id " rootHwnd)
    catch {
        pid := 0
    }
    if !pid {
        return {
            ok: false,
            hwnd: 0,
            pid: 0,
            failureReason: MeasurementFailureReason.VIEWER_NOT_FOUND
        }
    }
    return {
        ok: true,
        hwnd: rootHwnd,
        pid: pid,
        failureReason: MeasurementFailureReason.NONE
    }
}

GetContextMeasurementConfiguredScreenPoint(options := 0) {
    point := MeasurementOption(options, "imageScreenPoint", 0)
    if IsContextMeasurementPoint(point)
        return point
    return 0
}

ResolveContextMeasurementImagePoint(viewerHwnd, options := 0) {
    resolver := MeasurementOption(options, "imagePointResolver", 0)
    if IsObject(resolver) && HasMethod(resolver, "Call") {
        try point := resolver.Call(viewerHwnd)
        catch {
            point := 0
        }
    } else {
        point := GetContextMeasurementConfiguredScreenPoint(options)
    }

    if !IsContextMeasurementPoint(point) {
        return {
            ok: false,
            screenPoint: 0,
            clientPoint: 0,
            failureReason: MeasurementFailureReason.IMAGE_POINT_UNAVAILABLE
        }
    }

    screenPoint := {
        x: Round(point.x),
        y: Round(point.y)
    }
    if !PointInsideVirtualScreen(screenPoint) {
        return {
            ok: false,
            screenPoint: screenPoint,
            clientPoint: 0,
            failureReason: MeasurementFailureReason.IMAGE_POINT_OUT_OF_BOUNDS
        }
    }

    clientRectScreen := RectLTRB(Win32ClientRectScreen(viewerHwnd))
    if !clientRectScreen
        || screenPoint.x < clientRectScreen.l
        || screenPoint.x >= clientRectScreen.r
        || screenPoint.y < clientRectScreen.t
        || screenPoint.y >= clientRectScreen.b {
        return {
            ok: false,
            screenPoint: screenPoint,
            clientPoint: 0,
            failureReason: MeasurementFailureReason.IMAGE_POINT_OUT_OF_BOUNDS
        }
    }

    clientPoint := Win32ScreenToClient(viewerHwnd, screenPoint)
    if !clientPoint {
        return {
            ok: false,
            screenPoint: screenPoint,
            clientPoint: 0,
            failureReason: MeasurementFailureReason.IMAGE_POINT_OUT_OF_BOUNDS
        }
    }
    return {
        ok: true,
        screenPoint: screenPoint,
        clientPoint: clientPoint,
        clientRectScreen: clientRectScreen,
        failureReason: MeasurementFailureReason.NONE
    }
}

IsContextMeasurementPoint(point) {
    return IsObject(point)
        && point.HasOwnProp("x")
        && point.HasOwnProp("y")
        && IsNumber(point.x)
        && IsNumber(point.y)
}

PrepareContextMeasurementCopyCommand(viewer, clientPoint, commandText,
    actionContext, options := 0) {
    return PrepareMxNMContextCommand(
        viewer, clientPoint, commandText, actionContext, options
    )
}

PrepareMxNMContextCommand(viewer, clientPoint, commandText,
    actionContext, options := 0) {
    existingPopups := SnapshotContextMeasurementPopups(
        viewer.pid,
        commandText
    )
    lParam := PackContextMeasurementClientPoint(clientPoint)
    rightDownSent := DllCall(
        "User32\PostMessageW",
        "Ptr", viewer.hwnd,
        "UInt", 0x0204,
        "UPtr", 0x0002,
        "Ptr", lParam,
        "Int"
    )
    rightUpSent := DllCall(
        "User32\PostMessageW",
        "Ptr", viewer.hwnd,
        "UInt", 0x0205,
        "UPtr", 0,
        "Ptr", lParam,
        "Int"
    )
    if !rightDownSent || !rightUpSent {
        actionContext["failureReason"] :=
            MeasurementFailureReason.COMMAND_INVOKE_FAILED
        return false
    }

    popupResult := WaitForContextMeasurementPopup(
        viewer.pid,
        existingPopups,
        commandText,
        options
    )
    if !popupResult.ok {
        actionContext["failureReason"] := popupResult.failureReason
        actionContext["popupHwnd"] := popupResult.popupHwnd
        actionContext["popupDiscovery"] := popupResult.discovery
        return false
    }

    actionContext["popupHwnd"] := popupResult.popupHwnd
    actionContext["popupDiscovery"] := popupResult.discovery
    actionContext["commandControlHwnd"] := popupResult.controlHwnd
    runtimeId := DllCall(
        "User32\GetDlgCtrlID",
        "Ptr", popupResult.controlHwnd,
        "Int"
    )
    actionContext["commandRuntimeId"] := runtimeId
    actionContext["expectedPid"] := viewer.pid
    if runtimeId <= 0 {
        actionContext["failureReason"] := MeasurementFailureReason.COMMAND_ID_INVALID
        return false
    }
    return true
}

InvokePreparedContextMeasurementCommand(actionContext) {
    return InvokePreparedMxNMContextCommand(actionContext)
}

InvokePreparedMxNMContextCommand(actionContext, asynchronous := false) {
    popupHwnd := actionContext["popupHwnd"]
    controlHwnd := actionContext["commandControlHwnd"]
    runtimeId := actionContext["commandRuntimeId"]
    if !popupHwnd || !controlHwnd || runtimeId <= 0 {
        actionContext["failureReason"] := MeasurementFailureReason.COMMAND_ID_INVALID
        return false
    }
    try {
        ; Revalidate the exact prepared command immediately before dispatch.
        if !Win32IsWindowVisible(popupHwnd)
            || !Win32IsWindowVisible(controlHwnd)
            || !Win32IsWindowEnabled(controlHwnd)
            || !Win32IsChild(popupHwnd, controlHwnd)
            || WinGetPID("ahk_id " popupHwnd) != actionContext["expectedPid"]
            || WinGetPID("ahk_id " controlHwnd) != actionContext["expectedPid"]
            || DllCall("User32\GetDlgCtrlID", "Ptr", controlHwnd, "Int") != runtimeId
            throw Error("Prepared context command changed")
        if asynchronous {
            dispatched := DllCall(
                "User32\PostMessageW",
                "Ptr", popupHwnd,
                "UInt", 0x0111,
                "UPtr", runtimeId,
                "Ptr", controlHwnd,
                "Int"
            )
            if !dispatched
                throw Error("Context command post failed")
        } else {
            commandResult := Buffer(A_PtrSize, 0)
            commandStartedAt := A_TickCount
            dispatched := DllCall(
                "User32\SendMessageTimeoutW",
                "Ptr", popupHwnd,
                "UInt", 0x0111,
                "UPtr", runtimeId,
                "Ptr", controlHwnd,
                "UInt", 0x0002,
                "UInt", 1000,
                "Ptr", commandResult.Ptr,
                "Ptr"
            )
            actionContext["commandElapsedMs"] := A_TickCount - commandStartedAt
            if !dispatched {
                ; The receiver may already have acted. Never replay this command.
                actionContext["failureReason"] := MeasurementFailureReason.COMMAND_RESULT_UNKNOWN
                return false
            }
        }
    } catch {
        actionContext["failureReason"] :=
            MeasurementFailureReason.COMMAND_INVOKE_FAILED
        return false
    }
    return true
}

PackContextMeasurementClientPoint(clientPoint) {
    return ((clientPoint.y & 0xFFFF) << 16) | (clientPoint.x & 0xFFFF)
}

SnapshotContextMeasurementPopups(viewerPid := 0, commandText := "") {
    snapshot := Map()
    for hwnd in ListContextMeasurementPopupWindows(viewerPid) {
        snapshot[hwnd] := CaptureContextMeasurementPopupState(
            hwnd,
            commandText
        )
    }
    return snapshot
}

ListContextMeasurementPopupWindows(viewerPid := 0) {
    detectHiddenBefore := A_DetectHiddenWindows
    popupWindows := []
    try {
        DetectHiddenWindows true
        try popupWindows := WinGetList(
            "ahk_class " ContextMeasurementDefaults.PopupClass
        )
        catch {
            popupWindows := []
        }
    } finally {
        DetectHiddenWindows detectHiddenBefore
    }
    if !viewerPid
        return popupWindows

    matches := []
    for hwnd in popupWindows {
        try popupPid := WinGetPID("ahk_id " hwnd)
        catch {
            popupPid := 0
        }
        if popupPid = viewerPid
            matches.Push(hwnd)
    }
    return matches
}

CaptureContextMeasurementPopupState(popupHwnd, commandText := "") {
    detectHiddenBefore := A_DetectHiddenWindows
    controls := []
    commandControlHwnd := 0
    try {
        DetectHiddenWindows true
        try controls := WinGetControlsHwnd("ahk_id " popupHwnd)
        catch {
            controls := []
        }
        if commandText != "" {
            commandControlHwnd := FindContextMeasurementCommandControl(
                popupHwnd,
                commandText,
                false
            )
        }
    } finally {
        DetectHiddenWindows detectHiddenBefore
    }
    rect := RectLTRB(Win32WindowRect(popupHwnd))
    return {
        visible: Win32IsWindowVisible(popupHwnd),
        rectKey: RectKey(rect),
        controlCount: controls.Length,
        commandControlHwnd: commandControlHwnd
    }
}

ContextMeasurementPopupStateChanged(before, current) {
    return before.visible != current.visible
        || before.rectKey != current.rectKey
        || before.controlCount != current.controlCount
        || before.commandControlHwnd != current.commandControlHwnd
}

WaitForContextMeasurementPopup(viewerPid, existingPopups, commandText,
    options := 0) {
    timeoutMs := MeasurementOption(
        options,
        "popupTimeoutMs",
        ContextMeasurementDefaults.PopupTimeoutMs
    )
    pollIntervalMs := MeasurementOption(
        options,
        "popupPollIntervalMs",
        ContextMeasurementDefaults.PopupPollIntervalMs
    )
    deadline := A_TickCount + Max(0, Integer(timeoutMs))
    candidatePopupHwnd := 0
    candidateDiscovery := ""
    loop {
        readyPopups := []
        for popupHwnd in ListContextMeasurementPopupWindows(viewerPid) {
            currentState := CaptureContextMeasurementPopupState(
                popupHwnd,
                commandText
            )
            discovery := "NEW_HANDLE"
            if existingPopups.Has(popupHwnd) {
                if !ContextMeasurementPopupStateChanged(
                    existingPopups[popupHwnd],
                    currentState
                ) {
                    continue
                }
                discovery := "STATE_CHANGED"
            }
            candidatePopupHwnd := popupHwnd
            candidateDiscovery := discovery
            controlHwnd := currentState.commandControlHwnd
            if !currentState.visible || !controlHwnd
                || !Win32IsWindowVisible(controlHwnd)
                || !Win32IsWindowEnabled(controlHwnd)
                continue
            readyPopups.Push({
                ok: true,
                popupHwnd: popupHwnd,
                controlHwnd: controlHwnd,
                discovery: discovery,
                failureReason: MeasurementFailureReason.NONE
            })
        }
        if readyPopups.Length = 1
            return readyPopups[1]
        if A_TickCount >= deadline
            break
        Sleep Max(1, Integer(pollIntervalMs))
    }
    return {
        ok: false,
        popupHwnd: candidatePopupHwnd,
        controlHwnd: 0,
        discovery: candidateDiscovery,
        failureReason: candidatePopupHwnd
            ? MeasurementFailureReason.COMMAND_NOT_FOUND
            : MeasurementFailureReason.POPUP_NOT_CREATED
    }
}

FindContextMeasurementCommandControl(
    popupHwnd,
    commandText,
    requireVisible := true
) {
    try controls := WinGetControlsHwnd("ahk_id " popupHwnd)
    catch {
        controls := []
    }
    matches := []
    for controlHwnd in controls {
        if requireVisible && !Win32IsWindowVisible(controlHwnd)
            continue
        try controlText := ControlGetText(controlHwnd)
        catch {
            controlText := ""
        }
        if controlText = commandText
            matches.Push(controlHwnd)
    }
    return matches.Length = 1 ? matches[1] : 0
}

CloseContextMeasurementPopup(popupHwnd) {
    if !popupHwnd || !WinExist("ahk_id " popupHwnd)
        return false
    return DllCall(
        "User32\PostMessageW",
        "Ptr", popupHwnd,
        "UInt", 0x0010,
        "UPtr", 0,
        "Ptr", 0,
        "Int"
    ) = true
}

MergeContextMeasurementMetadata(context, actionContext, capture) {
    context["popupHwnd"] := actionContext["popupHwnd"]
    context["popupDiscovery"] := actionContext["popupDiscovery"]
    context["commandControlHwnd"] := actionContext["commandControlHwnd"]
    context["commandRuntimeId"] := actionContext["commandRuntimeId"]
    context["commandElapsedMs"] := actionContext.Has("commandElapsedMs")
        ? actionContext["commandElapsedMs"] : 0
    context["requestId"] := capture.requestId
    context["clipboardSequenceBeforeCommand"] := capture.sequenceBeforeCommand
    context["clipboardSequenceAfterCommand"] := capture.sequenceAfterCommand
    context["clipboardOwnerHwnd"] := capture.clipboardOwnerHwnd
    context["clipboardCaptureSucceeded"] := capture.captureSucceeded
    context["clipboardRestoreAttempted"] := capture.restoreAttempted
    context["clipboardRestoreSucceeded"] := capture.restoreSucceeded
}
