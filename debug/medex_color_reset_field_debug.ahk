#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; Source project version: v0.5.0-development
; Source commit: 3457248 + uncommitted semantic-anchor redesign
; Test date: fill on target workstation
; Purpose: Validate the MedEx insertion-color reset without pasting report text.

; Uses the repository-pinned debug\Lib\UIA.ahk v1.1.3 through <UIA> lookup.
#Include *i <UIA>
#Include ..\src\medex_color_reset_logic.ahk
#Include ..\src\diagnostics.ahk
#Include ..\src\adapters\medex_report_editor.ahk

; Field-test overrides. Production defaults come from MedExColorResetLayoutProfile.
DEBUG_COLOR_ARROW_OFFSET_X := MedExColorResetLayoutProfile.ColorArrowOffsetX
DEBUG_COLOR_ARROW_OFFSET_Y := MedExColorResetLayoutProfile.ColorArrowOffsetY
DEBUG_MENU_OPEN_TIMEOUT_MS := 600
DEBUG_MENU_POLL_INTERVAL_MS := 40
DEBUG_MAX_TRIGGER_ATTEMPTS := 2
DEBUG_ALLOW_PROVISIONAL_PROCESS := true
DEBUG_CONFIRMED_PROCESS_NAME := ""
DEBUG_WRITE_RESULT_FILE := true
DEBUG_RESULT_FILE := A_Temp "\MedExAHK\medex_color_reset_field_debug.txt"
DEBUG_LOG_FILE := A_Temp "\MedExAHK\medex_color_reset_field_debug.log"
DEBUG_UIA_LIBRARY_VERSION_PINNED := "v1.1.3"

A_IconTip := "MedEx Color Reset Field Debug"

^!F12::
{
    RunMedExColorResetFieldDebug()
}

RunMedExColorResetFieldDebug() {
    global DEBUG_COLOR_ARROW_OFFSET_X
    global DEBUG_COLOR_ARROW_OFFSET_Y
    global DEBUG_MENU_OPEN_TIMEOUT_MS
    global DEBUG_MENU_POLL_INTERVAL_MS
    global DEBUG_MAX_TRIGGER_ATTEMPTS
    global DEBUG_ALLOW_PROVISIONAL_PROCESS
    global DEBUG_CONFIRMED_PROCESS_NAME
    global DEBUG_WRITE_RESULT_FILE
    global DEBUG_RESULT_FILE
    global DEBUG_LOG_FILE
    global DEBUG_UIA_LIBRARY_VERSION_PINNED

    options := Map(
        "colorArrowOffsetX", DEBUG_COLOR_ARROW_OFFSET_X,
        "colorArrowOffsetY", DEBUG_COLOR_ARROW_OFFSET_Y,
        "menuOpenTimeoutMs", DEBUG_MENU_OPEN_TIMEOUT_MS,
        "menuPollIntervalMs", DEBUG_MENU_POLL_INTERVAL_MS,
        "maxTriggerAttempts", DEBUG_MAX_TRIGGER_ATTEMPTS,
        "allowProvisionalProcess", DEBUG_ALLOW_PROVISIONAL_PROCESS,
        "confirmedProcessName", DEBUG_CONFIRMED_PROCESS_NAME,
        "enableDevelopmentLog", true,
        "logPath", DEBUG_LOG_FILE,
        "uiaLibraryVersionPinned", DEBUG_UIA_LIBRARY_VERSION_PINNED
    )

    result := ResetMedExInsertionColor(options)
    header := "SourceProjectVersion=v0.5.0-development`r`n"
        . "SourceCommit=3457248+uncommitted-semantic-anchor-redesign`r`n"
        . "TestDate=" FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
        . "Purpose=MedExInsertionColorResetFieldValidation`r`n"
    output := header FormatMedExFieldDebugResult(result)

    A_Clipboard := output
    ClipWait(1)

    if DEBUG_WRITE_RESULT_FILE {
        try {
            SplitPath DEBUG_RESULT_FILE, , &resultDirectory
            if resultDirectory != "" && !DirExist(resultDirectory)
                DirCreate resultDirectory
            FileAppend "---`r`n" output, DEBUG_RESULT_FILE, "UTF-8"
        }
    }

    ; Intentionally no MsgBox, ToolTip, TrayTip, or other completion UI.
    ; Clipboard and files are the complete field-debug output contract.
}
