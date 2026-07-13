#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; Source project version: v0.5.0-development
; Source commit: a0e363df24f4 + uncommitted color-reset implementation
; Test date: fill on target workstation
; Purpose: Validate the MedEx insertion-color reset without pasting report text.

; Install UIA-v2 v1.1.3 as a standard <UIA> library before field testing.
#Include *i <UIA>
#Include ..\src\medex_color_reset_logic.ahk
#Include ..\src\diagnostics.ahk
#Include ..\src\adapters\medex_report_editor.ahk

; Provisional field-test overrides. Edit only these values during field testing.
DEBUG_RATIO := 0.337
DEBUG_MENU_OPEN_TIMEOUT_MS := 600
DEBUG_MENU_POLL_INTERVAL_MS := 40
DEBUG_MAX_TRIGGER_ATTEMPTS := 2
DEBUG_ALLOW_PROVISIONAL_PROCESS := true
DEBUG_CONFIRMED_PROCESS_NAME := ""
DEBUG_WRITE_RESULT_FILE := true
DEBUG_RESULT_FILE := A_Temp "\MedExAHK\medex_color_reset_field_debug.txt"
DEBUG_LOG_FILE := A_Temp "\MedExAHK\medex_color_reset_field_debug.log"
DEBUG_UIA_LIBRARY_VERSION := "EXPECTED_1.1.3_NOT_RUNTIME_DETECTED"

A_IconTip := "MedEx Color Reset Field Debug"
ToolTip "MedEx 颜色复位现场调试已加载：Ctrl+Alt+F12"
SetTimer () => ToolTip(), -2500

^!F12::
{
    RunMedExColorResetFieldDebug()
}

RunMedExColorResetFieldDebug() {
    global DEBUG_RATIO
    global DEBUG_MENU_OPEN_TIMEOUT_MS
    global DEBUG_MENU_POLL_INTERVAL_MS
    global DEBUG_MAX_TRIGGER_ATTEMPTS
    global DEBUG_ALLOW_PROVISIONAL_PROCESS
    global DEBUG_CONFIRMED_PROCESS_NAME
    global DEBUG_WRITE_RESULT_FILE
    global DEBUG_RESULT_FILE
    global DEBUG_LOG_FILE
    global DEBUG_UIA_LIBRARY_VERSION

    options := Map(
        "ratio", DEBUG_RATIO,
        "menuOpenTimeoutMs", DEBUG_MENU_OPEN_TIMEOUT_MS,
        "menuPollIntervalMs", DEBUG_MENU_POLL_INTERVAL_MS,
        "maxTriggerAttempts", DEBUG_MAX_TRIGGER_ATTEMPTS,
        "allowProvisionalProcess", DEBUG_ALLOW_PROVISIONAL_PROCESS,
        "confirmedProcessName", DEBUG_CONFIRMED_PROCESS_NAME,
        "enableDevelopmentLog", true,
        "logPath", DEBUG_LOG_FILE,
        "uiaLibraryVersion", DEBUG_UIA_LIBRARY_VERSION
    )

    result := ResetMedExInsertionColor(options)
    header := "SourceProjectVersion=v0.5.0-development`r`n"
        . "SourceCommit=a0e363df24f4+uncommitted-color-reset`r`n"
        . "TestDate=" FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
        . "Purpose=MedExInsertionColorResetFieldValidation`r`n"
    output := header FormatMedExFieldDebugResult(result)

    A_Clipboard := output
    clipboardReady := ClipWait(1)

    if DEBUG_WRITE_RESULT_FILE {
        try {
            SplitPath DEBUG_RESULT_FILE, , &resultDirectory
            if resultDirectory != "" && !DirExist(resultDirectory)
                DirCreate resultDirectory
            FileAppend "---`r`n" output, DEBUG_RESULT_FILE, "UTF-8"
        }
    }

    clipboardMessage := clipboardReady
        ? "完整诊断结果已复制到剪贴板。"
        : "剪贴板写入未确认，请从临时结果文件读取。"
    MsgBox "结果：" result.code "`n" clipboardMessage "`n"
        . "本脚本不会粘贴或记录报告文字。",
        "MedEx Color Reset Field Debug"
}
