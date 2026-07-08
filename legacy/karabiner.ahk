#Requires AutoHotkey v2.0

RAlt & h::SendInput("{Left}")
RAlt & j::SendInput("{Down}")
RAlt & k::SendInput("{Up}")
RAlt & l::SendInput("{Right}")


; 将 \ 键映射为退格键
; \::Backspace

; 将退格键映射为 \ 键
; Backspace::\

; 将 `·` 键映射为 Esc 键
; `::Esc

; 将 Esc 键映射为 `·` 键
; Esc::`

; HHKB 改键
; LAlt::LWin
; LWin::LAlt
; RAlt::RWin
; RWin::RAlt

; RWin & h::Send("{Left}")
; RWin & j::Send("{Down}")
; RWin & k::Send("{Up}")
; RWin & l::Send("{Right}")

; 鼠标改键

~XButton1::  ; 按下第一个侧键（通常是前侧键）
{
    ToolTip "你按下了第一个侧键（XButton1）" ; 弹出提示框
    SetTimer () => ToolTip(), -1000
}

+!b::  ; Shift + Alt + B
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

+!h::  ; Shift + Alt + H
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
    SendText("11") ; 当前层
    MouseClick "left", 2175, 801
    MouseClick "left", 2133, 623
    MouseClick "left", 2129, 836, 2
    SendText("1.2")
    Send "{Enter}"
    ToolTip "OK" 
    SetTimer () => ToolTip(), -1000
    return
}

+!l::  ; Shift + Alt + L
{
    CoordMode "Mouse", "Screen"
    Sleep 000
    MouseClick "left", 2208, 556  ; 排版
    MouseClick "left", 2073, 628  ;点击标注tab
    MouseClick "left", 2152, 1100 ; 删除图注
    MouseClick "left", 2031, 1202
    MouseClick "left", 2188, 628
    MouseClick "left", 2199, 673
    MouseClick "left", 2132, 754
    MouseClick "left", 2030, 720, 2
    SendText("7.5")               ; 层厚
    MouseClick "left", 2171, 719
    MouseClick "left", 2057, 806, 2
    SendText("23") ; 当前层
    MouseClick "left", 2175, 801
    MouseClick "left", 2133, 623
    MouseClick "left", 2129, 836, 2
    SendText("0.9")
    Send "{Enter}"
    ToolTip "OK" 
    SetTimer () => ToolTip(), -1000
    return
}

+!s::  ; 快速标图
{
    CoordMode "Mouse", "Screen"
    MouseGetPos &xpos, &ypos
    SendInput("^c")
    MouseClick "left", 2821, 1363   ; 点击输入框
    SendInput("^v")
    MouseMove 2884, 704
    SendInput("{WheelDown}")
    MouseMove xpos, ypos
}

^#+s::  ; hyper + s 截图
{
    CoordMode "Mouse", "Screen"
    MouseGetPos &xpos, &ypos
    MouseClick "left", 1981, 1350
    MouseMove xpos, ypos
}

global LastPressSUVTime := 0
^#+m::  ; hyper + m 测量SUV
{
    CoordMode "Mouse", "Screen"
    StartTime := A_TickCount
    TimeSinceLastPress := StartTime - LastPressSUVTime
    
    if (TimeSinceLastPress > 3000)
    {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 2471, 826 ; 点击测量SUV
        MouseMove xpos, ypos
    }
    else
    {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 1963, 627 ; 点击标注tab
        MouseClick "left", 2043, 1113 ; 点击清除
        MouseMove xpos, ypos
    }
    global LastPressSUVTime := StartTime
    return
}

global LastPressArrowTime := 0
^#+a::  ; hyper + a 箭头
{
    CoordMode "Mouse", "Screen"
    StartTime := A_TickCount
    TimeSinceLastPress := StartTime - LastPressArrowTime
    
    if (TimeSinceLastPress > 1000)
    {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 2470, 651 ; 点击Arrow
        MouseMove xpos, ypos
    }
    else
    {
        MouseGetPos &xpos, &ypos
        MouseClick "left", 2079, 626 ; 点击标注tab
        MouseClick "left", 2170, 989 ; 点击清除
        MouseMove xpos, ypos
    }
    global LastPressArrowTime := StartTime
    return
}

^#+c::  ; hyper + c 封面图
{
    CoordMode "Mouse", "Screen"
    MouseGetPos &xpos, &ypos
    MouseClick "left", 2129, 404   ; 点击排版
    MouseClick "left", 2073, 628   ; 点击标注tab
    MouseClick "left", 2153, 1099  ; 点击图注栏
    MouseClick "left", 2133, 1123  ; 增加图注
    MouseClick "left", 3637, 1084  ; 点击投影
    MouseClick "left", 1983, 1204  ; 保存左图
    MouseClick "left", 2935, 1081  ; 点击融合图
    MouseClick "left", 2177, 1289  ; 恢复默认
    MouseClick "left", 2084, 1202  ; 保存右图
    MouseMove xpos, ypos
}

+!r::  ; 保存剪切板
{
    FileDelete "D:\AutoHotKey\red_not.clip"
    FileAppend ClipboardAll(), "D:\AutoHotKey\red_not.clip"

    MsgBox "剪切板内容已保存!"
    return
}