#Requires AutoHotkey v2.0
#SingleInstance Force

; v0.5.x 迁移期预备 compatibility scaffold。
; 原始 legacy/karabiner.ahk 和 legacy/string_change.ahk 保持不变。
; 在新项目 MedEx color reset 完成并验证前，不要把本文件作为现有完整工作流的替代品。
;
; 有意不包含以下重复或已弃用入口：
;   ;red, ;fzg, ;fwj, ;fjd, ;cmx
;   Shift+Alt+R red_not.clip snapshot save
;
; 以下固定坐标和固定数值从 legacy/karabiner.ahk 保守复制，尚未增加窗口校验。
; 启用前必须在目标工作站确认；不得与原始 legacy scripts 同时运行。

A_IconTip := "MedEx Legacy Compatibility"

RAlt & h::SendInput("{Left}")
RAlt & j::SendInput("{Down}")
RAlt & k::SendInput("{Up}")
RAlt & l::SendInput("{Right}")

~XButton1::
{
    ToolTip "你按下了第一个侧键（XButton1）"
    SetTimer () => ToolTip(), -1000
}

+!b::
{
    CoordMode "Mouse", "Screen"
    Sleep 000
    MouseClick "left", 2208, 556 ; Purpose: 选择固定组合图模板，Current target: 排列模式缩略图区域中的目标模板，UI status: 内部缩略图未暴露，预计使用外层 Image + 相对坐标
    MouseClick "left", 2073, 628 ; 点击工具栏tab标签页的第3个按钮，tab暴露，内部按钮不暴露
    MouseClick "left", 2152, 1100 ; Purpose: 展开四角标记下拉选单，Current target: Name="打开", ControlType=Button，Migration candidate: UIA Invoke，坐标点击仅作为 fallback
    MouseClick "left", 2031, 1202 ; 选择下拉菜单中的NULL选项，消除图片四角标记，输入框展开之后暴露
    MouseClick "left", 2188, 628 ; 选择工具栏tab标签页的第5个按钮，和上面一样，不暴露按钮，但暴露tab整体
    MouseClick "left", 2030, 720, 2 ; 双击层厚x毫米的输入框，输入框暴露
    SendText("8.5") ; 输入层厚数字，以下可以默认暴露ui，除非特别说明
    MouseClick "left", 2171, 719 ;点击更改按钮
    MouseClick "left", 2057, 806, 2 ;双击当前层数输入框
    SendText("8") ; 输入数字8
    MouseClick "left", 2175, 801 ;点击更改按钮
    MouseClick "left", 2133, 623 ; 点击tab的第4个按钮，同上，不单独暴露
    MouseClick "left", 2129, 836, 2 ; 图像缩放大小的输入框
    SendText("0.8") ; 0.8倍大小
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
