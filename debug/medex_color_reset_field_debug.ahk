#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; Source project version and revision are read from AppMetadata.
; Test date: fill on target workstation
; Purpose: F12 validates color reset without paste; F11 runs the complete
; production insertion chain and therefore inserts built-in test text.

; Uses the same repository-pinned UIA-v2 dependency as production.
#Include ..\src\app_metadata.ahk
#Include ..\src\config.example.ahk
#Include ..\src\window_guard.ahk
#Include ..\src\utils.ahk
#Include ..\src\Lib\UIA.ahk
#Include ..\src\clipboard_html.ahk
#Include ..\src\medex_color_reset_logic.ahk
#Include ..\src\medex_candidate_g_logic.ahk
#Include ..\src\diagnostics.ahk
#Include ..\src\adapters\medex_report_editor.ahk
#Include ..\src\report_editor.ahk

; Field-test overrides. Production defaults come from MedExColorResetLayoutProfile.
DEBUG_COLOR_ARROW_OFFSET_X := MedExColorResetLayoutProfile.ColorArrowOffsetX
DEBUG_COLOR_ARROW_OFFSET_Y := MedExColorResetLayoutProfile.ColorArrowOffsetY
DEBUG_COLOR_RESET_STRATEGY := MedExColorResetStrategy.UIA_INVOKE
DEBUG_MENU_LOOKUP_STRATEGY := MedExColorResetDefaults.MenuLookupStrategy
DEBUG_MENU_OPEN_TIMEOUT_MS := MedExColorResetDefaults.MenuOpenTimeoutMs
DEBUG_MENU_POLL_INTERVAL_MS := MedExColorResetDefaults.MenuPollIntervalMs
DEBUG_BLACK_LOOKUP_RETRY_DELAY_MS := MedExColorResetDefaults.BlackLookupRetryDelayMs
DEBUG_BLACK_LOOKUP_MAX_ATTEMPTS := MedExColorResetDefaults.BlackLookupMaxAttempts
DEBUG_MENU_PRE_LOOKUP_SETTLE_MS := MedExColorResetDefaults.MenuPreLookupSettleMs
DEBUG_USE_CACHED_ANCHOR_SNAPSHOT := MedExColorResetDefaults.UseCachedAnchorSnapshot
DEBUG_ENABLE_FONT_ANCHOR_RETRY := MedExColorResetDefaults.EnableFontAnchorRetry
DEBUG_FONT_ANCHOR_RETRY_DELAY_MS := MedExColorResetDefaults.FontAnchorRetryDelayMs
; Keep false for timing A/B. Set true only for one dedicated focus/cursor run.
DEBUG_COLLECT_FOCUS_DIAGNOSTICS := false
DEBUG_ALLOW_PROVISIONAL_PROCESS := true
DEBUG_CONFIRMED_PROCESS_NAME := ""
DEBUG_WRITE_RESULT_FILE := true
DEBUG_RESULT_FILE := A_Temp "\MedExAHK\medex_color_reset_field_debug.txt"
DEBUG_LOG_FILE := A_Temp "\MedExAHK\medex_color_reset_field_debug.log"
DEBUG_PERFORMANCE_RESULT_FILE := A_Temp "\MedExAHK\medex_production_timing_debug.txt"
DEBUG_UIA_LIBRARY_VERSION_PINNED := "v1.1.3"

A_IconTip := "MedEx Color Reset Field Debug"

^!F12::
{
    RunMedExColorResetFieldDebug()
}

^!F11::
{
    RunMedExProductionTimingFieldDebug()
}

RunMedExColorResetFieldDebug() {
    global DEBUG_COLOR_ARROW_OFFSET_X
    global DEBUG_COLOR_ARROW_OFFSET_Y
    global DEBUG_COLOR_RESET_STRATEGY
    global DEBUG_MENU_LOOKUP_STRATEGY
    global DEBUG_MENU_OPEN_TIMEOUT_MS
    global DEBUG_MENU_POLL_INTERVAL_MS
    global DEBUG_BLACK_LOOKUP_RETRY_DELAY_MS
    global DEBUG_BLACK_LOOKUP_MAX_ATTEMPTS
    global DEBUG_MENU_PRE_LOOKUP_SETTLE_MS
    global DEBUG_USE_CACHED_ANCHOR_SNAPSHOT
    global DEBUG_ENABLE_FONT_ANCHOR_RETRY
    global DEBUG_FONT_ANCHOR_RETRY_DELAY_MS
    global DEBUG_COLLECT_FOCUS_DIAGNOSTICS
    global DEBUG_ALLOW_PROVISIONAL_PROCESS
    global DEBUG_CONFIRMED_PROCESS_NAME
    global DEBUG_WRITE_RESULT_FILE
    global DEBUG_RESULT_FILE
    global DEBUG_LOG_FILE
    global DEBUG_UIA_LIBRARY_VERSION_PINNED

    options := Map(
        "colorResetStrategy", DEBUG_COLOR_RESET_STRATEGY,
        "colorArrowOffsetX", DEBUG_COLOR_ARROW_OFFSET_X,
        "colorArrowOffsetY", DEBUG_COLOR_ARROW_OFFSET_Y,
        "menuLookupStrategy", DEBUG_MENU_LOOKUP_STRATEGY,
        "menuOpenTimeoutMs", DEBUG_MENU_OPEN_TIMEOUT_MS,
        "menuPollIntervalMs", DEBUG_MENU_POLL_INTERVAL_MS,
        "blackLookupRetryDelayMs", DEBUG_BLACK_LOOKUP_RETRY_DELAY_MS,
        "blackLookupMaxAttempts", DEBUG_BLACK_LOOKUP_MAX_ATTEMPTS,
        "menuPreLookupSettleMs", DEBUG_MENU_PRE_LOOKUP_SETTLE_MS,
        "useCachedAnchorSnapshot", DEBUG_USE_CACHED_ANCHOR_SNAPSHOT,
        "enableFontAnchorRetry", DEBUG_ENABLE_FONT_ANCHOR_RETRY,
        "fontAnchorRetryDelayMs", DEBUG_FONT_ANCHOR_RETRY_DELAY_MS,
        "collectFocusDiagnostics", DEBUG_COLLECT_FOCUS_DIAGNOSTICS,
        "allowProvisionalProcess", DEBUG_ALLOW_PROVISIONAL_PROCESS,
        "confirmedProcessName", DEBUG_CONFIRMED_PROCESS_NAME,
        "diagnosticMode", "field",
        "logPath", DEBUG_LOG_FILE,
        "uiaLibraryVersionPinned", DEBUG_UIA_LIBRARY_VERSION_PINNED
    )

    result := ResetMedExInsertionColor(options)
    header := "SourceProjectVersion=" AppMetadata.Version "`r`n"
        . "SourceRevision=" AppMetadata.SourceRevision "`r`n"
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

RunMedExProductionTimingFieldDebug() {
    global DEBUG_COLOR_RESET_STRATEGY
    global DEBUG_MENU_LOOKUP_STRATEGY
    global DEBUG_MENU_OPEN_TIMEOUT_MS
    global DEBUG_MENU_POLL_INTERVAL_MS
    global DEBUG_BLACK_LOOKUP_RETRY_DELAY_MS
    global DEBUG_BLACK_LOOKUP_MAX_ATTEMPTS
    global DEBUG_MENU_PRE_LOOKUP_SETTLE_MS
    global DEBUG_USE_CACHED_ANCHOR_SNAPSHOT
    global DEBUG_ENABLE_FONT_ANCHOR_RETRY
    global DEBUG_FONT_ANCHOR_RETRY_DELAY_MS
    global DEBUG_COLLECT_FOCUS_DIAGNOSTICS
    global DEBUG_ALLOW_PROVISIONAL_PROCESS
    global DEBUG_CONFIRMED_PROCESS_NAME
    global DEBUG_PERFORMANCE_RESULT_FILE
    global DEBUG_UIA_LIBRARY_VERSION_PINNED

    performanceContext := Map()
    options := Map(
        "colorResetStrategy", DEBUG_COLOR_RESET_STRATEGY,
        "menuLookupStrategy", DEBUG_MENU_LOOKUP_STRATEGY,
        "menuOpenTimeoutMs", DEBUG_MENU_OPEN_TIMEOUT_MS,
        "menuPollIntervalMs", DEBUG_MENU_POLL_INTERVAL_MS,
        "blackLookupRetryDelayMs", DEBUG_BLACK_LOOKUP_RETRY_DELAY_MS,
        "blackLookupMaxAttempts", DEBUG_BLACK_LOOKUP_MAX_ATTEMPTS,
        "menuPreLookupSettleMs", DEBUG_MENU_PRE_LOOKUP_SETTLE_MS,
        "useCachedAnchorSnapshot", DEBUG_USE_CACHED_ANCHOR_SNAPSHOT,
        "enableFontAnchorRetry", DEBUG_ENABLE_FONT_ANCHOR_RETRY,
        "fontAnchorRetryDelayMs", DEBUG_FONT_ANCHOR_RETRY_DELAY_MS,
        "collectFocusDiagnostics", DEBUG_COLLECT_FOCUS_DIAGNOSTICS,
        "allowProvisionalProcess", DEBUG_ALLOW_PROVISIONAL_PROCESS,
        "confirmedProcessName", DEBUG_CONFIRMED_PROCESS_NAME,
        "diagnosticMode", "performance",
        "performanceContext", performanceContext,
        "uiaLibraryVersionPinned", DEBUG_UIA_LIBRARY_VERSION_PINNED
    )

    options["colorResetStrategy"] := MedExColorResetStrategy.RELATIVE_MOUSE_PIXEL_VALIDATED
    operation := RunRedInsertion(options)
    output := "SourceProjectVersion=" AppMetadata.Version "`r`n"
        . "SourceRevision=" AppMetadata.SourceRevision "`r`n"
        . "TestDate=" FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
        . "Purpose=MedExProductionInsertionTiming`r`n"
        . FormatMedExPerformanceTimingResult(operation, performanceContext)

    A_Clipboard := output
    ClipWait(1)
    try {
        SplitPath DEBUG_PERFORMANCE_RESULT_FILE, , &resultDirectory
        if resultDirectory != "" && !DirExist(resultDirectory)
            DirCreate resultDirectory
        FileAppend "---`r`n" output, DEBUG_PERFORMANCE_RESULT_FILE, "UTF-8"
    }

    ; Intentionally no MsgBox, ToolTip, TrayTip, or other completion UI.
}
