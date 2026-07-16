FocusReportEditor() {
    return RequireReportEditor()
}

class ReportHotstringTimingDefaults {
    ; Preserve the legacy ;fzg caret-settle interval after editor automation.
    static FzgCursorRestoreDelayMs := 50
}

RunFzgInsertion(resetOptions := 0) {
    performanceContext := MedExAdapterOption(resetOptions, "performanceContext", 0)
    RecordOptionalPerformanceTimestamp(performanceContext, "HotstringStartMs")
    SendText("放射性摄取增高，SUVmax约")
    operation := InsertRedFigureTextAndRestoreState("（见图）", resetOptions)
    if operation.ok {
        Sleep ReportHotstringTimingDefaults.FzgCursorRestoreDelayMs
        if IsObject(operation.reset) && operation.reset.HasOwnProp("context")
            && Type(operation.reset.context) = "Map" {
            operation.reset.context["cursorRestoreRequestedCount"] := 4
            operation.reset.context["foregroundHwndBeforeCursorRestore"] := Format(
                "0x{:X}", WinExist("A")
            )
            operation.reset.context["cursorRestoreTargetHwnd"] := MedExContextValue(
                operation.reset.context,
                "foregroundWindowHandle",
                "UNKNOWN"
            )
            if MedExAdapterOption(resetOptions, "collectFocusDiagnostics", false)
                MergeContext(operation.reset.context,
                    CaptureMedExFocusedElementContext("beforeCursorRestore"))
        }
        Send("{Left 4}")
        if IsObject(operation.reset) && operation.reset.HasOwnProp("context")
            && Type(operation.reset.context) = "Map"
            operation.reset.context["cursorRestoreCommandSent"] := true
        RecordOptionalPerformanceTimestamp(performanceContext, "CursorRestoreSentMs")
    }
    RecordOptionalPerformanceTimestamp(performanceContext, "HotstringReturnMs")
    return operation
}

InsertRedFigureTextAndRestoreState(text := "（见图）", resetOptions := 0) {
    performanceContext := MedExAdapterOption(resetOptions, "performanceContext", 0)
    pasteResult := PasteRedFigureTextDetailed(text, performanceContext)
    if !pasteResult.pasteDispatched {
        return {
            ok: false,
            code: RedTextOperationCode.PASTE_FAILED,
            pasteDispatched: false,
            clipboardRestoreSucceeded: pasteResult.clipboardRestoreSucceeded,
            reset: 0
        }
    }

    ; The text is already present at this point. A reset failure is reported but
    ; never triggers automatic deletion or undo of report content.
    RecordOptionalPerformanceTimestamp(performanceContext, "ColorResetStartMs")
    resetResult := ResetMedExInsertionColor(resetOptions)
    RecordOptionalPerformanceTimestamp(performanceContext, "ColorResetReturnedMs")
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

ResetReportFormattingPlaceholder() {
    ; Future: reset editor formatting only after window and focus validation.
    Flash("Report format reset is not implemented")
    return false
}
