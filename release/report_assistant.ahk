; Generated file. Edit src/*.ahk instead.
; Generated at: 2026-07-09 16:30:49 UTC

; --- BEGIN config.example.ahk ---
; Copy this file to config.local.ahk and calibrate values on the target workstation.
; Do not store patient data, credentials, hospital identifiers, or sensitive logs here.

REPORT_EDITOR_EXE := "medexworkstation.exe"
VIEWER_EXE := "MedExNMFusion.exe"

; Red figure text expects dynamic RTF clipboard insertion by default.
RED_TEXT_MODE := "rtf"
RED_TEXT_COLOR := "red"
RED_TEXT_RESET_TO_BLACK := true

COORDINATES := Map(
    "example_viewer_button", { x: 100, y: 100 },
    "example_report_field", { x: 200, y: 200 }
)

; --- END config.example.ahk ---

; --- BEGIN window_guard.ahk ---
RequireReportEditor() {
    global REPORT_EDITOR_EXE
    return RequireWindowByExe(REPORT_EDITOR_EXE, "Report editor not active")
}

RequireViewer() {
    global VIEWER_EXE
    return RequireWindowByExe(VIEWER_EXE, "Viewer not active")
}

RequireWindowByExe(exeName, failureMessage) {
    if !IsSet(exeName) || exeName = "" {
        ToolTip failureMessage ": missing executable setting"
        SetTimer () => ToolTip(), -1200
        return false
    }

    windowQuery := "ahk_exe " exeName
    if !WinExist(windowQuery) {
        ToolTip failureMessage
        SetTimer () => ToolTip(), -1200
        return false
    }

    WinActivate windowQuery
    if !WinWaitActive(windowQuery, , 1) {
        ToolTip failureMessage ": activation failed"
        SetTimer () => ToolTip(), -1200
        return false
    }

    return true
}

; --- END window_guard.ahk ---

; --- BEGIN utils.ahk ---
Flash(message, duration := 1000) {
    ToolTip message
    SetTimer () => ToolTip(), -Abs(duration)
}

WithMouseRestore(callback) {
    if !HasMethod(callback, "Call") {
        Flash("Invalid callback")
        return false
    }

    MouseGetPos &originalX, &originalY
    try {
        callback.Call()
        return true
    } catch as err {
        Flash("Action failed: " err.Message)
        return false
    } finally {
        MouseMove originalX, originalY, 0
    }
}

ClickPoint(name, clicks := 1) {
    global COORDINATES

    if !IsSet(COORDINATES) || Type(COORDINATES) != "Map" {
        Flash("Coordinate map is not configured")
        return false
    }

    if !COORDINATES.Has(name) {
        Flash("Unknown point: " name)
        return false
    }

    point := COORDINATES[name]
    if !point.HasOwnProp("x") || !point.HasOwnProp("y") {
        Flash("Invalid point: " name)
        return false
    }

    safeClicks := Max(1, Integer(clicks))
    return WithMouseRestore(() => Click(point.x, point.y, safeClicks))
}

; --- END utils.ahk ---

; --- BEGIN clipboard_rtf.ahk ---
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

; --- END clipboard_rtf.ahk ---

; --- BEGIN report_editor.ahk ---
FocusReportEditor() {
    return RequireReportEditor()
}

InsertReportRichTextPlaceholder() {
    ; Future: validate editor focus before inserting RTF content.
    ; Future: replace plain-text paste with calibrated RTF insertion.
    Flash("Report rich-text insertion is not implemented")
    return false
}

ResetReportFormattingPlaceholder() {
    ; Future: reset editor formatting only after window and focus validation.
    Flash("Report format reset is not implemented")
    return false
}

; --- END report_editor.ahk ---

; --- BEGIN viewer_actions.ahk ---
FocusViewer() {
    return RequireViewer()
}

ViewerActionPlaceholder(actionName := "viewer action") {
    ; Viewer actions are coordinate-sensitive and require local calibration.
    ; Legacy click sequences should be migrated one workflow at a time.
    Flash(actionName " is not implemented")
    return false
}

ExampleCalibratedViewerClick() {
    ; Example migration pattern:
    ; if RequireViewer()
    ;     ClickPoint("example_viewer_button")
    return ViewerActionPlaceholder("Example viewer click")
}

; --- END viewer_actions.ahk ---

; --- BEGIN hotstrings.ahk ---
:*?:;red::
{
    PasteRedFigureText()
}

:*?:;fzg::
{
    SendText("放射性摄取增高，SUVmax约")
    PasteRedFigureText()
    Send("{Left 4}")
}

:*?:;fwj::
{
    SendText("放射性摄取未见明显增高")
    PasteRedFigureText()
}

:*?:;fjd::
{
    SendText("放射性摄取降低")
    PasteRedFigureText()
}

:*?:;cmx::
{
    SendText("cm×cm")
    Send("{Left 2}")
}

; --- END hotstrings.ahk ---

; --- BEGIN main.ahk ---
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn


#SuspendExempt

^!Esc::
{
    Suspend -1
    if A_IsSuspended
        Flash("Report Assistant suspended")
    else
        Flash("Report Assistant active")
}

^!q::
{
    ExitApp
}

#SuspendExempt False

Flash("Report Assistant AHK loaded")

; --- END main.ahk ---
