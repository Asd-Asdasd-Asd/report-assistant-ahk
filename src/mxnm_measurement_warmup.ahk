class MxNMMeasurementWarmupDefaults {
    static ViewerSettleMs := 1500
    static RetryIntervalMs := 5000
    static FallbackPollIntervalMs := 15000
    static ReadyHealthCheckIntervalMs := 60000
    static ShellEventDebounceMs := 250
    static ShellMessageName := "SHELLHOOK"
    static ShellWindowCreated := 1
    static ShellWindowDestroyed := 2
}

MxNMMeasurementWarmupRuntime := Map(
    "started", false,
    "shellMessageId", 0,
    "shellHookRegistered", false
)

StartMxNMMeasurementTargetWarmup() {
    global MxNMMeasurementWarmupRuntime
    if MxNMMeasurementWarmupRuntime["started"]
        return

    MxNMMeasurementWarmupRuntime["started"] := true
    shellMessageId := 0
    shellHookRegistered := false
    try shellMessageId := DllCall(
        "User32\RegisterWindowMessageW",
        "Str", MxNMMeasurementWarmupDefaults.ShellMessageName,
        "UInt"
    )
    catch {
        shellMessageId := 0
    }
    if shellMessageId {
        try shellHookRegistered := DllCall(
            "User32\RegisterShellHookWindow",
            "Ptr", A_ScriptHwnd,
            "Int"
        ) != 0
        catch {
            shellHookRegistered := false
        }
    }
    if shellHookRegistered {
        try {
            OnMessage(shellMessageId, HandleMxNMShellHookMessage)
            MxNMMeasurementWarmupRuntime["shellMessageId"] := shellMessageId
            MxNMMeasurementWarmupRuntime["shellHookRegistered"] := true
        } catch {
            try DllCall(
                "User32\DeregisterShellHookWindow",
                "Ptr", A_ScriptHwnd,
                "Int"
            )
        }
    }

    ; Startup-folder launches normally precede the viewer. Probe once without
    ; touching config/UIA, then rely on shell events or the low-frequency
    ; fallback until a viewer session exists.
    ProbeMxNMMeasurementWarmup()
}

HandleMxNMShellHookMessage(wParam, lParam, msg, hwnd) {
    if wParam != MxNMMeasurementWarmupDefaults.ShellWindowCreated
        && wParam != MxNMMeasurementWarmupDefaults.ShellWindowDestroyed {
        return
    }
    ; Shell callbacks must remain cheap. Defer process discovery, cache
    ; validation and all UIA work to an ordinary timer callback.
    SetTimer(
        ProbeMxNMMeasurementWarmup,
        -MxNMMeasurementWarmupDefaults.ShellEventDebounceMs
    )
}

ProbeMxNMMeasurementWarmup(*) {
    if MxNMMeasurementProvider.HasReusableTarget() {
        SetTimer WarmMxNMMeasurementTarget, 0
        EnsureMxNMMeasurementWarmupPoll(true)
        return
    }

    if WinExist("ahk_exe " MxNMConfigGeometryDefaults.ViewerExe) {
        SetTimer(
            WarmMxNMMeasurementTarget,
            -MxNMMeasurementWarmupDefaults.ViewerSettleMs
        )
    }
    EnsureMxNMMeasurementWarmupPoll()
}

WarmMxNMMeasurementTarget(*) {
    if MxNMMeasurementProvider.HasReusableTarget() {
        EnsureMxNMMeasurementWarmupPoll(true)
        return
    }
    if !WinExist("ahk_exe " MxNMConfigGeometryDefaults.ViewerExe) {
        EnsureMxNMMeasurementWarmupPoll()
        return
    }
    if MxNMMeasurementProvider.WarmTarget() {
        EnsureMxNMMeasurementWarmupPoll(true)
        return
    }

    ; The first top-level viewer window can appear before its final geometry
    ; and UIA panes. Retry once the session has had more time to settle.
    SetTimer(
        WarmMxNMMeasurementTarget,
        -MxNMMeasurementWarmupDefaults.RetryIntervalMs
    )
    EnsureMxNMMeasurementWarmupPoll()
}

PollMxNMMeasurementWarmup(*) {
    ProbeMxNMMeasurementWarmup()
}

EnsureMxNMMeasurementWarmupPoll(targetReady := false) {
    global MxNMMeasurementWarmupRuntime
    intervalMs := targetReady
        && MxNMMeasurementWarmupRuntime["shellHookRegistered"]
            ? MxNMMeasurementWarmupDefaults.ReadyHealthCheckIntervalMs
            : MxNMMeasurementWarmupDefaults.FallbackPollIntervalMs
    SetTimer(
        PollMxNMMeasurementWarmup,
        intervalMs
    )
}
