; Generated synthetic regression; never operates MedEx.

#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn

class MeasurementFailureReason {
    static NONE := ""
    static INVALID_MEASUREMENT_SPEC := "INVALID_MEASUREMENT_SPEC"
    static PROVIDER_BUSY := "PROVIDER_BUSY"
    static VIEWER_NOT_FOUND := "VIEWER_NOT_FOUND"
    static VIEWER_AMBIGUOUS := "VIEWER_AMBIGUOUS"
    static VIEWER_TARGET_CHANGED := "VIEWER_TARGET_CHANGED"
    static IMAGE_POINT_UNAVAILABLE := "IMAGE_POINT_UNAVAILABLE"
    static IMAGE_POINT_OUT_OF_BOUNDS := "IMAGE_POINT_OUT_OF_BOUNDS"
    static POPUP_NOT_CREATED := "POPUP_NOT_CREATED"
    static COMMAND_NOT_FOUND := "COMMAND_NOT_FOUND"
    static COMMAND_ID_INVALID := "COMMAND_ID_INVALID"
    static COMMAND_INVOKE_FAILED := "COMMAND_INVOKE_FAILED"
    static COMMAND_RESULT_UNKNOWN := "COMMAND_RESULT_UNKNOWN"
    static CONFIRMATION_REQUIRED := "CONFIRMATION_REQUIRED"
    static CLEANUP_NOT_VERIFIED := "CLEANUP_NOT_VERIFIED"
    static CLIPBOARD_SAVE_FAILED := "CLIPBOARD_SAVE_FAILED"
    static CLIPBOARD_SENTINEL_FAILED := "CLIPBOARD_SENTINEL_FAILED"
    static CLIPBOARD_ACTION_FAILED := "CLIPBOARD_ACTION_FAILED"
    static CLIPBOARD_NOT_UPDATED := "CLIPBOARD_NOT_UPDATED"
    static CLIPBOARD_READ_FAILED := "CLIPBOARD_READ_FAILED"
    static CLIPBOARD_RESTORE_FAILED := "CLIPBOARD_RESTORE_FAILED"
    static UNEXPECTED_FORMAT := "UNEXPECTED_FORMAT"
    static UNEXPECTED_ERROR := "UNEXPECTED_ERROR"
}



class MeasurementClipboardDefaults {
    static UpdateTimeoutMs := 1000
    static PollIntervalMs := 20
    static SentinelTimeoutSeconds := 0.5
    static RestoreSettleMs := 100
    static EmptyResultSettleMs := 40
}



WaitForMeasurementClipboardUpdate(sequenceBeforeCommand, sentinel, options := 0) {
    timeoutMs := MeasurementOption(
        options,
        "clipboardTimeoutMs",
        MeasurementClipboardDefaults.UpdateTimeoutMs
    )
    pollIntervalMs := MeasurementOption(
        options,
        "clipboardPollIntervalMs",
        MeasurementClipboardDefaults.PollIntervalMs
    )
    deadline := A_TickCount + Max(0, Integer(timeoutMs))
    acceptEmptyClipboard := MeasurementOption(
        options, "acceptEmptyClipboard", false
    )
    emptyResultSettleMs := MeasurementOption(
        options,
        "emptyResultSettleMs",
        MeasurementClipboardDefaults.EmptyResultSettleMs
    )
    lastSequence := sequenceBeforeCommand
    emptySequence := 0
    emptyDeadline := 0
    readFailed := false
    loop {
        sequence := GetMeasurementClipboardSequenceNumber()
        if sequence != sequenceBeforeCommand {
            lastSequence := sequence
            try {
                rawText := ReadTestClipboard()
                readFailed := false
            }
            catch {
                readFailed := true
                ; An inaccessible clipboard is not a successfully read empty result.
                emptySequence := 0
                emptyDeadline := 0
                if A_TickCount >= deadline
                    break
                Sleep Max(1, Integer(pollIntervalMs))
                continue
            }
            if rawText != "" && rawText != sentinel {
                ownerHwnd := DllCall("User32\GetClipboardOwner", "Ptr")
                return {
                    ok: true,
                    rawText: rawText,
                    sequence: sequence,
                    ownerHwnd: ownerHwnd
                }
            }
            if acceptEmptyClipboard && rawText = "" {
                if sequence != emptySequence {
                    emptySequence := sequence
                    emptyDeadline := A_TickCount
                        + Max(0, Integer(emptyResultSettleMs))
                }
                if A_TickCount >= emptyDeadline {
                    return {
                        ok: true,
                        rawText: "",
                        sequence: sequence,
                        ownerHwnd: DllCall(
                            "User32\GetClipboardOwner", "Ptr"
                        )
                    }
                }
            }
        }
        if A_TickCount >= deadline
            break
        Sleep Max(1, Integer(pollIntervalMs))
    }
    return {
        ok: false,
        rawText: "",
        sequence: lastSequence,
        ownerHwnd: 0,
        failureReason: readFailed ? MeasurementFailureReason.CLIPBOARD_READ_FAILED
            : MeasurementFailureReason.CLIPBOARD_NOT_UPDATED
    }
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
        if !DllCall("User32\IsWindowVisible", "Ptr", popupHwnd, "Int")
            || !DllCall("User32\IsWindowVisible", "Ptr", controlHwnd, "Int")
            || !DllCall("User32\IsWindowEnabled", "Ptr", controlHwnd, "Int")
            || !DllCall("User32\IsChild", "Ptr", popupHwnd, "Ptr", controlHwnd, "Int")
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



; Synthetic clipboard errors and native command dispatch. No clinical application.
global ReadinessSamples := []
global ReadinessSampleIndex := 0
global ReadinessSequence := 2

try {
    TestReadinessClipboard()
    TestReadinessCommand()
    FileAppend "Readiness regression: PASS" Chr(10), "*"
    ExitApp 0
} catch as readinessError {
    FileAppend "Readiness regression: FAIL - " readinessError.Message Chr(10), "**"
    ExitApp 1
}

MeasurementOption(options, key, fallback := 0) {
    return Type(options) = "Map" && options.Has(key) ? options[key] : fallback
}

GetMeasurementClipboardSequenceNumber() {
    global ReadinessSequence
    return ReadinessSequence
}

ReadTestClipboard() {
    global ReadinessSamples, ReadinessSampleIndex
    ReadinessSampleIndex += 1
    sample := ReadinessSamples[Min(ReadinessSampleIndex, ReadinessSamples.Length)]
    if IsObject(sample)
        throw Error("Synthetic clipboard temporarily inaccessible")
    return sample
}

ReadinessCapture(samples, sequence := 2) {
    global ReadinessSamples, ReadinessSampleIndex, ReadinessSequence
    ReadinessSamples := samples
    ReadinessSampleIndex := 0
    ReadinessSequence := sequence
    return WaitForMeasurementClipboardUpdate(1, "__sentinel__", Map(
        "clipboardTimeoutMs", 120, "clipboardPollIntervalMs", 10,
        "acceptEmptyClipboard", true, "emptyResultSettleMs", 30
    ))
}

AssertReadiness(condition, label) {
    if !condition
        throw Error(label)
}

TestReadinessClipboard() {
    result := ReadinessCapture([{}])
    AssertReadiness(!result.ok && result.failureReason = "CLIPBOARD_READ_FAILED",
        "read exceptions must not become an empty measurement")
    result := ReadinessCapture([""])
    AssertReadiness(result.ok && result.rawText = "", "genuine empty result")
    result := ReadinessCapture([{}, {}, "7.5"])
    AssertReadiness(result.ok && result.rawText = "7.5", "transient read error recovers")
    result := ReadinessCapture(["", {}, "", "", "", ""])
    AssertReadiness(result.ok && result.rawText = "", "empty settle restarts after error")
    result := ReadinessCapture(["7.5"], 1)
    AssertReadiness(!result.ok, "unchanged sequence is not fresh")
    result := ReadinessCapture(["__sentinel__"])
    AssertReadiness(!result.ok, "sentinel is never a result")
}

TestReadinessCommand() {
    panel := Gui("+ToolWindow")
    button := panel.AddButton("w100", "Synthetic")
    panel.Show("NoActivate w140 h80")
    try {
        action := Map("popupHwnd", panel.Hwnd, "commandControlHwnd", button.Hwnd,
            "commandRuntimeId", DllCall("User32\GetDlgCtrlID", "Ptr", button.Hwnd, "Int"),
            "expectedPid", DllCall("Kernel32\GetCurrentProcessId", "UInt"),
            "failureReason", "")
        button.Enabled := false
        AssertReadiness(!InvokePreparedMxNMContextCommand(action), "disabled target rejected")
        button.Enabled := true
        action["commandRuntimeId"] += 1
        AssertReadiness(!InvokePreparedMxNMContextCommand(action), "changed command ID rejected")
        action["commandRuntimeId"] -= 1
        AssertReadiness(InvokePreparedMxNMContextCommand(action), "live command dispatch")
        panel.Hide()
        AssertReadiness(!InvokePreparedMxNMContextCommand(action), "hidden popup rejected")
    } finally {
        panel.Destroy()
    }
}
