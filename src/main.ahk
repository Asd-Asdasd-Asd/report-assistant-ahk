#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include config.example.ahk
#Include *i config.local.ahk
#Include window_guard.ahk
#Include utils.ahk
#Include clipboard_html.ahk
#Include report_editor.ahk
#Include viewer_actions.ahk
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
