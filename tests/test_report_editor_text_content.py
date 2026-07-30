#!/usr/bin/env python3
"""Safety checks for the opt-in report-editor content diagnostic."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "tests" / "windows" / "report_editor_text_content_field.ahk"


class ReportEditorTextContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = HARNESS.read_text(encoding="utf-8")

    def test_harness_reads_both_document_representations(self) -> None:
        for required in (
            "UIA.GetFocusedElement()",
            "UIA.ControlType.Document",
            "documentElement.TextPattern.DocumentRange.GetText(-1)",
            "documentElement.ValuePattern.Value",
            "===== TextPattern.DocumentRange BEGIN =====",
            "===== ValuePattern.Value BEGIN =====",
        ):
            self.assertIn(required, self.source)

    def test_harness_is_explicitly_sensitive_and_clipboard_only(self) -> None:
        self.assertIn('"Warning=CONTAINS_REPORT_TEXT"', self.source)
        self.assertIn("A_Clipboard := report", self.source)
        self.assertIn("ClipWait(2)", self.source)
        for forbidden in (
            "FileAppend(",
            "Send(",
            "SendText",
            "ControlSend",
            "MouseMove",
            "MouseClick",
            "WinActivate",
        ):
            self.assertNotIn(forbidden, self.source)

    def test_harness_is_scoped_before_focused_element_read(self) -> None:
        for process_name in (
            '"medexworkstation.exe"',
            '"medexworkstations.exe"',
        ):
            self.assertIn(process_name, self.source)
        self.assertLess(
            self.source.index("IsReportTextContentApprovedProcess"),
            self.source.index("UIA.GetFocusedElement()"),
        )


if __name__ == "__main__":
    unittest.main()
