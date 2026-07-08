; Generated file. Edit src/*.ahk instead.
; Generated at: 2026-07-08 13:34:59 UTC

; --- BEGIN config.example.ahk ---
; Copy this file to config.local.ahk and calibrate values on the target workstation.
; Do not store patient data, credentials, hospital identifiers, or sensitive logs here.

REPORT_EDITOR_EXE := "medexworkstation.exe"
VIEWER_EXE := "MedExNMFusion.exe"

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
::;red::{
    PasteRedFigureText()
}

::;fzg::{
    SendText "放射性摄取增高，SUVmax约"
    PasteRedFigureText()
    Send "{Left 4}"
}

::;fwj::{
    SendText "放射性摄取未见明显增高"
    PasteRedFigureText()
}

::;fjd::{
    SendText "放射性摄取降低"
    PasteRedFigureText()
}

::;cmx::{
    SendText "cm×cm"
    Send "{Left 2}"
}

; --- END hotstrings.ahk ---

; --- BEGIN main.ahk ---
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn


^!Esc::Suspend
^!q::ExitApp

Flash("Report Assistant AHK loaded")

; --- END main.ahk ---
