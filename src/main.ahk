#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include app_metadata.ahk
#Include config.example.ahk
#Include *i config.local.ahk
#Include window_guard.ahk
#Include utils.ahk
#Include clipboard_html.ahk
#Include <UIA>
#Include medex_color_reset_logic.ahk
#Include medex_candidate_g_logic.ahk
#Include diagnostics.ahk
#Include adapters\medex_report_editor.ahk
#Include report_editor.ahk
#Include viewer_actions.ahk
#Include hotstring_config.ahk
#Include hotstrings.ahk

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
