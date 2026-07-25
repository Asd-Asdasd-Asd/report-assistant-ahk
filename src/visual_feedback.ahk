class ReportAssistantVisualFeedback {
    static CurrentWindow := 0
    static CurrentToken := 0

    static Show(message, durationMs := 1500) {
        this.Hide()
        token := A_TickCount
        this.CurrentToken := token
        try {
            window := Gui(
                "+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000"
            )
            window.BackColor := "202124"
            window.SetFont("s10 cFFFFFF", "Segoe UI")
            window.MarginX := 16
            window.MarginY := 10
            window.Add("Text",, String(message))
            window.Show("NoActivate AutoSize Hide")
            window.GetPos(, , &width, &height)
            MonitorGetWorkArea(
                MonitorGetPrimary(),
                &workLeft,
                &workTop,
                &workRight,
                &workBottom
            )
            x := workRight - width - 24
            y := workBottom - height - 24
            window.Show("NoActivate x" x " y" y)
            this.CurrentWindow := window
            SetTimer(
                () => ReportAssistantVisualFeedback.HideIfCurrent(token),
                -Max(250, Integer(durationMs))
            )
            return true
        } catch {
            this.CurrentWindow := 0
            return false
        }
    }

    static HideIfCurrent(token) {
        if this.CurrentToken = token
            this.Hide()
    }

    static Hide() {
        if IsObject(this.CurrentWindow) {
            try this.CurrentWindow.Destroy()
        }
        this.CurrentWindow := 0
        this.CurrentToken := 0
    }
}

ShowReportAssistantVisualFeedback(message, durationMs := 1500) {
    return ReportAssistantVisualFeedback.Show(message, durationMs)
}

class ReportAssistantDispatchPulse {
    static CurrentWindow := 0
    static CurrentToken := 0

    static ShowForWindow(targetHwnd, durationMs := 90) {
        this.Hide()
        if !targetHwnd
            return false
        try WinGetPos(
            &windowX,
            &windowY,
            &windowWidth,
            &windowHeight,
            "ahk_id " targetHwnd
        )
        catch
            return false
        if windowWidth < 32 || windowHeight < 32
            return false

        this.CurrentToken += 1
        token := this.CurrentToken
        try {
            window := Gui(
                "+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000"
            )
            window.BackColor := "FFFFFF"
            window.Show(
                "Hide x" windowX " y" windowY
                    . " w" windowWidth " h" windowHeight
            )
            try WinSetTransparent(
                58,
                "ahk_id " window.Hwnd
            )
            try DllCall(
                "User32\SetWindowDisplayAffinity",
                "Ptr", window.Hwnd,
                "UInt", 0x00000011,
                "Int"
            )
            window.Show("NoActivate")
            this.CurrentWindow := window
            SetTimer(
                () => ReportAssistantDispatchPulse.HideIfCurrent(token),
                -Max(80, Integer(durationMs))
            )
            return true
        } catch {
            this.CurrentWindow := 0
            return false
        }
    }

    static HideIfCurrent(token) {
        if this.CurrentToken = token
            this.Hide()
    }

    static Hide() {
        if IsObject(this.CurrentWindow) {
            try this.CurrentWindow.Destroy()
        }
        this.CurrentWindow := 0
    }
}

ShowReportAssistantDispatchPulse(targetHwnd, durationMs := 90) {
    return ReportAssistantDispatchPulse.ShowForWindow(
        targetHwnd,
        durationMs
    )
}
