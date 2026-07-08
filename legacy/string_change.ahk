#Requires AutoHotkey v2.0

; Hotstring：插入红色的 (见图)
:*?:;red:: 
{
    InsertRedText()
    MouseGetPos &xpos, &ypos
    MouseClick "left", 671, 296 ; 点击字体颜色下拉菜单
    MouseClick "left", 678, 380 ; 选择黑色
    MouseMove xpos, ypos
    return
}

; Hotstring：插入 "放射性摄取增高，SUVmax约XXX。"，然后插入 (见图)
:*?:;fzg::
{
    SendText("放射性摄取增高，SUVmax约")
    InsertRedText()
    Sleep 50
    Send("{Left 4}")
    return
}

; Hotstring：插入 "放射性摄取未见明显增高（见图）"
:*?:;fwj::
{
    ; 插入纯文本部分
    SendText("放射性摄取未见明显增高")
    InsertRedText()
    return
}

; Hotstring：插入 "放射性摄取降低（见图）"
:*?:;fjd::
{
    ; 插入纯文本部分
    SendText("放射性摄取降低")
    InsertRedText()
    return
}

; Hotstring：输入两个数字并格式化为 x1cm×x2cm
:*?:;cmx::
{
    SendText("cm×cm")
    Send("{Left 2}")
    return
}

; Function: 插入红色见图函数
InsertRedText() {
    ; 保存当前剪切板的内容
    ClipSaved := ClipboardAll  ; 保存当前剪切板
    ClipWait  ; 等待剪贴板更新

    ; 读取之前保存的剪切板内容
    ClipData := FileRead("D:\AutoHotKey\red_not.clip", "RAW")  ; 从文件读取剪切板数据
    A_Clipboard := ClipboardAll(ClipData)  ; 设置剪贴板为读取的红色文本数据
    ClipWait  ; 等待剪贴板更新

    ; 自动完成粘贴操作
    Send("^v")  ; 使用 Ctrl+V 粘贴

    ; 恢复之前保存的剪切板内容
    Clipboard := ClipSaved  ; 恢复剪切板内容
    ClipWait  ; 等待剪贴板更新
}

