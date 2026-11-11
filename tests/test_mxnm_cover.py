"""Cover workflow regressions: production AHK decisions, no live Viewer input."""
import os
from pathlib import Path
import unittest

import test_maintenance_windows as maintenance

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt" and maintenance.ahk_executable(), "requires Windows and AutoHotkey v2")
class CoverWindowsTests(unittest.TestCase):
    run_ahk = maintenance.MaintenanceWindowsTests.run_ahk

    def test_complete_release_parses_without_starting_application(self):
        from scripts.build_release import build_release_text

        release = build_release_text(timestamp="syntax-test")
        self.run_ahk('FileAppend("PASS`n", "*")\nExitApp(0)\n' + release
                     + '\n#Warn All, StdOut\n')

    def test_settings_window_stores_two_independent_layouts_without_overlap(self):
        from scripts.build_release import build_release_text

        body = '''
RunSettingsLayoutTest()
RunSettingsLayoutTest() {
    try {
        testConfig := A_ScriptDir "\\settings-layout.ini"
        FileAppend(BuildDefaultReportHotstringConfig(), testConfig, "UTF-16")
        load := LoadEditableReportHotstringConfig(testConfig)
        if !load.Ok
            throw Error("Could not load isolated settings fixture")
        controller := ReportAssistantSettingsWindow(load)
        controller.Window.Show("Hide w800 h660")
        controller.Tabs.Choose(2)
        inputs := [controller.MontageBodyChordInput, controller.MontageHeadChordInput,
            controller.MontageLungChordInput, controller.CoverChordInput,
            controller.MontageLayoutRowInput, controller.MontageLayoutColumnInput,
            controller.CoverLayoutRowInput, controller.CoverLayoutColumnInput]
        for record in controller.HelpButtons {
            definition := ReportAssistantSettingsDefaults.HelpTopic(record.Topic)
            helpMenu := controller.BuildHelpMenu(record.Topic)
            itemCount := DllCall("User32\\GetMenuItemCount", "Ptr", helpMenu.Handle, "Int")
            if itemCount != definition.Lines.Length + 2
                throw Error("Help menu lost a heading, separator or explanation")
            record.Control.GetPos(&hx, &hy, &hw, &hh)
            if hw != 18 || hh != 18 || hx < 28 || hx + hw > 772 || hy < 48 || hy + hh > 594
                throw Error("Help icon size or bounds incorrect")
        }
        if controller.Dirty
            throw Error("Building help menus changed settings")
        for index, input in inputs {
            input.GetPos(&x, &y, &w, &h)
            if y < 80 || y + 26 > 594 || x < 28 || x + w > 772
                throw Error("Shortcut input escapes tab content")
            for otherIndex, other in inputs {
                if otherIndex <= index
                    continue
                other.GetPos(&ox, &oy, &ow, &oh)
                if x < ox + ow && x + w > ox && y < oy + 26 && y + 26 > oy
                    throw Error("Shortcut/layout inputs overlap")
            }
        }
        controller.MontageLayoutRowInput.Choose(4)
        controller.MontageLayoutColumnInput.Choose(4)
        controller.CoverLayoutRowInput.Choose(2)
        controller.CoverLayoutColumnInput.Choose(3)
        controller.StoreMontageHotkeyControls()
        WriteMxNMMontageSettings(testConfig, controller.MontageSettings)
        reloaded := LoadMxNMMontageSettings(testConfig)
        if reloaded.layoutRow != 4 || reloaded.layoutColumn != 4
            || reloaded.coverLayoutRow != 2 || reloaded.coverLayoutColumn != 3
            throw Error("Settings UI mixed up independent layouts")
        controller.Window.Destroy()
        FileAppend("PASS`n", "*")
        ExitApp(0)
    } catch as testError {
        FileAppend(testError.Message, "**")
        ExitApp(1)
    }
}
'''
        self.run_ahk(body + build_release_text(timestamp="settings-layout-test")
                     + '\n#Warn All, StdOut\n')

    def run_cover(self, body):
        # Include definitions only. No app startup, hotkey registration, Viewer
        # commands, clipboard capture or report persistence is executed.
        includes = "\n".join(
            f'#Include {ROOT / path}' for path in (
                "src/app_config.ahk", "src/core/win32_window.ahk", "src/mxnm_montage.ahk",
                "src/mxnm_cover.ahk", "src/mxnm_context_target_session.ahk", "src/hotkey_registration.ahk",
                "src/feature_model.ahk", "src/feature_normalization.ahk",
                "src/hotstring_config_editor.ahk",
            )
        )
        # Modules also contain unused live transports; their dependencies are
        # intentionally not loaded. Runtime errors in exercised code still fail.
        self.run_ahk('#Warn All, Off\n' + includes + '\nRunCoverTest()\nRunCoverTest() {\ntry {\n' + body + '''
    FileAppend("PASS`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend(err.Message, "**")
    ExitApp(1)
}
}
class FakeCoverTransport {
    __New(failAt := "") {
        this.FailAt := failAt
        this.Calls := []
    }
    Execute(step, session) {
        this.Calls.Push(step)
        return {ok: step != this.FailAt, code: step = this.FailAt ? "TEST_STOP" : "READY"}
    }
}
CoverCandidate(hwnd, parent, className, left, top, right, bottom) {
    return {hwnd: hwnd, parent: parent, className: className,
        width: right - left, height: bottom - top, rect: {left: left, top: top, right: right, bottom: bottom}}
}
''')

    def test_order_and_every_failure_stop_without_replay(self):
        self.run_cover('''
    expected := ["PREFLIGHT", "SELECT_LAYOUT", "ANNOTATION_TAB", "CAPTION_DEFAULT",
        "BIND_SURFACE", "SELECT_MIP", "SAVE_LEFT", "SELECT_FUSION", "RESET_DEFAULT", "SAVE_RIGHT"]
    success := FakeCoverTransport()
    result := MxNMCoverRun({}, success)
    if !result.ok || success.Calls.Length != expected.Length
        throw Error("Successful sequence incomplete")
    for index, step in expected {
        if success.Calls[index] != step
            throw Error("Wrong export order")
        transport := FakeCoverTransport(step)
        result := MxNMCoverRun({}, transport)
        if result.ok || result.code != "TEST_STOP" || result.stage != step
            throw Error("Failure was not propagated")
        if transport.Calls.Length != index
            throw Error("Workflow continued or retried after failure")
        if result.leftSaveDispatched != (index > 7)
            throw Error("Partial left-save status lost")
    }
    if !MxNMViewerWorkflowLock.Acquire() || MxNMViewerWorkflowLock.Acquire()
        throw Error("Workflow lock admitted concurrent operation")
    MxNMViewerWorkflowLock.Release()
    if !MxNMViewerWorkflowLock.Acquire()
        throw Error("Workflow lock was not released")
    MxNMViewerWorkflowLock.Release()
''')

    def test_layout_semantics_and_ambiguous_surface_rejected(self):
        self.run_cover('''
    panes := []
    loop 4 {
        index := A_Index
        panes.Push(Map("Left", Mod(index - 1, 2) * 375, "Top", (index > 2 ? 472 : 0),
            "Width", 375, "Height", 472, "ImageType", [1, 2, 3, 1][index],
            "ImageOrient", 2, "ImageOrigin", index = 4 ? 2 : 1))
    }
    if !MxNMCoverFourPaneProfileMatches(panes)
        throw Error("Supported four-pane layout rejected")
    panes[4]["ImageOrigin"] := 1
    if MxNMCoverFourPaneProfileMatches(panes)
        throw Error("Non-MIP lower-right accepted")
    panes[4]["ImageOrigin"] := 2
    panes[3]["ImageType"] := 2
    if MxNMCoverFourPaneProfileMatches(panes)
        throw Error("Non-fusion lower-left accepted")
    root := {left: 1920, top: 0, right: 4481, bottom: 1440}
    palette := {left: 1930, top: 100, right: 2150, bottom: 375}
    identity := {rootHwnd: 11}
    match := (pane, point) => true
    canvas := CoverCandidate(22, 11, "#32770", 2180, 80, 2910, 920)
    result := MxNMCoverChooseSurface([canvas], root, palette, identity, match)
    if !result.ok || result.hwnd != 22
        throw Error("Unique canvas rejected under former root-relative size thresholds")
    if result.mode != "SHARED_CANVAS" || MxNMCoverPaneCenter(result.panes[4]).x != 2727
        throw Error("Shared canvas resolved the wrong lower-right point")
    if MxNMCoverChooseSurface([], root, palette, identity, match).ok
        throw Error("Missing canvas accepted")
    second := CoverCandidate(33, 11, "#32770", 3000, 80, 3750, 920)
    if MxNMCoverChooseSurface([canvas, second], root, palette, identity, match).code != "COVER_SURFACE_NOT_UNIQUE"
        throw Error("Ambiguous canvas accepted")
    blocked := MxNMCoverChooseSurface([canvas], root, palette, identity, (pane, point) => point.y < 500)
    if blocked.ok || blocked.code != "COVER_PANE_POINT_MISMATCH"
        throw Error("Canvas with an obscured lower pane accepted")
''')

    def test_live_geometry_orders_independent_panes_and_deduplicates_their_canvas(self):
        self.run_cover('''
    root := {left: -1600, top: 0, right: 0, bottom: 1000}
    palette := {left: -1590, top: 100, right: -1380, bottom: 370}
    identity := {rootHwnd: 11}
    canvas := CoverCandidate(22, 11, "#32770", -1360, 50, -160, 990)
    tl := CoverCandidate(31, 22, "DrawingView", -1360, 50, -762, 518)
    tr := CoverCandidate(32, 22, "DrawingView", -758, 50, -160, 518)
    bl := CoverCandidate(33, 22, "DrawingView", -1360, 522, -762, 990)
    br := CoverCandidate(34, 22, "DrawingView", -758, 522, -160, 990)
    match := (pane, point) => true
    for candidates in [[br, tl, bl, tr], [br, canvas, tl, bl, tr]] {
        result := MxNMCoverChooseSurface(candidates, root, palette, identity, match)
        if !result.ok || result.mode != "PANE_WINDOWS" || result.panes[3].hwnd != 33 || result.panes[4].hwnd != 34
            throw Error("Wrong lower pane mapping or duplicate shared canvas")
    }
    br.rect.top := 620
    if MxNMCoverChooseSurface([br, tl, bl, tr], root, palette, identity, match).ok
        throw Error("Unequal grid accepted")
''')

    def test_settings_round_trip_and_cross_feature_conflicts(self):
        self.run_cover('''
    configPath := A_ScriptDir "\\cover-test.ini"
    FileAppend("[Config]`nSchemaVersion=2`n", configPath, "UTF-16")
    settings := LoadMxNMMontageSettings(configPath)
    if !settings.ok || settings.coverEnabled || settings.coverChord != "^#+c"
        throw Error("Cover defaults incorrect")
    if settings.coverLayoutRow != 2 || settings.coverLayoutColumn != 3
        throw Error("Cover layout defaults incorrect")
    settings.coverEnabled := true
    settings.coverChord := "^#+v"
    settings.coverLayoutRow := 3
    settings.coverLayoutColumn := 1
    WriteMxNMMontageSettings(configPath, settings)
    reloaded := LoadMxNMMontageSettings(configPath)
    if !MxNMMontageSettingsMatch(settings, reloaded)
        throw Error("Cover settings did not survive save")
    if reloaded.layoutRow != 4 || reloaded.layoutColumn != 4
        throw Error("Cover layout replaced Montage layout")
    if !ValidateMxNMMontageSettings(settings).Ok
        throw Error("Cover-only mode requires Montage enabled")
    settings.coverChord := "^!q"
    if ValidateMxNMMontageSettings(settings).Ok
        throw Error("Reserved hotkey accepted")
    settings.enabled := true
    settings.coverChord := settings.chords["body"]
    if ValidateMxNMMontageSettings(settings).Ok
        throw Error("Cover-Montage hotkey collision accepted")
''')


    def test_owned_surface_can_reach_window_border_but_not_escape_frame(self):
        self.run_cover('''
    outer := {left: 1920, top: 0, right: 4481, bottom: 1440}
    client := {left: 1921, top: 1, right: 4480, bottom: 1439}
    canvas := CoverCandidate(22, 11, "#32770", 2566, 80, 3991, 1440)
    palette := {left: 1940, top: 100, right: 2200, bottom: 375}
    identity := {rootHwnd: 11}
    match := (pane, point) => true
    if MxNMCoverChooseSurface([canvas], client, palette, identity, match).candidateCount != 0
        throw Error("Regression fixture no longer reproduces inset-client rejection")
    result := MxNMCoverChooseSurface([canvas], outer, palette, identity, match)
    if !result.ok || result.candidateCount != 1
        throw Error("Owned canvas touching outer border rejected")
    canvas.rect.bottom := 1441
    if MxNMCoverChooseSurface([canvas], outer, palette, identity, match).ok
        throw Error("Canvas outside actual frame accepted")
''')

    def test_configured_cover_layout_validates_its_own_model_before_input(self):
        self.run_cover('''
    configPath := A_ScriptDir "\\layout-profiles.ini"
    IniWrite("4", configPath, "ShowModel9", "LowWndSize")
    IniWrite("0", configPath, "ShowModel9", "ShowModelPage")
    loop 4 {
        index := A_Index
        pane := Map("Left", Mod(index - 1, 2) * 375, "Top", index > 2 ? 472 : 0,
            "Width", 375, "Height", 472, "ImageType", [1, 2, 3, 1][index],
            "ImageOrient", 2, "ImageOrigin", index = 4 ? 2 : 1)
        for name, value in pane
            IniWrite(value, configPath, "ShowModel9", "LowWnd" name "_" index)
    }
    if !MxNMCoverLayoutSupported(configPath, 3, 1)
        throw Error("Configured model was not used")
    if MxNMCoverLayoutSupported(configPath, 2, 3)
        throw Error("Missing configured model fell back to another model")
    if MxNMCoverLayoutSupported(configPath, 6, 1)
        throw Error("Out-of-range layout accepted")
    IniWrite("2", configPath, "ShowModel9", "LowWndImageType_3")
    if MxNMCoverLayoutSupported(configPath, 3, 1)
        throw Error("Non-fusion layout accepted")
''')


class CoverIntegrationTests(unittest.TestCase):
    def test_cover_uses_montage_transports_and_owns_no_raw_screen_coordinates(self):
        text = (ROOT / "src/mxnm_cover.ahk").read_text(encoding="utf-8")
        for required in ("MxNMMontageLayoutPoint(session.coverLayoutRow, session.coverLayoutColumn)", "MxNMMontageComboSelect(21155, \"default\", session)",
                         "MxNMMontageResolveControl", "ClipboardAll()", "A_Clipboard := payload",
                         "COVER_SURFACE_NOT_UNIQUE", '"SAVE_COMMANDS_DISPATCHED"'):
            self.assertIn(required, text)
        for forbidden in ("3637", "2935", "MouseClick", "Send ", '"null"', "MxNMMontageRun("):
            self.assertNotIn(forbidden, text)
        self.assertIn('"mxnm_cover.ahk"', (ROOT / "scripts/build_release.py").read_text(encoding="utf-8"))
        resolver = text.split("\nMxNMCoverResolveSurface(session) {", 1)[1].split("\nMxNMCoverChooseSurface(", 1)[0]
        self.assertIn("Win32WindowRect(session.viewerRootOwner)", resolver)
        self.assertNotIn("Win32ClientRectScreen(session.viewerRootOwner)", resolver)


if __name__ == "__main__":
    unittest.main()
