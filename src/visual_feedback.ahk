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

class ReportImageCaptionTransferFeedback {
    static CardWindow := 0
    static CurrentState := 0
    static CurrentToken := 0
    static DurationMs := 200
    static FrameMs := 16
    static CardWidth := 42
    static CardHeight := 28
    static MinimumScale := 0.48

    static Show(origin, destination) {
        this.Hide()
        if !IsObject(origin)
            || !IsObject(destination) {
            return false
        }

        this.CurrentToken += 1
        token := this.CurrentToken
        try {
            card := Gui(
                "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
                    . " +E0x20 +E0x08000000"
            )
            card.BackColor := "3F4650"
            card.MarginX := 0
            card.MarginY := 0
            card.SetFont("s13 Bold cF4F5F7", "Segoe UI")
            card.Add(
                "Text",
                "x0 y-2 w" this.CardWidth
                    . " h" this.CardHeight
                    . " Center BackgroundTrans",
                "≡"
            )
            card.Show(
                "NoActivate Hide x" Round(origin.x - this.CardWidth / 2)
                    . " y" Round(origin.y - this.CardHeight / 2)
                    . " w" this.CardWidth
                    . " h" this.CardHeight
            )
            this.RoundWindow(card.Hwnd, this.CardWidth, this.CardHeight, 6)
            try WinSetTransparent(232, "ahk_id " card.Hwnd)
            this.ExcludeFromCapture(card.Hwnd)
            card.Show("NoActivate")

            this.CardWindow := card
            state := {
                token: token,
                startedAt: A_TickCount,
                origin: origin,
                destination: destination,
                card: card
            }
            this.CurrentState := state
            SetTimer(
                ReportImageCaptionTransferFeedbackCleanupTimer,
                -(this.DurationMs + 250)
            )
            this.AdvanceCurrent()
            return true
        } catch {
            this.Hide()
            return false
        }
    }

    static AdvanceCurrent() {
        state := this.CurrentState
        if !IsObject(state)
            return
        if state.token != this.CurrentToken
            return
        elapsed := Max(0, A_TickCount - state.startedAt)
        progress := Min(1, elapsed / this.DurationMs)
        eased := progress * progress * (3 - 2 * progress)

        deltaX := state.destination.x - state.origin.x
        deltaY := state.destination.y - state.origin.y
        distance := Sqrt(deltaX * deltaX + deltaY * deltaY)
        arcHeight := Min(76, Max(18, distance * 0.045))
        curveX := (state.origin.x + state.destination.x) / 2
        curveY := (state.origin.y + state.destination.y) / 2 - arcHeight
        inverse := 1 - eased
        centerX := inverse * inverse * state.origin.x
            + 2 * inverse * eased * curveX
            + eased * eased * state.destination.x
        centerY := inverse * inverse * state.origin.y
            + 2 * inverse * eased * curveY
            + eased * eased * state.destination.y

        arrival := progress <= 0.7
            ? 0
            : (progress - 0.7) / 0.3
        scale := (1 + 0.08 * Sin(progress * ACos(-1)))
            * (1 - (1 - this.MinimumScale) * arrival * arrival)
        width := Max(12, Round(this.CardWidth * scale))
        height := Max(8, Round(this.CardHeight * scale))
        cardX := Round(centerX - width / 2)
        cardY := Round(centerY - height / 2)
        try {
            state.card.Show(
                "NoActivate x" cardX
                    . " y" cardY
                    . " w" width
                    . " h" height
            )
            this.RoundWindow(
                state.card.Hwnd,
                width,
                height,
                Max(3, Round(6 * scale))
            )
            cardOpacity := progress < 0.78
                ? 232
                : Round(232 * (1 - (progress - 0.78) / 0.22))
            WinSetTransparent(
                Max(0, cardOpacity),
                "ahk_id " state.card.Hwnd
            )

        } catch {
            this.Hide()
            return
        }

        if progress >= 1 {
            this.HideIfCurrent(state.token)
            return
        }
        SetTimer(
            ReportImageCaptionTransferFeedbackTimer,
            -this.FrameMs
        )
    }

    static RoundWindow(hwnd, width, height, radius) {
        try WinSetRegion(
            "0-0 W" Max(1, width)
                . " H" Max(1, height)
                . " R" Max(1, radius) "-" Max(1, radius),
            "ahk_id " hwnd
        )
    }

    static ExcludeFromCapture(hwnd) {
        try DllCall(
            "User32\SetWindowDisplayAffinity",
            "Ptr", hwnd,
            "UInt", 0x00000011,
            "Int"
        )
    }

    static HideIfCurrent(token) {
        if this.CurrentToken = token
            this.Hide()
    }

    static Hide() {
        try SetTimer(ReportImageCaptionTransferFeedbackTimer, 0)
        try SetTimer(ReportImageCaptionTransferFeedbackCleanupTimer, 0)
        if IsObject(this.CardWindow) {
            try this.CardWindow.Destroy()
        }
        this.CardWindow := 0
        this.CurrentState := 0
    }
}

ReportImageCaptionTransferFeedbackTimer(*) {
    try ReportImageCaptionTransferFeedback.AdvanceCurrent()
    catch {
        ReportImageCaptionTransferFeedback.Hide()
    }
}

ReportImageCaptionTransferFeedbackCleanupTimer(*) {
    ReportImageCaptionTransferFeedback.Hide()
}

ShowReportImageCaptionTransferFeedback(
    origin,
    destination
) {
    return ReportImageCaptionTransferFeedback.Show(
        origin,
        destination
    )
}
