#!/usr/bin/env python3
"""Build and packaging checks for the report image caption diagnostic."""

from __future__ import annotations

import unittest
from pathlib import Path

from scripts.build_mxnm_viewer_adaptive_checkpoint import DIRECTIVES
from scripts.build_report_image_caption_diagnostic import (
    UIA_STANDALONE_ENTRYPOINT,
    build_diagnostic_text,
)


ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = ROOT / "scripts" / "build_tool_exe.ps1"
CMD = (
    ROOT
    / "tools"
    / "field-testing"
    / "Build Report Image Caption Diagnostic EXE.cmd"
)


class ReportImageCaptionDiagnosticBuildTests(unittest.TestCase):
    def test_generated_diagnostic_is_single_file(self) -> None:
        generated = build_diagnostic_text()
        self.assertNotIn("#Include", generated)
        self.assertNotIn(UIA_STANDALONE_ENTRYPOINT, generated)
        self.assertIn("class UIA {", generated)
        self.assertIn("Test=ReportImageCaptionMigrationDiagnostic", generated)
        self.assertIn("DiagnosticVersion=1.1", generated)
        for directive in DIRECTIVES:
            self.assertEqual(generated.count(directive), 1)

    def test_generated_diagnostic_preserves_privacy_contract(self) -> None:
        generated = build_diagnostic_text()
        for required in (
            "Privacy=NO_RAW_NAME_VALUE_TEXT_TITLE_OR_URL_OUTPUT",
            "SelectionPayloadPersisted=false",
            "MouseClickSent=false",
            "WheelSent=false",
            "PasteSent=false",
            "A_Clipboard := report",
        ):
            self.assertIn(required, generated)

    def test_windows_builder_outputs_only_the_diagnostic(self) -> None:
        powershell = POWERSHELL.read_text(encoding="utf-8-sig")
        cmd = CMD.read_text(encoding="utf-8")
        for required in (
            "-Generator build_report_image_caption_diagnostic.py",
            "-BuildSubdirectory report-image-caption-diagnostic",
            "-ToolName MedEx-Report-Image-Caption-Diagnostic",
            "build_tool_exe.ps1",
            "exit /b %BUILD_EXIT_CODE%",
        ):
            self.assertIn(required, cmd)
        for required in (
            "'/Validate'",
            "Start-Process",
            "-Wait",
            "AutoHotkey validation error",
            "Ahk2Exe error output",
            "Get-FileHash",
        ):
            self.assertIn(required, powershell)
        self.assertNotIn("build_release.py", powershell)


if __name__ == "__main__":
    unittest.main()
