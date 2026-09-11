; Synthetic clipboard errors and native command dispatch. No clinical application.
global ReadinessSamples := []
global ReadinessSampleIndex := 0
global ReadinessSequence := 2

try {
    TestReadinessClipboard()
    TestReadinessCommand()
    FileAppend "Readiness regression: PASS" Chr(10), "*"
    ExitApp 0
} catch as readinessError {
    FileAppend "Readiness regression: FAIL - " readinessError.Message Chr(10), "**"
    ExitApp 1
}

MeasurementOption(options, key, fallback := 0) {
    return Type(options) = "Map" && options.Has(key) ? options[key] : fallback
}

GetMeasurementClipboardSequenceNumber() {
    global ReadinessSequence
    return ReadinessSequence
}

ReadTestClipboard() {
    global ReadinessSamples, ReadinessSampleIndex
    ReadinessSampleIndex += 1
    sample := ReadinessSamples[Min(ReadinessSampleIndex, ReadinessSamples.Length)]
    if IsObject(sample)
        throw Error("Synthetic clipboard temporarily inaccessible")
    return sample
}

ReadinessCapture(samples, sequence := 2) {
    global ReadinessSamples, ReadinessSampleIndex, ReadinessSequence
    ReadinessSamples := samples
    ReadinessSampleIndex := 0
    ReadinessSequence := sequence
    return WaitForMeasurementClipboardUpdate(1, "__sentinel__", Map(
        "clipboardTimeoutMs", 120, "clipboardPollIntervalMs", 10,
        "acceptEmptyClipboard", true, "emptyResultSettleMs", 30
    ))
}

AssertReadiness(condition, label) {
    if !condition
        throw Error(label)
}

TestReadinessClipboard() {
    result := ReadinessCapture([{}])
    AssertReadiness(!result.ok && result.failureReason = "CLIPBOARD_READ_FAILED",
        "read exceptions must not become an empty measurement")
    result := ReadinessCapture([""])
    AssertReadiness(result.ok && result.rawText = "", "genuine empty result")
    result := ReadinessCapture([{}, {}, "7.5"])
    AssertReadiness(result.ok && result.rawText = "7.5", "transient read error recovers")
    result := ReadinessCapture(["", {}, "", "", "", ""])
    AssertReadiness(result.ok && result.rawText = "", "empty settle restarts after error")
    result := ReadinessCapture(["7.5"], 1)
    AssertReadiness(!result.ok, "unchanged sequence is not fresh")
    result := ReadinessCapture(["__sentinel__"])
    AssertReadiness(!result.ok, "sentinel is never a result")
}

TestReadinessCommand() {
    panel := Gui("+ToolWindow")
    button := panel.AddButton("w100", "Synthetic")
    panel.Show("NoActivate w140 h80")
    try {
        action := Map("popupHwnd", panel.Hwnd, "commandControlHwnd", button.Hwnd,
            "commandRuntimeId", DllCall("User32\GetDlgCtrlID", "Ptr", button.Hwnd, "Int"),
            "expectedPid", DllCall("Kernel32\GetCurrentProcessId", "UInt"),
            "failureReason", "")
        button.Enabled := false
        AssertReadiness(!InvokePreparedMxNMContextCommand(action), "disabled target rejected")
        button.Enabled := true
        action["commandRuntimeId"] += 1
        AssertReadiness(!InvokePreparedMxNMContextCommand(action), "changed command ID rejected")
        action["commandRuntimeId"] -= 1
        AssertReadiness(InvokePreparedMxNMContextCommand(action), "live command dispatch")
        panel.Hide()
        AssertReadiness(!InvokePreparedMxNMContextCommand(action), "hidden popup rejected")
    } finally {
        panel.Destroy()
    }
}
