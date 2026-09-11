; Entry fragment for build_viewer_state_regression.py.
; Execute the generated standalone file with AutoHotkey v2 on Windows.
try {
    RunViewerStateRegression()
    FileAppend "Viewer state regression: PASS`n", "*"
    ExitApp 0
} catch as regressionError {
    FileAppend "Viewer state regression: FAIL - " regressionError.Message "`n", "**"
    ExitApp 1
}

RunViewerStateRegression() {
    target := {pid: 101, hwnd: 1001}
    ReportImageCaptionPasteGate.ReadyTargetKey := ""
    AssertViewerState(ReportImageCaptionPasteGate.Plan(target).milliseconds = 500, "first target")
    ; Resolving/planning then cancelling must not consume the first save gate.
    AssertViewerState(ReportImageCaptionPasteGate.Plan(target).milliseconds = 500, "cancel before paste")
    ReportImageCaptionPasteGate.ObserveSave(target)
    AssertViewerState(ReportImageCaptionPasteGate.Plan(target).milliseconds = 20, "saved target")
    AssertViewerState(ReportImageCaptionPasteGate.Plan({pid: 101, hwnd: 1002}).milliseconds = 500, "new HWND in same process")
    AssertViewerState(ReportImageCaptionPasteGate.Plan({pid: 102, hwnd: 1001}).milliseconds = 500, "new process")
    AssertViewerState(MxNMViewerReleaseDecision(true, true, 2999, 3000) = "WAITING", "held before deadline")
    AssertViewerState(MxNMViewerReleaseDecision(true, true, 3000, 3000) = "KEY_RELEASE_TIMEOUT", "held at deadline")
    AssertViewerState(MxNMViewerReleaseDecision(false, true, 0, 3000) = "RELEASED", "next press can release")
    AssertViewerState(MxNMViewerReleaseDecision(false, false, 0, 3000) = "FOREGROUND_CHANGED", "cancel even after release")
    TestColorResetFailureSelection()
    TestViewerNativePanels()
}

TestViewerNativePanels() {
    panel := Gui("+ToolWindow")
    duplicate := Gui("+ToolWindow")
    try {
        controls := AddViewerTestButtons(panel)
        panel.Show("NoActivate x20 y20 w140 h130")
        controls["suv3d"].Enabled := false
        plan := {commands: Map()}
        for spec in MxNMViewerToolCommand.Specs()
            plan.commands[spec.id] := {commandId: spec.commandId, row: 0, column: 0}
        result := ResolveMxNMViewerToolControlSet(plan, [{hwnd: panel.Hwnd}])
        AssertViewerState(result.ok, "disabled sibling still identifies unique panel")
        AssertViewerState(result.controls["length"].controlId = 21048, "length identity independent of row")
        AddViewerTestButtons(duplicate)
        duplicate.Show("NoActivate x180 y20 w140 h130")
        result := ResolveMxNMViewerToolControlSet(plan, [{hwnd: panel.Hwnd}, {hwnd: duplicate.Hwnd}])
        AssertViewerState(!result.ok && result.code = "BUTTON_SET_NOT_UNIQUE", "two complete panels rejected")
    } finally {
        duplicate.Destroy()
        panel.Destroy()
    }
}

AddViewerTestButtons(panel) {
    buttons := Map()
    ; Deliberately use a different visual order from historical vendor rows.
    for index, spec in [MxNMViewerToolCommand.Specs()[3], MxNMViewerToolCommand.Specs()[1], MxNMViewerToolCommand.Specs()[2]] {
        button := panel.Add("Button", "x10 y" (10 + (index - 1) * 35) " w110 h25", spec.id)
        DllCall(A_PtrSize = 8 ? "User32\SetWindowLongPtrW" : "User32\SetWindowLongW", "Ptr", button.Hwnd, "Int", -12, "Ptr", spec.commandId, "Ptr")
        buttons[spec.id] := button
    }
    return buttons
}

AssertViewerState(condition, label) {
    if !condition
        throw Error(label)
}

TestColorResetFailureSelection() {
    oldCaption := {action: "ReportImageCaption", timestamp: "2026-09-04T18:38:57", source: "AUTOMATION"}
    currentFailure := "timestamp=2026-09-07T09:45:20 appVersion=0.8.0 action=MedExColorReset resultCode=ANCHOR_NOT_READY preflightStage=redResetReadiness readinessReason=exactAnchorNotReady exactAnchorQueryCount=8 exactAnchorCandidateCount=0 readinessElapsedMs=406 unlisted=SENSITIVE_FIXTURE"
    color := FindRecentColorResetFailureEvent([currentFailure, ""])
    AssertViewerState(color.timestamp = "2026-09-07T09:45:20", "legacy timestamp parsed")
    AssertViewerState(NewerAutomationDiagnosticEvent(oldCaption, color).source = "COLOR_RESET_FAILURE", "current failure beats stale Caption")
    AssertViewerState(InStr(color.summary, "resultCode=ANCHOR_NOT_READY"), "failure code retained")
    AssertViewerState(InStr(color.summary, "readinessElapsedMs=406"), "failure timing retained")
    AssertViewerState(!InStr(color.summary, "SENSITIVE_FIXTURE"), "unlisted content omitted")
    newerCapture := {action: "ViewerCapture", timestamp: "2026-09-07T09:46:00", source: "AUTOMATION"}
    AssertViewerState(NewerAutomationDiagnosticEvent(newerCapture, color).action = "ViewerCapture", "old color failure cannot hide new capture")
    missing := FindRecentColorResetFailureEvent([])
    AssertViewerState(NewerAutomationDiagnosticEvent(oldCaption, missing).action = "ReportImageCaption", "missing legacy file does not replace event")
}
