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

    def run_cover(self, body):
        # Include definitions only. No app startup, hotkey registration, Viewer
        # commands, clipboard capture or report persistence is executed.
        includes = "\n".join(
            f'#Include {ROOT / path}' for path in (
                "src/app_config.ahk", "src/core/win32_window.ahk", "src/mxnm_montage.ahk",
                "src/mxnm_cover.ahk", "src/hotkey_registration.ahk",
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
''')

    def test_order_and_every_failure_stop_without_replay(self):
        self.run_cover('''
    expected := ["PREFLIGHT", "LAYOUT_R2C3", "ANNOTATION_TAB", "CAPTION_DEFAULT",
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
    canvas := {hwnd: 22, className: "#32770", width: 1425, height: 1360,
        rect: {left: 2566, top: 80, right: 3991, bottom: 1440}}
    result := MxNMCoverChooseSurface([canvas], root, 11)
    if !result.ok || result.hwnd != 22
        throw Error("Unique inner canvas rejected")
    if MxNMCoverChooseSurface([], root, 11).ok
        throw Error("Missing canvas accepted")
    if MxNMCoverChooseSurface([canvas, canvas.Clone()], root, 11).ok
        throw Error("Ambiguous canvas accepted")
    canvas.rect.left := 1000
    if MxNMCoverChooseSurface([canvas], root, 11).ok
        throw Error("Canvas outside root accepted")
''')

    def test_settings_round_trip_and_cross_feature_conflicts(self):
        self.run_cover('''
    configPath := A_ScriptDir "\\cover-test.ini"
    FileAppend("[Config]`nSchemaVersion=2`n", configPath, "UTF-16")
    settings := LoadMxNMMontageSettings(configPath)
    if !settings.ok || settings.coverEnabled || settings.coverChord != "^#+c"
        throw Error("Cover defaults incorrect")
    settings.coverEnabled := true
    settings.coverChord := "^#+v"
    WriteMxNMMontageSettings(configPath, settings)
    reloaded := LoadMxNMMontageSettings(configPath)
    if !MxNMMontageSettingsMatch(settings, reloaded)
        throw Error("Cover settings did not survive save")
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


class CoverIntegrationTests(unittest.TestCase):
    def test_cover_uses_montage_transports_and_owns_no_raw_screen_coordinates(self):
        text = (ROOT / "src/mxnm_cover.ahk").read_text(encoding="utf-8")
        for required in ("MxNMMontageLayoutPoint(2, 3)", "MxNMMontageComboSelect(21155, \"default\", session)",
                         "MxNMMontageResolveControl", "ClipboardAll()", "A_Clipboard := payload",
                         "COVER_SURFACE_NOT_UNIQUE", '"SAVE_COMMANDS_DISPATCHED"'):
            self.assertIn(required, text)
        for forbidden in ("3637", "2935", "MouseClick", "Send ", '"null"', "MxNMMontageRun("):
            self.assertNotIn(forbidden, text)
        self.assertIn('"mxnm_cover.ahk"', (ROOT / "scripts/build_release.py").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
