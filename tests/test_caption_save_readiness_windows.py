"""Run Caption save/advance decisions in AHK with external input boundaries stubbed."""
import os
from pathlib import Path
import unittest

import test_maintenance_windows as maintenance

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt" and maintenance.ahk_executable(), "requires Windows and AutoHotkey v2")
class CaptionSaveReadinessWindowsTests(unittest.TestCase):
    run_ahk = maintenance.MaintenanceWindowsTests.run_ahk

    def test_actual_action_never_saves_or_advances_after_readiness_failure(self):
        source = (ROOT / "src/report_image_caption.ahk").read_text(encoding="utf-8")
        definitions = source.split("\nReportImageCaptionHotkeyDefinitions(", 1)[0]
        action = "ExecuteReportImageCaptionAction(" + source.split(
            "\nExecuteReportImageCaptionAction(", 1)[1].split(
                "\n; Per-paste policy;", 1)[0]
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
RunCaptionReadinessActionTest()
RunCaptionReadinessActionTest() {
    global CaptionScenario, CaptionEvents
    try {
        target := {hwnd: 1001, pid: 101, captionPoint: {x: 1, y: 1},
            savePoint: {x: 2, y: 2}, imagePoint: {x: 3, y: 3}}
        for scenario in ["TIMEOUT", "FINAL_DISABLED", "FINAL_AMBIGUOUS", "READY"] {
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
WaitForReportImageCaptionSaveReady(target) {
    global CaptionScenario
    return {ok: CaptionScenario != "TIMEOUT", code: "TEST_READY", elapsedMs: 80, sampleCount: 3}
}
ResolveReportImageCaptionSaveButton(target) {
    global CaptionScenario
    return {ok: CaptionScenario != "FINAL_AMBIGUOUS", code: "TEST_UNIQUE", button: {}}
}
ProbeReportImageCaptionSaveButton(target, button) {
    global CaptionScenario
    return {ok: CaptionScenario != "FINAL_DISABLED", code: "TEST_ENABLED"}
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
    global CaptionEvents
    CaptionEvents.Push(keys)
}
''' + definitions + "\n" + action + "\n" + result_function)

    def test_save_readiness_policy_in_generated_windows_harness(self):
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

    def test_live_uia_save_button_disabled_duplicate_and_hit_checks(self):
        source = (ROOT / "src/report_image_caption.ahk").read_text(encoding="utf-8")
        probes = "ResolveReportImageCaptionSaveButton(target) {" + source.split(
            "\nResolveReportImageCaptionSaveButton(target) {", 1)[1].split(
                "\nSetReportImageCaptionClipboard(payload) {", 1)[0]
        # Keep the test panel nonactivating; only foreground observation is
        # substituted. Identity, enabled state, native/UIA hit tests are real.
        probes = probes.replace('WinExist("A")', "CaptionPanelForeground()")
        geometry = "ReportImageCaptionElementRect(element) {" + source.split(
            "\nReportImageCaptionElementRect(element) {", 1)[1].split(
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
        resolved := ResolveReportImageCaptionSaveButton(target)
        if !resolved.ok || !ProbeReportImageCaptionSaveButton(target, resolved.button).ok
            throw Error("Unique enabled save button not recognized")
        button.Enabled := false
        disabled := ProbeReportImageCaptionSaveButton(target, resolved.button)
        if disabled.ok || !disabled.waitable || disabled.code != "SAVE_BUTTON_DISABLED"
            throw Error("Disabled button accepted or treated as ambiguous")
        button.Enabled := true
        target.savePoint.x := rect.r + 10
        if ProbeReportImageCaptionSaveButton(target, resolved.button).ok
            throw Error("Point outside button accepted")
        panel.Add("Button", "x120 y10 w100 h30", "保存")
        duplicate := ResolveReportImageCaptionSaveButton(target)
        if duplicate.ok || duplicate.waitable || duplicate.code != "SAVE_BUTTON_NOT_UNIQUE"
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
