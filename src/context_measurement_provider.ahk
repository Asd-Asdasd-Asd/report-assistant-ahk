class ContextMeasurementDefaults {
    static ViewerExe := "MedExNMFusion.exe"
    static SuvMaxCommandText := "复制SUVMax值"
    static PopupClass := "#32770"
    static PopupTimeoutMs := 1000
    static PopupPollIntervalMs := 20
    static ImagePointKey := "measurement_image_point"
}

class ContextMeasurementProvider {
    static ReadSuvMax(options := 0) {
        return ReadCurrentSuvMaxWithoutFocusSwitch(options)
    }
}

ReadCurrentSuvMaxWithoutFocusSwitch(options := 0) {
    context := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "viewerExe", MeasurementOption(
            options,
            "viewerExe",
            ContextMeasurementDefaults.ViewerExe
        ),
        "commandText", ContextMeasurementDefaults.SuvMaxCommandText,
        "focusSwitchAttempted", false,
        "mouseMoveAttempted", false,
        "popupHwnd", 0,
        "commandControlHwnd", 0,
        "commandRuntimeId", 0,
        "clipboardOwnerHwnd", 0
    )

    viewer := ResolveContextMeasurementViewer(context["viewerExe"])
    if !viewer.ok {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            MeasurementType.SUVMAX,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            viewer.failureReason,
            context
        )
    }
    context["viewerHwnd"] := viewer.hwnd
    context["viewerPid"] := viewer.pid

    pointResult := ResolveContextMeasurementImagePoint(
        viewer.hwnd,
        options
    )
    if !pointResult.ok {
        return MakeMeasurementResult(
            MeasurementState.AUTOMATION_FAILED,
            MeasurementType.SUVMAX,
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
        "commandControlHwnd", 0,
        "commandRuntimeId", 0
    )
    try {
        capture := CaptureMeasurementClipboardText(
            () => InvokePreparedContextMeasurementCommand(actionContext),
            options,
            () => PrepareContextMeasurementCopyCommand(
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
            MeasurementType.SUVMAX,
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
            MeasurementType.SUVMAX,
            "",
            "",
            MeasurementSource.MXNM_CONTEXT_COMMAND,
            failureReason,
            context
        )
    }

    result := ParseSuvMaxMeasurement(capture.rawText)
    result.context := context
    return result
}

ResolveContextMeasurementViewer(viewerExe) {
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

ResolveContextMeasurementImagePoint(viewerHwnd, options := 0) {
    resolver := MeasurementOption(options, "imagePointResolver", 0)
    if IsObject(resolver) && HasMethod(resolver, "Call") {
        try point := resolver.Call(viewerHwnd)
        catch {
            point := 0
        }
    } else {
        point := MeasurementOption(options, "imageScreenPoint", 0)
        if !IsContextMeasurementPoint(point) {
            global COORDINATES
            if IsSet(COORDINATES) && Type(COORDINATES) = "Map"
                && COORDINATES.Has(ContextMeasurementDefaults.ImagePointKey) {
                point := COORDINATES[ContextMeasurementDefaults.ImagePointKey]
            }
        }
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
    if !ContextMeasurementPointInsideVirtualScreen(screenPoint) {
        return {
            ok: false,
            screenPoint: screenPoint,
            clientPoint: 0,
            failureReason: MeasurementFailureReason.IMAGE_POINT_OUT_OF_BOUNDS
        }
    }

    clientRectScreen := GetContextMeasurementClientRectScreen(viewerHwnd)
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

    clientPoint := ContextMeasurementScreenToClient(viewerHwnd, screenPoint)
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

ContextMeasurementPointInsideVirtualScreen(point) {
    left := SysGet(76)
    top := SysGet(77)
    width := SysGet(78)
    height := SysGet(79)
    return width > 0
        && height > 0
        && point.x >= left
        && point.x < left + width
        && point.y >= top
        && point.y < top + height
}

GetContextMeasurementClientRectScreen(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall("User32\GetClientRect", "Ptr", hwnd, "Ptr", rectBuffer.Ptr, "Int")
        return 0

    topLeft := Buffer(8, 0)
    bottomRight := Buffer(8, 0)
    NumPut("Int", NumGet(rectBuffer, 0, "Int"), topLeft, 0)
    NumPut("Int", NumGet(rectBuffer, 4, "Int"), topLeft, 4)
    NumPut("Int", NumGet(rectBuffer, 8, "Int"), bottomRight, 0)
    NumPut("Int", NumGet(rectBuffer, 12, "Int"), bottomRight, 4)
    if !DllCall("User32\ClientToScreen", "Ptr", hwnd, "Ptr", topLeft.Ptr, "Int")
        return 0
    if !DllCall("User32\ClientToScreen", "Ptr", hwnd, "Ptr", bottomRight.Ptr, "Int")
        return 0
    return {
        l: NumGet(topLeft, 0, "Int"),
        t: NumGet(topLeft, 4, "Int"),
        r: NumGet(bottomRight, 0, "Int"),
        b: NumGet(bottomRight, 4, "Int")
    }
}

ContextMeasurementScreenToClient(hwnd, screenPoint) {
    pointBuffer := Buffer(8, 0)
    NumPut("Int", screenPoint.x, pointBuffer, 0)
    NumPut("Int", screenPoint.y, pointBuffer, 4)
    if !DllCall("User32\ScreenToClient", "Ptr", hwnd, "Ptr", pointBuffer.Ptr, "Int")
        return 0
    return {
        x: NumGet(pointBuffer, 0, "Int"),
        y: NumGet(pointBuffer, 4, "Int")
    }
}

PrepareContextMeasurementCopyCommand(viewer, clientPoint, commandText,
    actionContext, options := 0) {
    existingPopups := SnapshotContextMeasurementPopups()
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
        return false
    }

    actionContext["popupHwnd"] := popupResult.popupHwnd
    actionContext["commandControlHwnd"] := popupResult.controlHwnd
    runtimeId := DllCall(
        "User32\GetDlgCtrlID",
        "Ptr", popupResult.controlHwnd,
        "Int"
    )
    actionContext["commandRuntimeId"] := runtimeId
    if runtimeId <= 0 {
        actionContext["failureReason"] := MeasurementFailureReason.COMMAND_ID_INVALID
        return false
    }
    return true
}

InvokePreparedContextMeasurementCommand(actionContext) {
    popupHwnd := actionContext["popupHwnd"]
    controlHwnd := actionContext["commandControlHwnd"]
    runtimeId := actionContext["commandRuntimeId"]
    if !popupHwnd || !controlHwnd || runtimeId <= 0 {
        actionContext["failureReason"] := MeasurementFailureReason.COMMAND_ID_INVALID
        return false
    }
    try {
        DllCall(
            "User32\SendMessageW",
            "Ptr", popupHwnd,
            "UInt", 0x0111,
            "UPtr", runtimeId,
            "Ptr", controlHwnd,
            "Ptr"
        )
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

SnapshotContextMeasurementPopups() {
    snapshot := Map()
    try popupWindows := WinGetList(
        "ahk_class " ContextMeasurementDefaults.PopupClass
    )
    catch {
        popupWindows := []
    }
    for hwnd in popupWindows
        snapshot[hwnd] := true
    return snapshot
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
    newPopupHwnd := 0
    loop {
        try popupWindows := WinGetList(
            "ahk_class " ContextMeasurementDefaults.PopupClass
        )
        catch {
            popupWindows := []
        }
        for popupHwnd in popupWindows {
            if existingPopups.Has(popupHwnd)
                continue
            try popupPid := WinGetPID("ahk_id " popupHwnd)
            catch {
                popupPid := 0
            }
            if popupPid != viewerPid
                continue
            newPopupHwnd := popupHwnd
            controlHwnd := FindContextMeasurementCommandControl(
                popupHwnd,
                commandText
            )
            if controlHwnd {
                return {
                    ok: true,
                    popupHwnd: popupHwnd,
                    controlHwnd: controlHwnd,
                    failureReason: MeasurementFailureReason.NONE
                }
            }
        }
        if A_TickCount >= deadline
            break
        Sleep Max(1, Integer(pollIntervalMs))
    }
    return {
        ok: false,
        popupHwnd: newPopupHwnd,
        controlHwnd: 0,
        failureReason: newPopupHwnd
            ? MeasurementFailureReason.COMMAND_NOT_FOUND
            : MeasurementFailureReason.POPUP_NOT_CREATED
    }
}

FindContextMeasurementCommandControl(popupHwnd, commandText) {
    try controls := WinGetControlsHwnd("ahk_id " popupHwnd)
    catch {
        controls := []
    }
    for controlHwnd in controls {
        if !DllCall("User32\IsWindowVisible", "Ptr", controlHwnd, "Int")
            continue
        try controlText := ControlGetText(controlHwnd)
        catch {
            controlText := ""
        }
        if controlText = commandText
            return controlHwnd
    }
    return 0
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
    context["commandControlHwnd"] := actionContext["commandControlHwnd"]
    context["commandRuntimeId"] := actionContext["commandRuntimeId"]
    context["requestId"] := capture.requestId
    context["clipboardSequenceBeforeCommand"] := capture.sequenceBeforeCommand
    context["clipboardSequenceAfterCommand"] := capture.sequenceAfterCommand
    context["clipboardOwnerHwnd"] := capture.clipboardOwnerHwnd
    context["clipboardCaptureSucceeded"] := capture.captureSucceeded
    context["clipboardRestoreAttempted"] := capture.restoreAttempted
    context["clipboardRestoreSucceeded"] := capture.restoreSucceeded
}
