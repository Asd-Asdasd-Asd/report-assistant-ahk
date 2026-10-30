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
    TestReportHotstringDiagnosticFields()
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

TestReportHotstringDiagnosticFields() {
    oldCaption := {action: "ReportImageCaption", timestamp: "2026-09-04T18:38:57", source: "AUTOMATION"}
    newerFailure := {action: "ContextTarget", timestamp: "2026-09-07T09:45:20", source: "VIEWER_FAILURE"}
    AssertViewerState(NewerAutomationDiagnosticEvent(oldCaption, newerFailure).source = "VIEWER_FAILURE", "newer viewer failure wins")
    missing := {action: "NONE", timestamp: "", source: "NONE"}
    AssertViewerState(NewerAutomationDiagnosticEvent(oldCaption, missing).action = "ReportImageCaption", "missing event does not replace")

    stages := [{name: "OPERATION_STARTED", tickOffsetMs: 0}, {name: "REPORT_WRITE_RETURNED", tickOffsetMs: 412}]
    AssertViewerState(AutomationDiagnosticStageList(stages) = "OPERATION_STARTED@0>REPORT_WRITE_RETURNED@412", "stage offsets inline")

    perf := Map("ColorResetStartedMs", 1000, "ArrowClickSentMs", 1090, "BlackClickSentMs", 1112, "ColorResetReturnedMs", 1120)
    context := Map("popupSignatureSampleCount", 1, "popupSignatureFirstReason", "allRequiredPixelsMatched", "mouseRestored", true, "elapsedMs", 120, "arrowPoint", Map("x", 1, "y", 2))
    fields := ReportColorResetDiagnosticFields({ok: true, code: "RELATIVE_MOUSE_CHAIN_OK", context: context}, perf)
    AssertViewerState(fields["color.arrowToBlackMs"] = 22, "arrow to black duration")
    AssertViewerState(fields["color.resetToArrowMs"] = 90, "reset to arrow duration")
    AssertViewerState(fields["color.blackToReturnMs"] = 8, "black to return duration")
    AssertViewerState(fields["color.mouseRestored"] = "true", "mouse restore flag")
    AssertViewerState(!fields.Has("color.failureReason"), "success has no failure reason")
    AssertViewerState(!fields.Has("color.arrowPoint"), "geometry is not logged")

    failed := ReportColorResetDiagnosticFields({ok: false, code: "COLOR_RESET_POPUP_SIGNATURE_MISMATCH", context: Map("popupSignatureReason", "blueSwatchMismatch")})
    AssertViewerState(failed["color.failureReason"] = "popupSignatureReason:blueSwatchMismatch", "failure reason kept")
    AssertViewerState(failed["color.arrowToBlackMs"] = "UNKNOWN", "missing timing is explicit")
}
