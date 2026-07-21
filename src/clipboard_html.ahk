class ClipboardTransactionDefaults {
    ; Continue after Ctrl+V without a fixed paste-dispatch delay. Clipboard restore
    ; remains protected by the independently validated minimum interval below.
    static HtmlPasteDispatchSettleMs := 0
    static ClipboardPreRestoreSettleMs := 100
    static ClipboardPostRestoreSettleMs := 100
    static SafeMinPasteToRestoreMs := 300
}

PastePlainText(text) {
    transaction := WithClipboardRestore(() => PastePlainTextWithoutRestore(text))
    if !transaction.actionSucceeded
        Flash("Plain-text paste failed")
    if transaction.restoreAttempted && !transaction.restoreSucceeded
        Flash("Clipboard restore failed")
    return transaction.actionSucceeded && transaction.restoreAttempted
}

PasteRedFigureText(text := "（见图）") {
    return PasteRedFigureTextDetailed(text).pasteDispatched
}

PasteRedFigureTextDetailed(text := "（见图）", performanceContext := 0,
    beforeRestoreCallback := 0) {
    ; The black wrapper is intentionally empty of boundary/sentinel characters.
    escapedText := StrReplace(HtmlEscape(text), "`n", "<br>")
    fragment := "<span style=`"color:#000000`"><span style=`"color:#ff0000`">" . escapedText . "</span></span>"
    return PasteHtmlFragmentDetailed(
        fragment,
        performanceContext,
        beforeRestoreCallback
    )
}

PasteHtmlFragment(fragment) {
    return PasteHtmlFragmentDetailed(fragment).pasteDispatched
}

PasteHtmlFragmentDetailed(fragment, performanceContext := 0,
    beforeRestoreCallback := 0) {
    restoreTimingContext := Map()
    transaction := WithClipboardRestore(
        () => PasteHtmlFragmentWithoutRestore(
            fragment,
            performanceContext,
            restoreTimingContext
        ),
        performanceContext,
        beforeRestoreCallback,
        restoreTimingContext
    )
    pasteDispatched := transaction.actionSucceeded && transaction.restoreAttempted

    if !transaction.actionSucceeded {
        SoundBeep(750, 120)
    } else if !transaction.restoreSucceeded {
        SoundBeep(750, 120)
    }

    ; pasteDispatched does not confirm that the target editor rendered the HTML.
    return {
        ok: transaction.actionSucceeded && transaction.restoreSucceeded,
        pasteDispatched: pasteDispatched,
        clipboardRestoreSucceeded: transaction.restoreSucceeded,
        beforeRestoreAttempted: transaction.beforeRestoreAttempted,
        beforeRestoreSucceeded: transaction.beforeRestoreSucceeded,
        beforeRestoreResult: transaction.beforeRestoreResult,
        beforeRestoreError: transaction.beforeRestoreError,
        transaction: transaction
    }
}

BuildCfHtml(fragment) {
    startMarker := "<!--StartFragment-->"
    endMarker := "<!--EndFragment-->"
    htmlPrefix := "<html><body>" startMarker
    htmlSuffix := endMarker "</body></html>"
    html := htmlPrefix fragment htmlSuffix

    headerTemplate := "Version:1.0`r`n"
        . "StartHTML:0000000000`r`n"
        . "EndHTML:0000000000`r`n"
        . "StartFragment:0000000000`r`n"
        . "EndFragment:0000000000`r`n"

    startHtml := Utf8ByteCount(headerTemplate)
    startFragment := startHtml + Utf8ByteCount(htmlPrefix)
    endFragment := startFragment + Utf8ByteCount(fragment)
    endHtml := startHtml + Utf8ByteCount(html)

    header := "Version:1.0`r`n"
        . "StartHTML:" FormatCfHtmlOffset(startHtml) "`r`n"
        . "EndHTML:" FormatCfHtmlOffset(endHtml) "`r`n"
        . "StartFragment:" FormatCfHtmlOffset(startFragment) "`r`n"
        . "EndFragment:" FormatCfHtmlOffset(endFragment) "`r`n"

    if Utf8ByteCount(header) != startHtml
        throw Error("CF_HTML header length changed while formatting offsets")

    return header html
}

HtmlEscape(text) {
    escaped := StrReplace(text, "&", "&amp;")
    escaped := StrReplace(escaped, "<", "&lt;")
    escaped := StrReplace(escaped, ">", "&gt;")
    escaped := StrReplace(escaped, Chr(34), "&quot;")
    return StrReplace(escaped, "'", "&#39;")
}

SetClipboardHtml(cfHtml) {
    htmlFormat := DllCall("RegisterClipboardFormat", "Str", "HTML Format", "UInt")
    if !htmlFormat
        return 0

    if !OpenClipboardWithRetry()
        return 0

    try {
        if !DllCall("EmptyClipboard", "Int")
            return 0

        cfHtmlBuffer := Utf8Buffer(cfHtml)
        if !SetClipboardBuffer(htmlFormat, cfHtmlBuffer)
            return 0

        return htmlFormat
    } finally {
        DllCall("CloseClipboard", "Int")
    }
}

WithClipboardRestore(callback, performanceContext := 0,
    beforeRestoreCallback := 0, restoreTimingContext := 0) {
    result := {
        actionSucceeded: false,
        beforeRestoreAttempted: false,
        beforeRestoreSucceeded: false,
        beforeRestoreResult: 0,
        beforeRestoreError: "",
        restoreAttempted: false,
        restoreSucceeded: false,
        actionError: "",
        restoreError: ""
    }

    if !HasMethod(callback, "Call") {
        result.actionError := "Invalid clipboard action"
        return result
    }

    clipboardSaved := false
    try {
        savedClipboard := ClipboardAll()
        clipboardSaved := true
        result.actionSucceeded := callback.Call() = true
        if result.actionSucceeded && IsObject(beforeRestoreCallback)
            && HasMethod(beforeRestoreCallback, "Call") {
            result.beforeRestoreAttempted := true
            try {
                result.beforeRestoreResult := beforeRestoreCallback.Call()
                result.beforeRestoreSucceeded := true
            } catch as beforeRestoreErr {
                result.beforeRestoreError := beforeRestoreErr.Message
            }
        }
    } catch as err {
        result.actionError := err.Message
    } finally {
        if clipboardSaved {
            result.restoreAttempted := true
            try {
                WaitForSafeClipboardRestore(
                    restoreTimingContext,
                    performanceContext
                )
                RecordOptionalPerformanceTimestamp(
                    performanceContext,
                    "ClipboardRestoreStartedMs"
                )
                A_Clipboard := savedClipboard
                Sleep ClipboardTransactionDefaults.ClipboardPostRestoreSettleMs
                result.restoreSucceeded := true
                RecordOptionalPerformanceTimestamp(
                    performanceContext,
                    "ClipboardRestoreCompletedMs"
                )
            } catch as restoreErr {
                result.restoreError := restoreErr.Message
            }
        }
    }

    return result
}

WaitForSafeClipboardRestore(restoreTimingContext := 0,
    performanceContext := 0) {
    waitStartedAt := A_TickCount
    if Type(restoreTimingContext) = "Map"
        && restoreTimingContext.Has("pasteSentAt") {
        loop {
            elapsedMs := A_TickCount - restoreTimingContext["pasteSentAt"]
            waitMs := ClipboardTransactionDefaults.SafeMinPasteToRestoreMs
                - elapsedMs
            if waitMs <= 0
                break
            Sleep waitMs
        }
    } else {
        Sleep ClipboardTransactionDefaults.ClipboardPreRestoreSettleMs
    }
    actualWaitMs := A_TickCount - waitStartedAt
    if Type(performanceContext) = "Map"
        performanceContext["ClipboardRestoreSafetyWaitMs"] := actualWaitMs
    return actualWaitMs
}

PasteHtmlFragmentWithoutRestore(fragment, performanceContext := 0,
    restoreTimingContext := 0) {
    cfHtml := BuildCfHtml(fragment)
    htmlFormat := SetClipboardHtml(cfHtml)
    if !htmlFormat
        return false

    if !WaitForClipboardFormat(htmlFormat, 500)
        return false

    Send("^v")
    pasteSentAt := A_TickCount
    if Type(performanceContext) = "Map" {
        performanceContext["PasteCommandSentMs"] := pasteSentAt
        performanceContext["PasteSentMs"] := pasteSentAt
    }
    if Type(restoreTimingContext) = "Map"
        restoreTimingContext["pasteSentAt"] := pasteSentAt
    Sleep ClipboardTransactionDefaults.HtmlPasteDispatchSettleMs
    RecordOptionalPerformanceTimestamp(
        performanceContext,
        "PasteDispatchSettleCompletedMs"
    )
    return true
}

PastePlainTextWithoutRestore(text) {
    A_Clipboard := ""
    Sleep 30
    A_Clipboard := text

    if !ClipWait(1)
        return false

    Sleep 80
    Send("^v")
    Sleep 100
    return true
}

OpenClipboardWithRetry(timeoutMs := 500) {
    deadline := A_TickCount + timeoutMs
    loop {
        if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd, "Int")
            return true
        if A_TickCount >= deadline
            return false
        Sleep 25
    }
}

WaitForClipboardFormat(format, timeoutMs := 500) {
    deadline := A_TickCount + timeoutMs
    loop {
        if DllCall("IsClipboardFormatAvailable", "UInt", format, "Int")
            return true
        if A_TickCount >= deadline
            return false
        Sleep 20
    }
}

RecordOptionalPerformanceTimestamp(performanceContext, key) {
    if Type(performanceContext) = "Map"
        performanceContext[key] := A_TickCount
}

RecordOptionalPerformanceTimestampAliases(performanceContext, keys) {
    if Type(performanceContext) != "Map" || Type(keys) != "Array"
        return
    timestamp := A_TickCount
    for key in keys
        performanceContext[key] := timestamp
}

SetClipboardBuffer(format, source) {
    static GMEM_MOVEABLE := 0x0002

    hMem := DllCall("GlobalAlloc", "UInt", GMEM_MOVEABLE, "UPtr", source.Size, "Ptr")
    if !hMem
        return false

    lockedMemory := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    if !lockedMemory {
        DllCall("GlobalFree", "Ptr", hMem, "Ptr")
        return false
    }

    DllCall("RtlMoveMemory", "Ptr", lockedMemory, "Ptr", source.Ptr, "UPtr", source.Size)
    DllCall("GlobalUnlock", "Ptr", hMem)

    if !DllCall("SetClipboardData", "UInt", format, "Ptr", hMem, "Ptr") {
        DllCall("GlobalFree", "Ptr", hMem, "Ptr")
        return false
    }

    ; Windows owns hMem after SetClipboardData succeeds.
    return true
}

Utf8Buffer(text) {
    byteCount := Utf8ByteCount(text)
    byteStorage := Buffer(byteCount + 1, 0)
    written := StrPut(text, byteStorage, "UTF-8")
    if written != byteCount + 1
        throw Error("Unexpected UTF-8 buffer length")
    return byteStorage
}

Utf8ByteCount(text) {
    return StrPut(text, "UTF-8") - 1
}

FormatCfHtmlOffset(offset) {
    if offset < 0 || offset > 9999999999
        throw Error("CF_HTML offset is outside the 10-digit header range")
    return Format("{:010d}", offset)
}
