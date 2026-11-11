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

    def test_hotstring_clipboard_commits_only_after_full_success(self):
        source = (ROOT / "src/hotstrings.ahk").read_text(encoding="utf-8")
        entry = source[source.index("RunConfiguredReportHotstring(entry, *) {"):
                       source.index("RunObservedReportHotstring(entry, operation) {")]
        entry = entry.replace("ClipboardAll()", "SaveTestClipboard()")
        entry = entry.replace(
            'A_Clipboard := StrReplace(text, "`n", "`r`n")',
            'WriteTestClipboard(StrReplace(text, "`n", "`r`n"))',
        ).replace("A_Clipboard := savedClipboard", "WriteTestClipboard(savedClipboard)")
        self.assertNotIn("A_Clipboard", entry)
        self.assertNotIn("ClipboardAll()", entry)
        self.run_ahk(r'''
try {
    text := "第一行`n{{date}}"
    RunCase("COMPLETED", "", "", "OK", 0, 0, "original")
    RunCase("FAILED", text, "", "TEST_OUTCOME", 0, 0, "original")
    RunCase("DEGRADED", text, "", "TEST_OUTCOME", 0, 0, "original")
    RunCase("COMPLETED", text, "", "OK", 1, 1, "第一行`r`n{{date}}")
    RunCase("COMPLETED", text, "save", "CLIPBOARD_SAVE_FAILED", 1, 0, "original")
    RunCase("COMPLETED", text, "write", "CLIPBOARD_WRITE_FAILED", 1, 2, "original")
    RunCase("COMPLETED", text, "restore", "CLIPBOARD_RESTORE_FAILED", 1, 2,
        "partial write")
    FileAppend("PASS`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend(err.Message, "**")
    ExitApp(1)
}

RunCase(status, text, failure, expectedCode, saves, writes, expectedClipboard) {
    global testState := {status: status, failure: failure, clipboard: "original",
        saves: 0, writes: 0, bodyRuns: 0, completion: "", feedback: 0}
    oldCritical := A_IsCritical
    result := RunConfiguredReportHotstring({ClipboardText: text})
    expectedStatus := failure = "" ? status : "DEGRADED"
    if testState.bodyRuns != 1 || testState.saves != saves || testState.writes != writes
        || testState.clipboard !== expectedClipboard || result != (status != "FAILED")
        || testState.completion != expectedStatus ":" expectedCode
        || testState.feedback != (failure != "") || A_IsCritical != oldCritical
        throw Error("Hotstring clipboard case failed: " status "/" failure)
}

RunObservedReportHotstring(entry, operation) {
    testState.bodyRuns += 1
    return ReportHotstringOutcome(testState.status != "FAILED", testState.status,
        testState.status = "COMPLETED" ? "OK" : "TEST_OUTCOME")
}

SaveTestClipboard() {
    testState.saves += 1
    if testState.bodyRuns != 1 || testState.failure = "save"
        throw Error("Synthetic clipboard snapshot failed")
    return testState.clipboard
}

WriteTestClipboard(value) {
    testState.writes += 1
    if testState.failure != "" && testState.writes = 1 {
        testState.clipboard := "partial write"
        throw Error("Synthetic clipboard write failed")
    }
    if testState.failure = "restore"
        throw Error("Synthetic clipboard restore failed")
    testState.clipboard := value
}

BeginAutomationDiagnosticOperation(*) {
    return {Complete: (self, status, code) => testState.completion := status ":" code}
}

ShowReportAssistantVisualFeedback(*) {
    testState.feedback += 1
}
''' + entry)
