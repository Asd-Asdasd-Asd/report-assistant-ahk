#!/usr/bin/env python3
"""Static checks for the shared field-tool EXE build script and its launchers."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = ROOT / "scripts" / "build_tool_exe.ps1"
LAUNCHERS = {
    "Build Viewer Checkpoint EXE.cmd": (
        "build_mxnm_viewer_adaptive_checkpoint.py",
        "mxnm_viewer_adaptive_checkpoint1_standalone.ahk",
        "MxNM-Viewer-Checkpoint1",
        "viewer-checkpoint",
    ),
    "Build Viewer Context Diagnostic EXE.cmd": (
        "build_mxnm_context_menu_diagnostic.py",
        "mxnm_context_menu_receiver_diagnostic_standalone.ahk",
        "MxNM-Viewer-Context-Diagnostic",
        "viewer-context-diagnostic",
    ),
    "Build Report Image Caption Diagnostic EXE.cmd": (
        "build_report_image_caption_diagnostic.py",
        "report_image_caption_migration_diagnostic_standalone.ahk",
        "MedEx-Report-Image-Caption-Diagnostic",
        "report-image-caption-diagnostic",
    ),
}


class ToolExeBuildTests(unittest.TestCase):
    def test_launchers_pass_their_tool_parameters_and_propagate_exit_code(
        self,
    ) -> None:
        for name, (generator, script, tool, subdirectory) in LAUNCHERS.items():
            with self.subTest(launcher=name):
                cmd = (ROOT / "tools" / "field-testing" / name).read_text(
                    encoding="utf-8"
                )
                self.assertIn('set "REPOSITORY_ROOT=%~dp0..\\..\\"', cmd)
                self.assertIn(
                    "powershell.exe -NoProfile -ExecutionPolicy Bypass", cmd
                )
                self.assertIn("scripts\\build_tool_exe.ps1", cmd)
                self.assertIn(f"-Generator {generator}", cmd)
                self.assertIn(f"-InputScriptName {script}", cmd)
                self.assertIn(f"-ToolName {tool}", cmd)
                self.assertIn(f"-BuildSubdirectory {subdirectory}", cmd)
                self.assertIn('set "BUILD_EXIT_CODE=%ERRORLEVEL%"', cmd)
                self.assertIn("exit /b %BUILD_EXIT_CODE%", cmd)
                self.assertTrue((ROOT / "scripts" / generator).is_file())

    def test_builder_targets_only_the_requested_tool(self) -> None:
        script = POWERSHELL.read_text(encoding="utf-8-sig")
        self.assertIn("[Parameter(Mandatory = $true)][string]$Generator", script)
        self.assertIn("[string]$InputScriptName", script)
        self.assertIn("[string]$ToolName", script)
        self.assertIn("[string]$BuildSubdirectory", script)
        self.assertIn("'..\\report-assistant-build'", script)
        self.assertIn("Join-Path $toolRoot 'source'", script)
        self.assertIn("Join-Path $toolRoot 'publish'", script)
        self.assertIn("'--output'", script)
        self.assertIn('"$ToolName.building.exe"', script)
        self.assertIn('"$ToolName.exe"', script)
        self.assertIn('"$ToolName.sha256.txt"', script)
        self.assertNotIn("build_release.py", script)
        self.assertNotIn("report_assistant.ahk", script)
        self.assertNotIn("麦旋风.exe", script)

    def test_builder_validates_inputs_output_and_hash(self) -> None:
        script = POWERSHELL.read_text(encoding="utf-8-sig")
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
        self.assertTrue(POWERSHELL.read_bytes().startswith(b"\xef\xbb\xbf"))

    def test_generated_checkpoint_has_exe_metadata(self) -> None:
        generated = (
            ROOT / "tests" / "windows" / "generated"
            / "mxnm_viewer_adaptive_checkpoint1_standalone.ahk"
        ).read_text(encoding="utf-8")
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
