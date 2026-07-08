PastePlainText(text) {
    return WithClipboardRestore(() => PastePlainTextWithoutRestore(text))
}

PasteRedFigureText(text := "（见图）") {
    ; TODO: Add true RTF/HTML clipboard support after compatibility testing on Windows.
    ; For now, use a plain-text fallback and avoid external clipboard snapshot files.
    return PastePlainText(text)
}

WithClipboardRestore(callback) {
    if !HasMethod(callback, "Call") {
        Flash("Invalid clipboard action")
        return false
    }

    savedClipboard := ClipboardAll()

    try {
        return callback.Call()
    } catch as err {
        Flash("Clipboard action failed: " err.Message)
        return false
    } finally {
        Sleep 50
        A_Clipboard := savedClipboard
        Sleep 50
    }
}

PastePlainTextWithoutRestore(text) {
    A_Clipboard := ""
    Sleep 30
    A_Clipboard := text

    if !ClipWait(1) {
        Flash("Clipboard unavailable")
        return false
    }

    Sleep 80
    Send("^v")
    Sleep 100
    return true
}
