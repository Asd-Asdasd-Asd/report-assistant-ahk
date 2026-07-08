PasteRedFigureText(text := "（见图）") {
    ; TODO: Add true RTF/HTML clipboard support after the plain-text workflow is tested.
    savedClipboard := ClipboardAll()

    try {
        A_Clipboard := text
        if !ClipWait(0.5) {
            Flash("Clipboard unavailable")
            return false
        }

        Send "^v"
        Sleep 50
        return true
    } catch as err {
        Flash("Paste failed: " err.Message)
        return false
    } finally {
        A_Clipboard := savedClipboard
    }
}
