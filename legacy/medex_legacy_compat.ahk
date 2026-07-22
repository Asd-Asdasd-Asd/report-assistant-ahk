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
;
; 以下固定坐标和固定数值从 legacy/karabiner.ahk 保守复制，尚未增加窗口校验。
; 启用前必须在目标工作站确认；不得与原始 legacy scripts 同时运行。

A_IconTip := "MedEx Legacy Compatibility"

~XButton1::
{
    ToolTip "你按下了第一个侧键（XButton1）"
    SetTimer () => ToolTip(), -1000
}

+!b::
{
    CoordMode "Mouse", "Screen"
    Sleep 000
    MouseClick "left", 2208, 556
    MouseClick "left", 2073, 628
    MouseClick "left", 2152, 1100
    MouseClick "left", 2031, 1202
    MouseClick "left", 2188, 628
    MouseClick "left", 2030, 720, 2
    SendText("8.5")
    MouseClick "left", 2171, 719
    MouseClick "left", 2057, 806, 2
    SendText("8")
    MouseClick "left", 2175, 801
    MouseClick "left", 2133, 623
    MouseClick "left", 2129, 836, 2
    SendText("0.8")
    Send "{Enter}"
    ToolTip "OK"
    SetTimer () => ToolTip(), -1000
    return
}

+!h::
{
    CoordMode "Mouse", "Screen"
    Sleep 000
    MouseClick "left", 2208, 556
    MouseClick "left", 2073, 628
    MouseClick "left", 2152, 1100
    MouseClick "left", 2031, 1202
    MouseClick "left", 2188, 628
    MouseClick "left", 2030, 720, 2
    SendText("4")
    MouseClick "left", 2171, 719
    MouseClick "left", 2057, 806, 2
    SendText("11")
    MouseClick "left", 2175, 801
    MouseClick "left", 2133, 623
    MouseClick "left", 2129, 836, 2
    SendText("1.2")
    Send "{Enter}"
    ToolTip "OK"
    SetTimer () => ToolTip(), -1000
    return
}

+!l::
{
    CoordMode "Mouse", "Screen"
    Sleep 000
    MouseClick "left", 2208, 556
    MouseClick "left", 2073, 628
    MouseClick "left", 2152, 1100
    MouseClick "left", 2031, 1202
    MouseClick "left", 2188, 628
    MouseClick "left", 2199, 673
    MouseClick "left", 2132, 754
    MouseClick "left", 2030, 720, 2
    SendText("7.5")
    MouseClick "left", 2171, 719
    MouseClick "left", 2057, 806, 2
    SendText("23")
    MouseClick "left", 2175, 801
    MouseClick "left", 2133, 623
    MouseClick "left", 2129, 836, 2
    SendText("0.9")
    Send "{Enter}"
    ToolTip "OK"
    SetTimer () => ToolTip(), -1000
    return
}

+!s::
{
    CoordMode "Mouse", "Screen"
    MouseGetPos &xpos, &ypos
    SendInput("^c")
    MouseClick "left", 2821, 1363
    SendInput("^v")
    MouseMove 2884, 704
    SendInput("{WheelDown}")
    MouseMove xpos, ypos
}

^#+s::
{
    CoordMode "Mouse", "Screen"
    MouseGetPos &xpos, &ypos
    MouseClick "left", 1981, 1350
    MouseMove xpos, ypos
}

global LastPressSUVTime := 0

^#+m::
{
    CoordMode "Mouse", "Screen"
    startTime := A_TickCount
    timeSinceLastPress := startTime - LastPressSUVTime

    if (timeSinceLastPress > 3000) {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 2471, 826
        MouseMove xpos, ypos
    } else {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 1963, 627
        MouseClick "left", 2043, 1113
        MouseMove xpos, ypos
    }

    global LastPressSUVTime := startTime
    return
}

global LastPressArrowTime := 0

^#+a::
{
    CoordMode "Mouse", "Screen"
    startTime := A_TickCount
    timeSinceLastPress := startTime - LastPressArrowTime

    if (timeSinceLastPress > 1000) {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 2470, 651
        MouseMove xpos, ypos
    } else {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 2079, 626
        MouseClick "left", 2170, 989
        MouseMove xpos, ypos
    }

    global LastPressArrowTime := startTime
    return
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
