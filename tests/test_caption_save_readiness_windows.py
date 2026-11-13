"""Run Caption save/advance decisions in AHK with external input boundaries stubbed."""
import os
from pathlib import Path
import unittest

import test_maintenance_windows as maintenance

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt" and maintenance.ahk_executable(), "requires Windows and AutoHotkey v2")
class CaptionSaveTimingWindowsTests(unittest.TestCase):
    run_ahk = maintenance.MaintenanceWindowsTests.run_ahk

    def test_caret_fallback_requires_unchanged_focus_and_fresh_copy(self):
        source = (ROOT / "src/report_image_caption.ahk").read_text(encoding="utf-8")
        definitions = source.split("\nReportImageCaptionHotkeyDefinitions(", 1)[0]
        capture = source.split("\nCaptureFreshReportImageCaption(", 1)[1].split(
            "\nReportImageCaptionFocusStillMatches(", 1
        )[0]
        capture = ("CaptureFreshReportImageCaption(" + capture).replace(
            "UIA.GetFocusedElement()", "({})"
        ).replace('WinExist("A")', "1001").replace(
            'A_Clipboard := ""', "CaptionTestClear()"
        ).replace('SendInput "^c"', 'CaptionTestInput("^c")').replace(
            'SendInput "^+{End}^c"', 'CaptionTestInput("^+{End}^c")'
        ).replace('SendInput "{Left}"', 'CaptionTestInput("{Left}")').replace(
            "ClipWait(", "CaptionTestWait("
        ).replace("ClipboardAll()", '("RICH_SELECTION")').replace(
            "A_Clipboard", "CaptionTestText()"
        )
        results = "MakeReportImageCaptionResult(" + source.split(
            "\nMakeReportImageCaptionResult(", 1
        )[1].split("\nReportImageCaptionFailureMessage(", 1)[0]
        includes = f'#Include {ROOT / "src/hotstring_model.ahk"}\n'
        self.run_ahk(includes + '''
try {
    global CaptionCase, CaptionKeys, CaptionSequence, CaptionText
    for sample in [
        ["manual", "手选（见图）", "", "OK", "RICH_SELECTION", "^c"],
        ["caret", "", "甲段`r`n乙段（见图）后续（见图）", "OK", "甲段`r`n乙段", "^c^+{End}^c{Left}"],
        ["no-marker", "", "正文见图但没有括号", "FIGURE_MARKER_NOT_FOUND", "", "^c^+{End}^c{Left}"],
        ["empty", "", " （见图）", "FIGURE_MARKER_NOT_FOUND", "", "^c^+{End}^c{Left}"],
        ["end", "", "", "COPY_FAILED", "", "^c^+{End}^c"],
        ["wrong-focus", "", "甲（见图）", "COPY_FAILED", "", "^c"],
        ["focus-lost", "", "甲（见图）", "SOURCE_CHANGED", "", "^c^+{End}^c"],
        ["late-copy", "", "甲（见图）", "COPY_FAILED", "", "^c"],
        ["copy-error", "", "甲（见图）", "COPY_FAILED", "", "^c"]
    ] {
        CaptionCase := sample
        CaptionKeys := ""
        CaptionSequence := 1
        CaptionText := ""
        observedCapture := CaptureFreshReportImageCaption(1001)
        if observedCapture.code != sample[4] || CaptionKeys != sample[6]
            throw Error(sample[1] ": wrong capture result or input sequence")
        if observedCapture.ok && observedCapture.payload != sample[5]
            throw Error(sample[1] ": wrong caption payload")
    }
    FileAppend("PASS", "*")
    ExitApp(0)
} catch as err {
    FileAppend(err.Message, "**")
    ExitApp(1)
}
CaptionTestClear() {
    global CaptionSequence, CaptionText
    CaptionSequence += 1
    CaptionText := ""
}
CaptionTestInput(keys) {
    global CaptionCase, CaptionKeys, CaptionSequence, CaptionText
    CaptionKeys .= keys
    if keys = "{Left}"
        return
    CaptionText := keys = "^c" ? CaptionCase[2] : CaptionCase[3]
    if CaptionText != "" || CaptionCase[1] = "copy-error"
        CaptionSequence += 1
}
CaptionTestWait(*) => CaptionTestText() != ""
CaptionTestText() {
    global CaptionText
    return CaptionText
}
ReportImageCaptionFocusStillMatches(*) {
    global CaptionCase, CaptionKeys
    return CaptionCase[1] != "focus-lost" || CaptionKeys = "^c"
}
ReportImageCaptionFocusIsReportEditor(*) {
    global CaptionCase, CaptionSequence
    if CaptionCase[1] = "late-copy"
        CaptionSequence += 1
    return CaptionCase[1] != "wrong-focus"
}
ReportImageCaptionClipboardSequence() {
    global CaptionSequence
    return CaptionSequence
}
ReportImageCaptionCopyModifierMask() => 0
SetReportImageCaptionCopyDiagnostic(*) => 0
''' + definitions + "\n" + capture + "\n" + results)

    def test_actual_action_waits_then_saves_or_stops_without_advancing(self):
        source = (ROOT / "src/report_image_caption.ahk").read_text(encoding="utf-8")
        definitions = source.split("\nReportImageCaptionHotkeyDefinitions(", 1)[0]
        action = "ExecuteReportImageCaptionAction(" + source.split(
            "\nExecuteReportImageCaptionAction(", 1)[1].split(
                "\nValidateReportImageCaptionSaveTarget(", 1)[0]
        # Substitute external boundaries only. Preserve production branches,
        # result codes, ordering and return paths. No real clipboard or input.
        action = action.replace('WinExist("A")', "CaptionTestForeground()")
        action = action.replace("MouseGetPos &originalX, &originalY", "originalX := 0, originalY := 0")
        action = action.replace("MouseClick(", "CaptionTestClick(")
        action = action.replace("MouseMove originalX, originalY, 0", "CaptionTestMove(originalX, originalY, 0)")
        action = action.replace("MouseMove(", "CaptionTestMove(")
        action = action.replace('SendInput "^a"', 'CaptionTestSend("^a")')
        action = action.replace('SendInput "^v"', 'CaptionTestSend("^v")')
        action = action.replace('SendInput "{WheelDown}"', 'CaptionTestSend("wheel")')
        result_function = "MakeReportImageCaptionResult(" + source.split(
            "\nMakeReportImageCaptionResult(", 1)[1].split("\nReportImageCaptionFailureMessage(", 1)[0]
        self.run_ahk('''
RunCaptionSaveTimingActionTest()
RunCaptionSaveTimingActionTest() {
    global CaptionScenario, CaptionEvents, CaptionPasteTick
    try {
        target := {hwnd: 1001, pid: 101, captionPoint: {x: 1, y: 1},
            savePoint: {x: 2, y: 2}, imagePoint: {x: 3, y: 3}}
        for scenario in ["FINAL_DISABLED", "FINAL_AMBIGUOUS", "READY", "READY"] {
            CaptionScenario := scenario
            CaptionEvents := []
            ReportImageCaptionAdvanceGate.LastAdvanceTicks := Map()
            result := ExecuteReportImageCaptionAction({payload: "SYNTHETIC"}, target, 1001, 0)
            observed := ""
            for event in CaptionEvents
                observed .= event ">"
            if scenario = "READY" {
                if !result.ok || observed != "click1>^a>^v>click2>move3>wheel>move0>"
                    throw Error("Single save/advance sequence changed: " observed)
            } else {
                if result.ok || result.code != ReportImageCaptionCode.SAVE_NOT_READY
                    throw Error("Readiness failure was reported as success")
                if !result.pasteDispatched || observed != "click1>^a>^v>move0>"
                    throw Error("Save or advance escaped failed gate: " observed)
            }
        }
        FileAppend("PASS`n", "*")
        ExitApp(0)
    } catch as captionTestError {
        FileAppend(captionTestError.Message, "**")
        ExitApp(1)
    }
}
CaptionTestForeground() => 1001
Win32WindowPid(hwnd) => 101
ReportImageCaptionPointBelongsToTarget(hwnd, point) => true
SetReportImageCaptionClipboard(payload) => true
ReportImageCaptionFeedbackOrigin(cache, x, y) => 0
ShowReportImageCaptionTransferFeedback(origin, destination) => true
ValidateReportImageCaptionSaveTarget(target) {
    global CaptionScenario, CaptionPasteTick
    if A_TickCount - CaptionPasteTick < 235
        throw Error("Paste-to-save wait was too short")
    return {ok: CaptionScenario = "READY", code: "TEST_SAVE_TARGET"}
}
CaptionTestClick(which, x, *) {
    global CaptionEvents
    CaptionEvents.Push("click" x)
}
CaptionTestMove(x, *) {
    global CaptionEvents
    CaptionEvents.Push("move" x)
}
CaptionTestSend(keys) {
    global CaptionEvents, CaptionPasteTick
    if keys = "^v"
        CaptionPasteTick := A_TickCount
    CaptionEvents.Push(keys)
}
''' + definitions + "\n" + action + "\n" + result_function)

    def test_generated_viewer_state_harness(self):
        # Synthetic windows only; this harness never interacts with MedEx.
        import subprocess
        result = subprocess.run(
            [maintenance.ahk_executable(), "/ErrorStdOut",
             str(ROOT / "tests/windows/generated/viewer_state_regression_standalone.ahk")],
            capture_output=True, timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        self.assertEqual(result.returncode, 0, (result.stdout + result.stderr).decode("utf-8", errors="replace"))
        self.assertIn(b"Viewer state regression: PASS", result.stdout)

    def test_save_target_checks_live_button_identity_and_native_ownership(self):
        source = (ROOT / "src/report_image_caption.ahk").read_text(encoding="utf-8")
        probes = "ValidateReportImageCaptionSaveTarget(target) {" + source.split(
            "\nValidateReportImageCaptionSaveTarget(target) {", 1)[1].split(
                "\nSetReportImageCaptionClipboard(payload) {", 1)[0]
        # Keep the test panel nonactivating; only foreground observation is
        # substituted. Identity, enabled state, native point ownership is real.
        probes = probes.replace('WinExist("A")', "CaptionPanelForeground()")
        geometry = "ReportImageCaptionElementUsable(element, expectedPid) {" + source.split(
            "\nReportImageCaptionElementUsable(element, expectedPid) {", 1)[1].split(
                "\nReportImageCaptionRectWidth(rect) {", 1)[0]
        includes = f'#Include {ROOT / "src/Lib/UIA.ahk"}\n#Include {ROOT / "src/core/win32_window.ahk"}\n'
        self.run_ahk(includes + '''
RunCaptionPanelTest()
RunCaptionPanelTest() {
    global CaptionPanelHwnd
    panel := Gui("+AlwaysOnTop +ToolWindow")
    try {
        button := panel.Add("Button", "x10 y10 w100 h30", "保存")
        panel.Show("NoActivate x20 y20 w230 h70")
        CaptionPanelHwnd := panel.Hwnd
        root := UIA.ElementFromHandle(panel.Hwnd, , false)
        elements := root.FindElements({Type: "Button", Name: "保存"})
        if elements.Length != 1
            throw Error("Synthetic save button missing")
        rect := ReportImageCaptionElementRect(elements[1])
        target := {hwnd: panel.Hwnd, pid: DllCall("GetCurrentProcessId", "UInt"),
            saveAnchor: {element: elements[1], rectKey: RectKey(rect)},
            savePoint: {x: (rect.l + rect.r) // 2, y: (rect.t + rect.b) // 2}}
        if !ValidateReportImageCaptionSaveTarget(target).ok
            throw Error("Unique enabled save button not recognized")
        button.Enabled := false
        disabled := ValidateReportImageCaptionSaveTarget(target)
        if disabled.ok || disabled.code != "SAVE_BUTTON_UNAVAILABLE"
            throw Error("Disabled button accepted or treated as ambiguous")
        button.Enabled := true
        target.savePoint.x := rect.r + 10
        if ValidateReportImageCaptionSaveTarget(target).ok
            throw Error("Point outside button accepted")
        target.savePoint.x := (rect.l + rect.r) // 2
        panel.Add("Button", "x120 y10 w100 h30", "保存")
        duplicate := ValidateReportImageCaptionSaveTarget(target)
        if duplicate.ok || duplicate.code != "SAVE_BUTTON_NOT_UNIQUE"
            throw Error("Duplicate save button did not stop immediately")
        panel.Destroy()
        FileAppend("PASS`n", "*")
        ExitApp(0)
    } catch as panelTestError {
        panel.Destroy()
        FileAppend(panelTestError.Message, "**")
        ExitApp(1)
    }
}
CaptionPanelForeground() {
    global CaptionPanelHwnd
    return CaptionPanelHwnd
}
ReportImageCaptionUiaRoot(hwnd) => UIA.ElementFromHandle(hwnd, , false)
''' + probes + geometry)


if __name__ == "__main__":
    unittest.main()
