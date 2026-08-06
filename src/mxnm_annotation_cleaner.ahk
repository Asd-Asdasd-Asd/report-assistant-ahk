class MxNMAnnotationCleanupDefaults {
    static DeleteAllCommandText := "删除全部标注"
    static ConfirmationProbeMs := 500
    static ConfirmationPollIntervalMs := 20
    static ProductionEnabled := true
}

class MxNMAnnotationCleanupCode {
    static OK := "OK"
    static TARGET_UNAVAILABLE := "TARGET_UNAVAILABLE"
    static TARGET_CLIENT_POINT_INVALID := "TARGET_CLIENT_POINT_INVALID"
    static TARGET_CHANGED := "TARGET_CHANGED"
    static COMMAND_FAILED := "COMMAND_FAILED"
    static CONFIRMATION_REQUIRED := "CONFIRMATION_REQUIRED"
    static CLEANUP_NOT_VERIFIED := "CLEANUP_NOT_VERIFIED"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}

class MxNMAnnotationCleanupVerificationMode {
    static COMMAND_ONLY := "command_only"
}

class MxNMAnnotationCleaner {
    static DeleteAll(expectedViewerHwnd := 0, expectedViewerPid := 0,
        options := 0,
        cleanupMeasurementType := MeasurementType.SUVMAX) {
        return DeleteAllMxNMAnnotations(
            expectedViewerHwnd,
            expectedViewerPid,
            options,
            cleanupMeasurementType
        )
    }
}

DeleteAllMxNMAnnotations(expectedViewerHwnd := 0, expectedViewerPid := 0,
    options := 0,
    cleanupMeasurementType := MeasurementType.SUVMAX) {
    result := {
        ok: false,
        code: MxNMAnnotationCleanupCode.UNEXPECTED_ERROR,
        failureReason: MeasurementFailureReason.UNEXPECTED_ERROR,
        commandInvoked: false,
        confirmationDetected: false,
        verificationState: "",
        context: Map()
    }
    actionContext := Map(
        "failureReason", MeasurementFailureReason.NONE,
        "popupHwnd", 0,
        "popupDiscovery", "",
        "commandControlHwnd", 0,
        "commandRuntimeId", 0
    )
    try {
        target := MxNMMeasurementProvider.ResolveTarget(options)
        result.context["targetCode"] := target.code
        result.context["targetConfigCode"] := target.configCode
        result.context["targetLayoutCode"] := target.layoutCode
        result.context["targetRuntimeFrameCandidateCount"] :=
            target.runtimeFrameCandidateCount
        result.context["targetRuntimeFrameOwnerFamilyCount"] :=
            target.runtimeFrameOwnerFamilyCount
        result.context["targetRuntimeToolAnchorResolved"] :=
            target.runtimeToolAnchorResolved
        result.context["targetRuntimeToolAnchorUsed"] :=
            target.runtimeToolAnchorUsed
        result.context["targetRuntimeToolAnchorFallbackCode"] :=
            target.runtimeToolAnchorFallbackCode
        result.context["targetRuntimeSurfaceSelectionCode"] :=
            target.runtimeSurfaceSelectionCode
        result.context["targetRuntimePointSource"] :=
            target.runtimePointSource
        if !target.ok {
            result.context["failureStage"] := "TARGET_RESOLVE"
            result.code := MxNMAnnotationCleanupCode.TARGET_UNAVAILABLE
            result.failureReason :=
                MeasurementFailureReason.IMAGE_POINT_UNAVAILABLE
            return result
        }
        if (expectedViewerHwnd && target.actionHwnd != expectedViewerHwnd)
            || (expectedViewerPid && target.actionPid != expectedViewerPid) {
            result.code := MxNMAnnotationCleanupCode.TARGET_CHANGED
            result.failureReason :=
                MeasurementFailureReason.VIEWER_TARGET_CHANGED
            return result
        }

        clientPoint := target.actionClientPoint
        if !IsContextMeasurementPoint(clientPoint) {
            result.context["failureStage"] := "TARGET_CLIENT_POINT"
            result.code :=
                MxNMAnnotationCleanupCode.TARGET_CLIENT_POINT_INVALID
            result.failureReason :=
                MeasurementFailureReason.IMAGE_POINT_UNAVAILABLE
            return result
        }
        viewer := {
            hwnd: target.actionHwnd,
            pid: target.actionPid
        }
        dialogSnapshot := SnapshotMxNMViewerDialogs(target.actionPid)
        prepared := PrepareMxNMContextCommand(
            viewer,
            clientPoint,
            MxNMAnnotationCleanupDefaults.DeleteAllCommandText,
            actionContext,
            options
        )
        result.context["popupHwnd"] := actionContext["popupHwnd"]
        result.context["popupDiscovery"] :=
            actionContext["popupDiscovery"]
        if !prepared {
            result.code := MxNMAnnotationCleanupCode.COMMAND_FAILED
            result.failureReason := actionContext["failureReason"]
            return result
        }
        ; Delete may open a modal confirmation. Post the command so this
        ; process remains able to detect and close that owned dialog.
        if !InvokePreparedMxNMContextCommand(actionContext, true) {
            result.code := MxNMAnnotationCleanupCode.COMMAND_FAILED
            result.failureReason := actionContext["failureReason"]
            return result
        }
        result.commandInvoked := true
        confirmationHwnd := WaitForNewMxNMViewerDialog(
            target.actionPid,
            dialogSnapshot,
            actionContext["popupHwnd"],
            MxNMAnnotationCleanupDefaults.ConfirmationProbeMs
        )
        if confirmationHwnd {
            result.confirmationDetected := true
            CloseOwnedMxNMViewerDialog(confirmationHwnd)
            result.code :=
                MxNMAnnotationCleanupCode.CONFIRMATION_REQUIRED
            result.failureReason :=
                MeasurementFailureReason.CONFIRMATION_REQUIRED
            return result
        }
    } catch as err {
        result.context["exceptionType"] := Type(err)
        result.code := MxNMAnnotationCleanupCode.UNEXPECTED_ERROR
        result.failureReason := MeasurementFailureReason.UNEXPECTED_ERROR
        return result
    } finally {
        if actionContext["popupHwnd"]
            CloseContextMeasurementPopup(actionContext["popupHwnd"])
    }

    if cleanupMeasurementType = MxNMAnnotationCleanupVerificationMode.COMMAND_ONLY {
        result.ok := true
        result.code := MxNMAnnotationCleanupCode.OK
        result.failureReason := MeasurementFailureReason.NONE
        return result
    }

    verificationOptions := CloneMeasurementOptions(options)
    verificationOptions["expectedViewerHwnd"] := expectedViewerHwnd
    verificationOptions["expectedViewerPid"] := expectedViewerPid
    verification := cleanupMeasurementType = MeasurementType.LINE_AXES
        ? MxNMMeasurementProvider.ReadLineAxes(verificationOptions)
        : MxNMMeasurementProvider.ReadSuvMax(verificationOptions)
    result.verificationState := verification.state
    if verification.state != MeasurementState.NOT_ANNOTATED {
        result.code := MxNMAnnotationCleanupCode.CLEANUP_NOT_VERIFIED
        result.failureReason :=
            MeasurementFailureReason.CLEANUP_NOT_VERIFIED
        return result
    }
    result.ok := true
    result.code := MxNMAnnotationCleanupCode.OK
    result.failureReason := MeasurementFailureReason.NONE
    return result
}

SnapshotMxNMViewerDialogs(viewerPid) {
    snapshot := Map()
    try dialogs := WinGetList("ahk_class #32770")
    catch {
        dialogs := []
    }
    for hwnd in dialogs {
        try dialogPid := WinGetPID("ahk_id " hwnd)
        catch {
            dialogPid := 0
        }
        if dialogPid = viewerPid
            snapshot[hwnd] := true
    }
    return snapshot
}

FindNewMxNMViewerDialog(viewerPid, snapshot, ownedPopupHwnd := 0) {
    try dialogs := WinGetList("ahk_class #32770")
    catch {
        dialogs := []
    }
    for hwnd in dialogs {
        if hwnd = ownedPopupHwnd || snapshot.Has(hwnd)
            continue
        try dialogPid := WinGetPID("ahk_id " hwnd)
        catch {
            dialogPid := 0
        }
        if dialogPid = viewerPid
            return hwnd
    }
    return 0
}

WaitForNewMxNMViewerDialog(
    viewerPid,
    snapshot,
    ownedPopupHwnd,
    timeoutMs
) {
    deadline := A_TickCount + Max(0, Integer(timeoutMs))
    loop {
        dialogHwnd := FindNewMxNMViewerDialog(
            viewerPid,
            snapshot,
            ownedPopupHwnd
        )
        if dialogHwnd
            return dialogHwnd
        if A_TickCount >= deadline
            return 0
        Sleep MxNMAnnotationCleanupDefaults.ConfirmationPollIntervalMs
    }
}

CloseOwnedMxNMViewerDialog(hwnd) {
    if !hwnd || !WinExist("ahk_id " hwnd)
        return false
    return DllCall(
        "User32\PostMessageW",
        "Ptr", hwnd,
        "UInt", 0x0010,
        "UPtr", 0,
        "Ptr", 0,
        "Int"
    ) = true
}
