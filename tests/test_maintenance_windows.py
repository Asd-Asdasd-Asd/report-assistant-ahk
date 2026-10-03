"""Execute isolated AHK maintenance regressions; never load the application.

Only the notification boundary is stubbed. Hotkeys are registered under a
false context, and no keys, clipboard, MedEx windows or user config are used.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def ahk_executable():
    candidates = [
        os.environ.get("AUTOHOTKEY_EXE", ""),
        shutil.which("AutoHotkey64.exe") or "",
        str(Path(os.environ.get("ProgramFiles", "C:/Program Files"))
            / "AutoHotkey/v2/AutoHotkey64.exe"),
    ]
    return next((path for path in candidates if path and Path(path).is_file()), None)


@unittest.skipUnless(os.name == "nt" and ahk_executable(), "requires Windows and AutoHotkey v2")
class MaintenanceWindowsTests(unittest.TestCase):
    def run_ahk(self, code):
        with tempfile.TemporaryDirectory(prefix="medex-maintenance-test-") as directory:
            script = Path(directory) / "test.ahk"
            script.write_text(
                '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#Warn All, StdOut\n' + code,
                encoding="utf-8-sig",
            )
            result = subprocess.run(
                [ahk_executable(), "/ErrorStdOut", str(script)],
                capture_output=True, timeout=15,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            self.assertEqual(result.returncode, 0, (result.stdout + result.stderr).decode("utf-8", errors="replace"))
            self.assertEqual(result.stdout.strip(), b"PASS")

    def test_hotkey_names_and_registration_failure_isolation(self):
        normalization = (ROOT / "src/feature_normalization.ahk").read_text(encoding="utf-8")
        key_functions = normalization.split("ViewerToolHotkeyChordIsSafe(chord) {", 1)[1].split(
            "ViewerHotkeyChordIsBare(chord) {", 1)[0]
        key_functions = "ViewerToolHotkeyChordIsSafe(chord) {" + key_functions
        registration = (ROOT / "src/hotkey_registration.ahk").read_text(encoding="utf-8")
        start = registration.index("\nReportHotkeyRegistrationFailures(chords) {")
        end = registration.index("\nBuildHotkeyChordSet(", start)
        registration = registration[:start] + registration[end:]
        self.run_ahk(r'''
global ObservedFailures := []
try {
    for testChord in ["^p", "+!s", "^!1", "#1", "s", "7", "^F12", "^WheelDown", "^XButton1", "^vkFF", "^sc123", "^vkFFsc123", "^Browser_Back", "^;"] {
        if !ViewerToolHotkeyChordIsSafe(testChord)
            throw Error("Valid chord rejected: " testChord)
    }
    for testChord in ["", "^", "F7", "^F999", "^UnknownKey", "^p q"] {
        if ViewerToolHotkeyChordIsSafe(testChord)
            throw Error("Invalid chord accepted: " testChord)
    }
    definitions := [
        {Id: "first", Chord: "^!F23", Handler: (*) => 0},
        {Id: "bad", Chord: "^F999", Handler: (*) => 0},
        {Id: "last", Chord: "^!F24", Handler: (*) => 0}
    ]
    registered := RegisterHotkeyDefinitions(definitions, [], (*) => false)
    if registered.Length != 2 || registered[1] != "first" || registered[2] != "last"
        throw Error("One failure prevented valid hotkey registration")
    if ObservedFailures.Length != 1 || ObservedFailures[1] != "^F999"
        throw Error("Registration failure was not reported")
    FileAppend("PASS`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend(err.Message, "**")
    ExitApp(1)
}
ReportHotkeyRegistrationFailures(chords) {
    global ObservedFailures
    ObservedFailures := chords
}
''' + key_functions + registration)

    def test_failed_config_startup_does_not_load_or_register_templates(self):
        entry = (ROOT / "src/hotstrings.ahk").read_text(encoding="utf-8").split(
            "class ReportTemplateWriteCode", 1)[0]
        self.run_ahk('''
global LoadCount := 0, RegistrationCount := 0
for startupOk in [false, true] {
    ReportAssistantConfigStartupResult := {Ok: startupOk}
''' + entry + '''
    if LoadCount != (startupOk ? 1 : 0) || RegistrationCount != LoadCount {
        FileAppend("Configuration startup gate failed", "**")
        ExitApp(1)
    }
}
FileAppend("PASS`n", "*")
ExitApp(0)
LoadReportHotstringConfig() {
    global LoadCount
    LoadCount += 1
    return []
}
RegisterReportHotstrings(entries, executor) {
    global RegistrationCount
    RegistrationCount += 1
}
RunConfiguredReportHotstring(*) {
}
''')
