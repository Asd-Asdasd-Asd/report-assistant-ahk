FocusReportEditor() {
    return RequireReportEditor()
}

InsertRedFigureTextAndRestoreState(text := "（见图）", resetOptions := 0) {
    pasteResult := PasteRedFigureTextDetailed(text)
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
    resetResult := ResetMedExInsertionColor(resetOptions)
    if !resetResult.ok {
        SoundBeep(650, 150)
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
