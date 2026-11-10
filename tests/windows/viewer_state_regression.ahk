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
    ready := {ok: true, waitable: false, code: "SAVE_BUTTON_READY"}
    gate := ReportImageCaptionSaveReadinessGate(1000)
    AssertViewerState(!gate.Observe(ready, 1000).done, "first ready sample cannot dispatch")
    AssertViewerState(!gate.Observe(ready, 1040).done, "minimum paste settle still applies")
    AssertViewerState(gate.Observe(ready, 1080).ok, "stable button ready at 80 ms")
    anotherPaste := ReportImageCaptionSaveReadinessGate(2000)
    AssertViewerState(!anotherPaste.Observe(ready, 2000).done, "each paste starts its own readiness")
    AssertViewerState(anotherPaste.Observe(ready, 2080).ok, "no first-window 500 ms gate")
    busy := {ok: false, waitable: true, code: "SAVE_BUTTON_DISABLED"}
    gate := ReportImageCaptionSaveReadinessGate(1000)
    gate.Observe(ready, 1000)
    AssertViewerState(!gate.Observe(busy, 1060).done, "disabled button may become ready without input")
    AssertViewerState(!gate.Observe(ready, 1080).done, "disable resets stable interval")
    AssertViewerState(gate.Observe(ready, 1120).ok, "stable interval after re-enable")
    timeoutGate := ReportImageCaptionSaveReadinessGate(1000)
    AssertViewerState(timeoutGate.Observe(busy, 1800).code = "SAVE_READY_TIMEOUT", "bounded readiness timeout")
    fatalGate := ReportImageCaptionSaveReadinessGate(1000)
    fatal := fatalGate.Observe({ok: false, waitable: false, code: "SAVE_BUTTON_NOT_UNIQUE"}, 1000)
    AssertViewerState(fatal.done && !fatal.ok && fatal.code = "SAVE_BUTTON_NOT_UNIQUE", "ambiguous target stops immediately")
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
