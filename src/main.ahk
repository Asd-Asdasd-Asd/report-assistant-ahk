#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

#Include config.example.ahk
#Include *i config.local.ahk
#Include window_guard.ahk
#Include utils.ahk
#Include clipboard_rtf.ahk
#Include report_editor.ahk
#Include viewer_actions.ahk
#Include hotstrings.ahk

^!Esc::Suspend
^!q::ExitApp

Flash("Report Assistant AHK loaded")
