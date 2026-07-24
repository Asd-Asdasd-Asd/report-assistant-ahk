class MeasurementClipboardDefaults {
    static UpdateTimeoutMs := 1000
    static PollIntervalMs := 20
    static SentinelTimeoutSeconds := 0.5
    static RestoreSettleMs := 100
}

CaptureMeasurementClipboardText(actionCallback, options := 0,
    prepareCallback := 0) {
    static busy := false
    result := {
        ok: false,
        captureSucceeded: false,
        restoreAttempted: false,
        restoreSucceeded: false,
        rawText: "",
        failureReason: MeasurementFailureReason.NONE,
        requestId: "",
        sequenceBeforeCommand: 0,
        sequenceAfterCommand: 0,
        clipboardOwnerHwnd: 0,
        prepareError: "",
        actionError: "",
        restoreError: ""
    }

    if busy {
        result.failureReason := MeasurementFailureReason.PROVIDER_BUSY
        return result
    }
    if !HasMethod(actionCallback, "Call") {
        result.failureReason := MeasurementFailureReason.CLIPBOARD_ACTION_FAILED
        return result
    }

    busy := true
    clipboardSaved := false
    try {
        try {
            savedClipboard := ClipboardAll()
            clipboardSaved := true
        } catch as err {
            result.failureReason := MeasurementFailureReason.CLIPBOARD_SAVE_FAILED
            result.actionError := err.Message
            return result
        }

        result.requestId := BuildMeasurementClipboardRequestId()
        sentinel := "__MEDEX_MEASUREMENT_" result.requestId "__"
        try {
            A_Clipboard := sentinel
            sentinelTimeout := MeasurementOption(
                options,
                "sentinelTimeoutSeconds",
                MeasurementClipboardDefaults.SentinelTimeoutSeconds
            )
            if !ClipWait(sentinelTimeout)
                result.failureReason := MeasurementFailureReason.CLIPBOARD_SENTINEL_FAILED
            else if A_Clipboard != sentinel
                result.failureReason := MeasurementFailureReason.CLIPBOARD_SENTINEL_FAILED
        } catch as err {
            result.failureReason := MeasurementFailureReason.CLIPBOARD_SENTINEL_FAILED
            result.actionError := err.Message
        }
        if result.failureReason != MeasurementFailureReason.NONE
            return result

        if IsObject(prepareCallback) && HasMethod(prepareCallback, "Call") {
            try {
                if prepareCallback.Call() != true {
                    result.failureReason :=
                        MeasurementFailureReason.CLIPBOARD_ACTION_FAILED
                    return result
                }
            } catch as err {
                result.failureReason :=
                    MeasurementFailureReason.CLIPBOARD_ACTION_FAILED
                result.prepareError := err.Message
                return result
            }
        }

        ; Record freshness only after popup/command preparation. This prevents a
        ; clipboard change during popup discovery from being attributed to the
        ; command that has not yet been sent.
        result.sequenceBeforeCommand := GetMeasurementClipboardSequenceNumber()
        try {
            if actionCallback.Call() != true {
                result.failureReason := MeasurementFailureReason.CLIPBOARD_ACTION_FAILED
                return result
            }
        } catch as err {
            result.failureReason := MeasurementFailureReason.CLIPBOARD_ACTION_FAILED
            result.actionError := err.Message
            return result
        }

        update := WaitForMeasurementClipboardUpdate(
            result.sequenceBeforeCommand,
            sentinel,
            options
        )
        result.sequenceAfterCommand := update.sequence
        result.clipboardOwnerHwnd := update.ownerHwnd
        if !update.ok {
            result.failureReason := MeasurementFailureReason.CLIPBOARD_NOT_UPDATED
            return result
        }

        result.rawText := update.rawText
        result.captureSucceeded := true
    } finally {
        if clipboardSaved {
            result.restoreAttempted := true
            try {
                A_Clipboard := savedClipboard
                Sleep MeasurementOption(
                    options,
                    "restoreSettleMs",
                    MeasurementClipboardDefaults.RestoreSettleMs
                )
                result.restoreSucceeded := true
            } catch as err {
                result.restoreError := err.Message
                result.failureReason := MeasurementFailureReason.CLIPBOARD_RESTORE_FAILED
            }
        }
        busy := false
    }

    if result.captureSucceeded && result.restoreSucceeded
        result.ok := true
    else if result.failureReason = MeasurementFailureReason.NONE
        result.failureReason := MeasurementFailureReason.CLIPBOARD_RESTORE_FAILED
    return result
}

BuildMeasurementClipboardRequestId() {
    static requestCounter := 0
    requestCounter += 1
    return Format("{:X}_{:X}_{}", A_TickCount, A_ScriptHwnd, requestCounter)
}

GetMeasurementClipboardSequenceNumber() {
    return DllCall("User32\GetClipboardSequenceNumber", "UInt")
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
    lastSequence := sequenceBeforeCommand
    loop {
        sequence := GetMeasurementClipboardSequenceNumber()
        if sequence != sequenceBeforeCommand {
            lastSequence := sequence
            try rawText := A_Clipboard
            catch {
                rawText := ""
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
        }
        if A_TickCount >= deadline
            break
        Sleep Max(1, Integer(pollIntervalMs))
    }
    return {
        ok: false,
        rawText: "",
        sequence: lastSequence,
        ownerHwnd: 0
    }
}
