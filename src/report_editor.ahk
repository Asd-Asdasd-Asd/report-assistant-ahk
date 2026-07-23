class ReportEditorTimingDefaults {
    ; MedEx commits CF_HTML asynchronously. Give the red marker time to set the
    ; final caret before moving left; this wait remains inside the 300 ms
    ; paste-to-clipboard-restore safety interval.
    static RedCaretAfterPasteSettleMs := 60
}

FocusReportEditor() {
    return RequireReportEditor()
}

RunRedInsertion(resetOptions := 0) {
    return RunRedResetInsertion("（见图）", resetOptions)
}

RunRedResetInsertion(text, resetOptions := 0) {
    performanceContext := MedExAdapterOption(resetOptions, "performanceContext", 0)
    RecordOptionalPerformanceTimestampAliases(
        performanceContext,
        ["HotstringTriggeredMs", "HotstringStartMs"]
    )
    operation := InsertRedFigureTextAndRestoreState(text, resetOptions)
    RecordOptionalPerformanceTimestampAliases(
        performanceContext,
        ["FunctionReturnedMs", "HotstringReturnMs"]
    )
    return operation
}

RunRedCaretInsertion(text, caretLeftCount, resetOptions := 0) {
    if caretLeftCount < 1
        return false
    performanceContext := MedExAdapterOption(resetOptions, "performanceContext", 0)
    RecordOptionalPerformanceTimestamp(performanceContext, "HotstringStartMs")
    operation := InsertRedFigureTextForCaretRelocation(
        text,
        caretLeftCount,
        performanceContext,
        resetOptions
    )
    RecordOptionalPerformanceTimestamp(performanceContext, "HotstringReturnMs")
    return operation
}

; Field-debug compatibility wrapper. Production templates do not dispatch by
; legacy mode or section identity.
RunFzgInsertion(resetOptions := 0) {
    return RunRedCaretInsertion(
        "放射性摄取增高，SUVmax约（见图）",
        4,
        resetOptions
    )
}

InsertRedFigureTextForCaretRelocation(text, caretLeftCount,
    performanceContext := 0, resetOptions := 0) {
    cursorContext := Map(
        "cursorRestoreRequestedCount", caretLeftCount,
        "cursorRestoreCommandSent", false,
        "foregroundHwndBeforeCursorRestore", "UNKNOWN",
        "cursorRestoreTargetHwnd", "UNKNOWN"
    )
    pasteResult := PasteRedFigureTextDetailed(
        text,
        performanceContext,
        () => SendRedFigureCaretRelocation(
            cursorContext,
            caretLeftCount,
            performanceContext,
            resetOptions
        )
    )
    if !pasteResult.pasteDispatched {
        return {
            ok: false,
            code: RedTextOperationCode.PASTE_FAILED,
            pasteDispatched: false,
            clipboardRestoreSucceeded: pasteResult.clipboardRestoreSucceeded,
            reset: 0
        }
    }

    resetContext := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "appVersion", AppMetadata.Version,
        "colorResetStrategy", "notRequiredForCaretRelocation",
        "colorResetReason", "caretMovesBeforeRedMarker",
        "foregroundWindowHandle", cursorContext["cursorRestoreTargetHwnd"],
        "automationChainResult", ColorResetCode.NOT_REQUIRED,
        "finalValidationState", "NOT_APPLICABLE",
        "finalInsertionColorVisuallyValidated", false
    )
    MergeContext(resetContext, cursorContext)
    if !pasteResult.beforeRestoreSucceeded {
        resetContext["automationChainResult"] := ColorResetCode.UNEXPECTED_ERROR
        resetContext["cursorRestoreError"] := pasteResult.beforeRestoreError
        return {
            ok: false,
            code: RedTextOperationCode.CURSOR_RESTORE_FAILED,
            pasteDispatched: true,
            clipboardRestoreSucceeded: pasteResult.clipboardRestoreSucceeded,
            reset: MakeColorResetResult(
                false,
                ColorResetCode.UNEXPECTED_ERROR,
                resetContext
            )
        }
    }
    if !pasteResult.clipboardRestoreSucceeded {
        return {
            ok: false,
            code: RedTextOperationCode.CLIPBOARD_RESTORE_FAILED,
            pasteDispatched: true,
            clipboardRestoreSucceeded: false,
            reset: 0
        }
    }
    return {
        ok: true,
        code: RedTextOperationCode.OK,
        pasteDispatched: true,
        clipboardRestoreSucceeded: true,
        reset: MakeColorResetResult(true, ColorResetCode.NOT_REQUIRED, resetContext)
    }
}

SendRedFigureCaretRelocation(cursorContext, caretLeftCount,
    performanceContext := 0, resetOptions := 0) {
    foregroundHwnd := WinExist("A")
    formattedHwnd := foregroundHwnd ? Format("0x{:X}", foregroundHwnd) : "UNKNOWN"
    cursorContext["foregroundHwndBeforeCursorRestore"] := formattedHwnd
    cursorContext["cursorRestoreTargetHwnd"] := formattedHwnd
    if MedExAdapterOption(resetOptions, "collectFocusDiagnostics", false)
        MergeContext(cursorContext,
            CaptureMedExFocusedElementContext("beforeCursorRestore"))
    Sleep ReportEditorTimingDefaults.RedCaretAfterPasteSettleMs
    Send("{Left " caretLeftCount "}")
    cursorContext["cursorRestoreCommandSent"] := true
    RecordOptionalPerformanceTimestamp(performanceContext, "CursorRestoreSentMs")
    return true
}

InsertRedFigureTextAndRestoreState(text := "（见图）", resetOptions := 0) {
    performanceContext := MedExAdapterOption(resetOptions, "performanceContext", 0)
    pasteResult := PasteRedFigureTextDetailed(
        text,
        performanceContext,
        () => ResetRedInsertionColorBeforeClipboardRestore(
            resetOptions,
            performanceContext
        )
    )
    if !pasteResult.pasteDispatched {
        return {
            ok: false,
            code: RedTextOperationCode.PASTE_FAILED,
            pasteDispatched: false,
            clipboardRestoreSucceeded: pasteResult.clipboardRestoreSucceeded,
            reset: 0
        }
    }

    if pasteResult.beforeRestoreSucceeded {
        resetResult := pasteResult.beforeRestoreResult
    } else {
        resetContext := Map(
            "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
            "appVersion", AppMetadata.Version,
            "colorResetStrategy", "beforeRestoreCallback",
            "automationChainResult", "AUTOMATION_CHAIN_NOT_COMPLETED",
            "exceptionMessage", pasteResult.beforeRestoreError
        )
        resetResult := MakeColorResetResult(
            false,
            ColorResetCode.UNEXPECTED_ERROR,
            resetContext
        )
    }

    ; The text is already present at this point. A reset failure is reported but
    ; never triggers automatic deletion or undo of report content. The feedback
    ; remains after the clipboard transaction has completed.
    if !resetResult.ok {
        RecordOptionalPerformanceTimestamp(performanceContext, "FailureFeedbackStartedMs")
        SoundBeep(650, 150)
        RecordOptionalPerformanceTimestamp(performanceContext, "FailureFeedbackCompletedMs")
        return {
            ok: false,
            code: RedTextOperationCode.RESET_FAILED,
            pasteDispatched: true,
            clipboardRestoreSucceeded: pasteResult.clipboardRestoreSucceeded,
            reset: resetResult
        }
    }

    if !pasteResult.clipboardRestoreSucceeded {
        return {
            ok: false,
            code: RedTextOperationCode.CLIPBOARD_RESTORE_FAILED,
            pasteDispatched: true,
            clipboardRestoreSucceeded: false,
            reset: resetResult
        }
    }

    return {
        ok: true,
        code: RedTextOperationCode.OK,
        pasteDispatched: true,
        clipboardRestoreSucceeded: true,
        reset: resetResult
    }
}

ResetRedInsertionColorBeforeClipboardRestore(resetOptions,
    performanceContext := 0) {
    RecordOptionalPerformanceTimestampAliases(
        performanceContext,
        ["ColorResetStartedMs", "ColorResetStartMs"]
    )
    resetResult := ResetMedExInsertionColor(resetOptions)
    RecordOptionalPerformanceTimestamp(performanceContext, "ColorResetReturnedMs")
    return resetResult
}

ResetReportFormattingPlaceholder() {
    ; Future: reset editor formatting only after window and focus validation.
    Flash("Report format reset is not implemented")
    return false
}
