PastePlainText(text) {
    return WithClipboardRestore(() => PastePlainTextWithoutRestore(text))
}

PasteRedFigureText(text := "（见图）") {
    return PasteRedRtfText(text)
}

PasteRedRtfText(text) {
    ; This RTF clipboard path must be tested in the target Windows report editor.
    ; It intentionally does not fall back to plain black text on failure.
    return WithClipboardRestore(() => PasteRedRtfTextWithoutRestore(text))
}

BuildRedRtf(text) {
    escapedText := RtfEscapeUnicode(text)
    return "{\rtf1\ansi\deff0{\fonttbl{\f0 Microsoft YaHei;}}"
        . "{\colortbl ;\red255\green0\blue0;\red0\green0\blue0;}"
        . "\f0\fs22\cf1 " escapedText "\cf2 }"
}

RtfEscapeUnicode(text) {
    escaped := ""

    Loop Parse text {
        char := A_LoopField
        code := Ord(char)

        if char = "\" {
            escaped .= "\\"
        } else if char = "{" {
            escaped .= "\{"
        } else if char = "}" {
            escaped .= "\}"
        } else if char = "`r" {
            continue
        } else if char = "`n" {
            escaped .= "\par "
        } else if code >= 0x20 && code <= 0x7E {
            escaped .= char
        } else {
            signedCode := code > 32767 ? code - 65536 : code
            escaped .= "\u" signedCode "?"
        }
    }

    return escaped
}

SetClipboardRtf(rtfText, plainText) {
    static CF_UNICODETEXT := 13
    rtfFormat := DllCall("RegisterClipboardFormat", "Str", "Rich Text Format", "UInt")
    if !rtfFormat
        return false

    if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd, "Int")
        return false

    clipboardOpened := true
    try {
        if !DllCall("EmptyClipboard", "Int")
            return false

        if !SetClipboardTextFormat(rtfFormat, rtfText, "CP0")
            return false

        if !SetClipboardTextFormat(CF_UNICODETEXT, plainText, "UTF-16")
            return false

        return true
    } finally {
        if clipboardOpened
            DllCall("CloseClipboard", "Int")
    }
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

PasteRedRtfTextWithoutRestore(text) {
    rtfText := BuildRedRtf(text)
    if !SetClipboardRtf(rtfText, text) {
        Flash("红字插入失败，请手动添加")
        SoundBeep(750, 120)
        return false
    }

    Sleep 80
    Send("^v")
    Sleep 120
    return true
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

SetClipboardTextFormat(format, text, encoding) {
    byteCount := GetEncodedByteCount(text, encoding)
    source := Buffer(byteCount, 0)
    StrPut(text, source, encoding)

    hMem := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", byteCount, "Ptr")
    if !hMem
        return false

    lockedMemory := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    if !lockedMemory {
        DllCall("GlobalFree", "Ptr", hMem, "Ptr")
        return false
    }

    DllCall("RtlMoveMemory", "Ptr", lockedMemory, "Ptr", source.Ptr, "UPtr", byteCount)
    DllCall("GlobalUnlock", "Ptr", hMem)

    if !DllCall("SetClipboardData", "UInt", format, "Ptr", hMem, "Ptr") {
        DllCall("GlobalFree", "Ptr", hMem, "Ptr")
        return false
    }

    return true
}

GetEncodedByteCount(text, encoding) {
    charCount := StrPut(text, encoding)
    encodingName := StrLower(encoding)
    if encodingName = "utf-16" || encodingName = "cp1200"
        return charCount * 2

    return charCount
}
