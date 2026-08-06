#!/usr/bin/env python3
"""Static safety checks for the Viewer context-menu diagnostic."""

from __future__ import annotations

import unittest
from pathlib import Path

from scripts.build_mxnm_context_menu_diagnostic import (
    DIRECTIVES,
    OUTPUT,
    build_diagnostic_text,
)


ROOT = Path(__file__).resolve().parents[1]
HARNESS = (
    ROOT / "tests" / "windows" / "mxnm_context_menu_receiver_diagnostic.ahk"
)
POWERSHELL = ROOT / "scripts" / "build_viewer_context_diagnostic_exe.ps1"
CMD = (
    ROOT
    / "tools"
    / "field-testing"
    / "Build Viewer Context Diagnostic EXE.cmd"
)


class MxNMContextMenuDiagnosticBuildTests(unittest.TestCase):
    def test_generated_diagnostic_matches_sources(self) -> None:
        self.assertEqual(
            OUTPUT.read_text(encoding="utf-8"),
            build_diagnostic_text(),
        )

    def test_diagnostic_is_single_file_and_never_invokes_command(self) -> None:
        generated = OUTPUT.read_text(encoding="utf-8")
        self.assertNotIn("#Include", generated)
        self.assertIn(
            "InteractionMode=NON_DESTRUCTIVE_POPUP_PROBE",
            generated,
        )
        self.assertIn("CommandDispatch=DISABLED", generated)
        self.assertIn("A_Clipboard := report", generated)
        self.assertIn('"User32\\PostMessageW"', generated)
        self.assertIn('"UInt", 0x0204', generated)
        self.assertIn('"UInt", 0x0205', generated)
        self.assertIn('"UInt", 0x0010', generated)
        self.assertNotIn(
            "InvokePreparedMxNMContextCommand(",
            generated,
        )
        self.assertNotIn('"UInt", 0x0111', generated)
        self.assertNotIn('"User32\\SendMessageW"', generated)
        for directive in DIRECTIVES:
            self.assertEqual(generated.count(directive), 1)

    def test_probe_is_bounded_and_identity_checked(self) -> None:
        harness = HARNESS.read_text(encoding="utf-8")
        self.assertIn("probeLimit := Min(24, candidates.Length)", harness)
        self.assertIn("deadline := A_TickCount + 600", harness)
        self.assertIn("pid != expectedPid", harness)
        self.assertIn("ownerMatches: rootOwner = expectedOwner", harness)
        self.assertIn("RawWindowTextCaptured=false", harness)
        self.assertIn("SessionTargetOk=", harness)
        self.assertIn("SessionCandidateCount=", harness)
        self.assertIn("SessionPointProbeCount=", harness)
        self.assertIn("HasDeleteAll=", harness)
        self.assertIn('discovery := "STATE_CHANGED"', harness)

    def test_windows_builder_targets_only_diagnostic(self) -> None:
        powershell = POWERSHELL.read_text(encoding="utf-8")
        cmd = CMD.read_text(encoding="utf-8")
        self.assertIn("build_mxnm_context_menu_diagnostic.py", powershell)
        self.assertIn("MxNM-Viewer-Context-Diagnostic.exe", powershell)
        self.assertIn("'/Validate'", powershell)
        self.assertIn("Start-Process", powershell)
        self.assertIn("-Wait", powershell)
        self.assertIn("AutoHotkey validation error", powershell)
        self.assertIn("Ahk2Exe error output", powershell)
        self.assertIn("Get-FileHash", powershell)
        self.assertNotIn("build_release.py", powershell)
        self.assertIn(
            "build_viewer_context_diagnostic_exe.ps1",
            cmd,
        )
        self.assertIn("exit /b %BUILD_EXIT_CODE%", cmd)


if __name__ == "__main__":
    unittest.main()
