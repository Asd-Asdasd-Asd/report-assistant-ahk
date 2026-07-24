#!/usr/bin/env python3
"""Privacy and safety checks for the report-editor text snapshot harness."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "tests" / "windows" / "report_editor_text_snapshot_field.ahk"


class ReportEditorTextSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = HARNESS.read_text(encoding="utf-8")

    def test_harness_uses_focused_document_text_ranges(self) -> None:
        for required in (
            "UIA.GetFocusedElement()",
            "UIA.ControlType.Document",
            "UIA.RawViewWalker.TryGetParentElement(",
            "documentElement.TextPattern",
            "textPattern.DocumentRange",
            "textPattern.GetSelection()",
            "textPattern.GetCaretRange(&caretIsActive)",
            "MoveEndpointByRange(",
            "UIA.TextPatternRangeEndpoint.Start",
            "UIA.TextPatternRangeEndpoint.End",
        ):
            self.assertIn(required, self.source)

    def test_harness_is_read_only_and_does_not_persist_report_text(self) -> None:
        for forbidden in (
            "A_Clipboard",
            "ClipboardAll",
            "Send(",
            "SendText",
            "ControlSend",
            "MouseMove",
            "MouseClick",
            "WinActivate",
            "documentText=",
            "selectedText=",
            "GetText(-1) \"",
        ):
            self.assertNotIn(forbidden, self.source)
        for safe_field in (
            '"TextLength="',
            '"ValueLength="',
            '"TextValueEqual="',
            '"SelectionLength="',
            '"SelectionStart="',
            '"SelectionEnd="',
            '"CaretOffset="',
            '"CaretCandidateOffset="',
            '"CaretSource="',
            '"UnexpectedExceptionType="',
            '"ForegroundUnchanged="',
            '"MouseUnchanged="',
        ):
            self.assertIn(safe_field, self.source)

    def test_harness_is_scoped_to_known_medex_processes(self) -> None:
        self.assertIn('"medexworkstation.exe"', self.source)
        self.assertIn('"medexworkstations.exe"', self.source)
        self.assertLess(
            self.source.index("IsReportSnapshotApprovedProcess"),
            self.source.index("UIA.GetFocusedElement()"),
        )

    def test_inactive_text_pattern_2_caret_is_not_trusted(self) -> None:
        self.assertIn('result["caretActive"] := caretIsActive = true', self.source)
        self.assertIn(
            'result["caretSource"] :=\n'
            '                        "TEXT_PATTERN_2_INACTIVE"',
            self.source,
        )
        self.assertIn(
            'if result["caretActive"] {',
            self.source,
        )
        self.assertIn(
            '&& !result["textPattern2Available"]',
            self.source,
        )


if __name__ == "__main__":
    unittest.main()
