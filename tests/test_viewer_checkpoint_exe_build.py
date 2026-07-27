#!/usr/bin/env python3
"""Static checks for the standalone Viewer checkpoint EXE build."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CMD = ROOT / "Build Viewer Checkpoint EXE.cmd"
POWERSHELL = ROOT / "scripts" / "build_viewer_checkpoint_exe.ps1"
GENERATED = (
    ROOT
    / "tests"
    / "windows"
    / "generated"
    / "mxnm_viewer_adaptive_checkpoint1_standalone.ahk"
)


class ViewerCheckpointExeBuildTests(unittest.TestCase):
    def test_cmd_runs_checkpoint_builder_and_propagates_exit_code(
        self,
    ) -> None:
        cmd = CMD.read_text(encoding="utf-8")
        self.assertIn('set "REPOSITORY_ROOT=%~dp0"', cmd)
        self.assertIn("powershell.exe -NoProfile -ExecutionPolicy Bypass", cmd)
        self.assertIn("build_viewer_checkpoint_exe.ps1", cmd)
        self.assertIn('set "BUILD_EXIT_CODE=%ERRORLEVEL%"', cmd)
        self.assertIn("exit /b %BUILD_EXIT_CODE%", cmd)

    def test_builder_compiles_only_the_read_only_checkpoint(self) -> None:
        script = POWERSHELL.read_text(encoding="utf-8")
        self.assertIn(
            "mxnm_viewer_adaptive_checkpoint1_standalone.ahk",
            script,
        )
        self.assertIn("'..\\report-assistant-build'", script)
        self.assertIn("Join-Path $checkpointRoot 'source'", script)
        self.assertIn("Join-Path $checkpointRoot 'publish'", script)
        self.assertIn(
            "build_mxnm_viewer_adaptive_checkpoint.py",
            script,
        )
        self.assertIn("'--output'", script)
        self.assertIn("MxNM-Viewer-Checkpoint1.building.exe", script)
        self.assertIn("MxNM-Viewer-Checkpoint1.exe", script)
        self.assertIn("MxNM-Viewer-Checkpoint1.sha256.txt", script)
        self.assertNotIn("build_release.py", script)
        self.assertNotIn("report_assistant.ahk", script)
        self.assertNotIn("麦旋风.exe", script)

    def test_builder_validates_inputs_output_and_hash(self) -> None:
        script = POWERSHELL.read_text(encoding="utf-8")
        self.assertIn("Ahk2Exe.exe", script)
        self.assertIn("AutoHotkey64.exe", script)
        self.assertIn("medex-icon.ico", script)
        self.assertIn("'/Validate'", script)
        self.assertIn("'/ErrorStdOut'", script)
        self.assertIn("Start-Process", script)
        self.assertIn("-Wait", script)
        self.assertIn("-RedirectStandardOutput", script)
        self.assertIn("-RedirectStandardError", script)
        self.assertIn("Write-ProcessOutput", script)
        self.assertIn("AutoHotkey validation error", script)
        self.assertIn("Ahk2Exe error output", script)
        self.assertIn("$compilerProcess.ExitCode", script)
        self.assertIn("$buildingItem.Length -le 0", script)
        self.assertIn("$buildingItem.LastWriteTimeUtc", script)
        self.assertIn("Get-FileHash", script)
        self.assertIn("SHA256", script)

    def test_generated_script_has_exe_metadata(self) -> None:
        generated = GENERATED.read_text(encoding="utf-8")
        self.assertIn(";@Ahk2Exe-SetFileVersion 0.0.1.2", generated)
        self.assertIn(";@Ahk2Exe-SetProductVersion 0.0.1", generated)
        self.assertIn(
            ";@Ahk2Exe-SetName MxNM Viewer Adaptive Checkpoint 1",
            generated,
        )

    def test_legacy_field_publish_directory_is_ignored(self) -> None:
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("/publish-field/", gitignore)


if __name__ == "__main__":
    unittest.main()
