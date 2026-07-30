#!/usr/bin/env python3
"""Privacy and scope checks for the report-editor structure diagnostic."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HARNESS = (
    ROOT / "tests" / "windows" / "report_editor_edit_structure_field.ahk"
)


class ReportEditorEditStructureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = HARNESS.read_text(encoding="utf-8")

    def test_harness_collects_point_chain_and_structural_candidates(self) -> None:
        for required in (
            "UIA.GetFocusedElement()",
            "UIA.ElementFromPoint(mouseX, mouseY)",
            "UIA.SmallestElementFromPoint(",
            'condition: {Type: "Edit"}',
            'condition: {Type: "Document"}',
            "IsTextPatternAvailable: true",
            "IsTextEditPatternAvailable: true",
            "IsValuePatternAvailable: true",
            "BoundingRectangle",
        ):
            self.assertIn(required, self.source)

    def test_harness_does_not_read_or_output_content_properties(self) -> None:
        self.assertIn('"Privacy=NO_NAME_VALUE_OR_TEXT_READ"', self.source)
        for forbidden in (
            ".Name",
            ".Value",
            "ValuePattern.Value",
            "GetText(",
            "LegacyIAccessiblePattern.",
            "AutomationId",
            "ClassName",
            "HelpText",
            "AriaProperties",
            "FileAppend(",
        ):
            self.assertNotIn(forbidden, self.source)

    def test_harness_does_not_change_editor_or_window_state(self) -> None:
        self.assertIn("A_Clipboard := report", self.source)
        for forbidden in (
            "Send(",
            "SendText",
            "ControlSend",
            "MouseMove",
            "MouseClick",
            "WinActivate",
            ".SetFocus(",
        ):
            self.assertNotIn(forbidden, self.source)

    def test_harness_is_scoped_before_uia_capture(self) -> None:
        for process_name in (
            '"medexworkstation.exe"',
            '"medexworkstations.exe"',
        ):
            self.assertIn(process_name, self.source)
        self.assertLess(
            self.source.index("IsReportEditStructureApprovedProcess"),
            self.source.index("UIA.GetFocusedElement()"),
        )


if __name__ == "__main__":
    unittest.main()
