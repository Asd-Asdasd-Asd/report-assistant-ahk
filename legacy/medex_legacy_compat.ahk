#Requires AutoHotkey v2.0
#SingleInstance Force

; v0.5.x 迁移期 compatibility script，可与 MedEx Report Assistant EXE 同时运行。
; 原始 legacy/karabiner.ahk 和 legacy/string_change.ahk 保持不变。
; 功能迁移已完成，本文件仅保留历史侧键通知测试项。
;
; 有意不包含以下重复或已弃用入口：
;   ;red, ;fzg, ;fwj, ;fjd, ;cmx
;   RAlt+H/J/K/L（由 EXE 的 GlobalHjklArrows=true 接管）
;   Shift+Alt+R red_not.clip snapshot save
;   Ctrl+Win+Shift+S Viewer 截图
;   Ctrl+Win+Shift+M SUV/清除复按状态机
;   Ctrl+Win+Shift+A Arrow/清除复按状态机
;   Shift+Alt+B/H/L Montage（由 EXE 的 MontageHotkeys 接管）
;   Ctrl+Win+Shift+C 封面图（由 EXE 接管，2026-11-10 现场验收通过）
;
; 不得与原始 legacy scripts 同时运行。

A_IconTip := "MedEx Legacy Compatibility"

~XButton1::
{
    ToolTip "你按下了第一个侧键（XButton1）"
    SetTimer () => ToolTip(), -1000
}
