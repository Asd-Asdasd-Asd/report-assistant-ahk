#Requires AutoHotkey v2.0
#SingleInstance Force

; v0.5.x 迁移期 compatibility script，可与 MedEx Report Assistant EXE 同时运行。
; 原始 legacy/karabiner.ahk 和 legacy/string_change.ahk 保持不变。
; 本文件只保留 EXE 尚未接管的 legacy viewer/annotation actions。
;
; 有意不包含以下重复或已弃用入口：
;   ;red, ;fzg, ;fwj, ;fjd, ;cmx
;   RAlt+H/J/K/L（由 EXE 的 GlobalHjklArrows=true 接管）
;   Shift+Alt+R red_not.clip snapshot save
;   Ctrl+Win+Shift+S Viewer 截图
;   Ctrl+Win+Shift+M SUV/清除复按状态机
;   Ctrl+Win+Shift+A Arrow/清除复按状态机
;   Shift+Alt+B/H/L Montage（由 EXE 的 MontageHotkeys 接管）
;
; 以下固定坐标和固定数值从 legacy/karabiner.ahk 保守复制，尚未增加窗口校验。
; 启用前必须在目标工作站确认；不得与原始 legacy scripts 同时运行。

A_IconTip := "MedEx Legacy Compatibility"

~XButton1::
{
    ToolTip "你按下了第一个侧键（XButton1）"
    SetTimer () => ToolTip(), -1000
}

^#+c::
{
    CoordMode "Mouse", "Screen"
    MouseGetPos &xpos, &ypos
    MouseClick "left", 2129, 404
    MouseClick "left", 2073, 628
    MouseClick "left", 2153, 1099
    MouseClick "left", 2133, 1123
    MouseClick "left", 3637, 1084
    MouseClick "left", 1983, 1204
    MouseClick "left", 2935, 1081
    MouseClick "left", 2177, 1289
    MouseClick "left", 2084, 1202
    MouseMove xpos, ypos
}
